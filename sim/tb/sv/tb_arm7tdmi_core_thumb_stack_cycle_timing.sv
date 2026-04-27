`timescale 1ns/1ps

module tb_arm7tdmi_core_thumb_stack_cycle_timing
  import arm7tdmi_pkg::*;
;
  logic clk;
  logic rst_n;
  logic [31:0] bus_addr;
  logic bus_valid;
  logic bus_write;
  arm_bus_size_t bus_size;
  arm_bus_cycle_t bus_cycle;
  logic [31:0] bus_wdata;
  logic [31:0] bus_rdata;
  logic bus_ready;
  logic [31:0] debug_pc;
  logic [31:0] debug_cpsr;
  logic debug_reg_we;
  logic [3:0] debug_reg_waddr;
  logic [31:0] debug_reg_wdata;
  logic retired;
  logic unsupported;

  int sim_cycle;
  int fetch_20;
  int fetch_22;
  int fetch_34;
  int int_cycles_seen;
  int push_seen;
  int pop_seen;
  int push_wb_seen;
  int pop_r4_seen;
  int pop_r5_seen;
  int pop_r6_seen;
  int pop_wb_seen;
  int loop_seen;

  arm7tdmi_core #(
    .TIMING_MODE(TIMING_ARM7TDMI_CYCLE)
  ) dut (
    .clk_i(clk),
    .rst_ni(rst_n),
    .bus_addr_o(bus_addr),
    .bus_valid_o(bus_valid),
    .bus_write_o(bus_write),
    .bus_size_o(bus_size),
    .bus_cycle_o(bus_cycle),
    .bus_wdata_o(bus_wdata),
    .bus_rdata_i(bus_rdata),
    .bus_ready_i(bus_ready),
    .irq_i(1'b0),
    .fiq_i(1'b0),
    .debug_pc_o(debug_pc),
    .debug_cpsr_o(debug_cpsr),
    .debug_reg_we_o(debug_reg_we),
    .debug_reg_waddr_o(debug_reg_waddr),
    .debug_reg_wdata_o(debug_reg_wdata),
    .retired_o(retired),
    .unsupported_o(unsupported)
  );

  initial clk = 1'b0;
  always #5 clk = !clk;

  always_comb begin
    unique case (bus_addr)
      32'h0000_0000: bus_rdata = 32'hE3A0_0011; // MOV r0, #0x11
      32'h0000_0004: bus_rdata = 32'hE3A0_1022; // MOV r1, #0x22
      32'h0000_0008: bus_rdata = 32'hE3A0_2033; // MOV r2, #0x33
      32'h0000_000C: bus_rdata = 32'hE3A0_D080; // MOV sp, #0x80
      32'h0000_0010: bus_rdata = 32'hE3A0_E035; // MOV lr, #0x35
      32'h0000_0014: bus_rdata = 32'hE3A0_6021; // MOV r6, #0x21
      32'h0000_0018: bus_rdata = 32'hE12F_FF16; // BX r6
      32'h0000_0020: bus_rdata = 32'h0000_B507; // Thumb PUSH {r0-r2, lr}
      32'h0000_0022: bus_rdata = 32'h0000_BD70; // Thumb POP {r4-r6, pc}
      32'h0000_0034: bus_rdata = 32'h0000_E7FE; // Thumb B .
      32'h0000_0070: bus_rdata = 32'h0000_0011;
      32'h0000_0074: bus_rdata = 32'h0000_0022;
      32'h0000_0078: bus_rdata = 32'h0000_0033;
      32'h0000_007C: bus_rdata = 32'h0000_0035;
      default:       bus_rdata = 32'hE1A0_0000;
    endcase
  end

  initial begin
    rst_n = 1'b0;
    bus_ready = 1'b1;
    sim_cycle = 0;
    fetch_20 = -1;
    fetch_22 = -1;
    fetch_34 = -1;
    int_cycles_seen = 0;
    push_seen = 0;
    pop_seen = 0;
    push_wb_seen = 0;
    pop_r4_seen = 0;
    pop_r5_seen = 0;
    pop_r6_seen = 0;
    pop_wb_seen = 0;
    loop_seen = 0;

    repeat (2) @(posedge clk);
    rst_n = 1'b1;

    for (int cycle = 0; cycle < 180; cycle++) begin
      @(posedge clk);
      #1;
      sim_cycle++;

      if (unsupported) begin
        $fatal(1, "unexpected unsupported instruction at pc=%08x cpsr=%08x", debug_pc, debug_cpsr);
      end

      if (bus_valid) begin
        if (bus_size != BUS_SIZE_WORD && bus_size != BUS_SIZE_HALF) begin
          $fatal(1, "Thumb stack timing saw invalid bus size");
        end

        if (!(bus_cycle inside {BUS_CYCLE_NONSEQ, BUS_CYCLE_SEQ})) begin
          $fatal(1, "Thumb stack timing saw invalid cycle class");
        end

        if (bus_addr == 32'h0000_0020 && fetch_20 < 0) fetch_20 = sim_cycle;
        if (bus_addr == 32'h0000_0022 && fetch_22 < 0) fetch_22 = sim_cycle;
        if (bus_addr == 32'h0000_0034 && fetch_34 < 0) fetch_34 = sim_cycle;

        if (bus_write) begin
          if (bus_size !== BUS_SIZE_WORD) begin
            $fatal(1, "Thumb PUSH expected word transfer");
          end
          unique case (bus_addr)
            32'h0000_0070: begin
              if (bus_wdata !== 32'h0000_0011) $fatal(1, "Thumb PUSH r0 store mismatch: %08x", bus_wdata);
              push_seen++;
            end
            32'h0000_0074: begin
              if (bus_wdata !== 32'h0000_0022) $fatal(1, "Thumb PUSH r1 store mismatch: %08x", bus_wdata);
              push_seen++;
            end
            32'h0000_0078: begin
              if (bus_wdata !== 32'h0000_0033) $fatal(1, "Thumb PUSH r2 store mismatch: %08x", bus_wdata);
              push_seen++;
            end
            32'h0000_007C: begin
              if (bus_wdata !== 32'h0000_0035) $fatal(1, "Thumb PUSH lr store mismatch: %08x", bus_wdata);
              push_seen++;
            end
            default: $fatal(1, "unexpected Thumb PUSH addr=%08x data=%08x", bus_addr, bus_wdata);
          endcase
        end else if (bus_addr inside {32'h0000_0070, 32'h0000_0074, 32'h0000_0078, 32'h0000_007C}) begin
          if (bus_size !== BUS_SIZE_WORD) begin
            $fatal(1, "Thumb POP expected word transfer");
          end
          pop_seen++;
        end
      end else if (bus_cycle == BUS_CYCLE_INT) begin
        int_cycles_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd13 && debug_reg_wdata == 32'h0000_0070) begin
        push_wb_seen++;
      end
      if (debug_reg_we && debug_reg_waddr == 4'd4 && debug_reg_wdata == 32'h0000_0011) begin
        pop_r4_seen++;
      end
      if (debug_reg_we && debug_reg_waddr == 4'd5 && debug_reg_wdata == 32'h0000_0022) begin
        pop_r5_seen++;
      end
      if (debug_reg_we && debug_reg_waddr == 4'd6 && debug_reg_wdata == 32'h0000_0033) begin
        pop_r6_seen++;
      end
      if (debug_reg_we && debug_cpsr[5] &&
          debug_reg_waddr == 4'd13 && debug_reg_wdata == 32'h0000_0080) begin
        pop_wb_seen++;
      end
      if (retired && debug_pc == 32'h0000_0034 && debug_cpsr[5]) begin
        loop_seen++;
      end
    end

    if (fetch_20 < 0 || fetch_22 < 0 || fetch_34 < 0) begin
      $fatal(1, "missing Thumb stack timing fetch timestamps");
    end
    if ((fetch_22 - fetch_20) != 7) begin
      $fatal(1, "Thumb PUSH with 4 beats and writeback should take 7 cycles to next fetch, saw %0d",
             fetch_22 - fetch_20);
    end
    if ((fetch_34 - fetch_22) != 7) begin
      $fatal(1, "Thumb POP {r4-r6,pc} with 4 beats and redirect should take 7 cycles to next fetch, saw %0d",
             fetch_34 - fetch_22);
    end
    if (push_seen != 4 || pop_seen != 4 || push_wb_seen != 1 ||
        pop_r4_seen != 1 || pop_r5_seen != 1 || pop_r6_seen != 1 || pop_wb_seen != 1) begin
      $fatal(1, "unexpected Thumb stack timing observations push=%0d pop=%0d push_wb=%0d r4=%0d r5=%0d r6=%0d pop_wb=%0d",
             push_seen, pop_seen, push_wb_seen, pop_r4_seen, pop_r5_seen, pop_r6_seen, pop_wb_seen);
    end
    if (int_cycles_seen < 2) begin
      $fatal(1, "expected visible Thumb stack internal cycles, saw %0d", int_cycles_seen);
    end
    if (loop_seen < 2) begin
      $fatal(1, "expected Thumb POP PC loop to retire, saw %0d", loop_seen);
    end

    $display("tb_arm7tdmi_core_thumb_stack_cycle_timing passed");
    $finish;
  end
endmodule
