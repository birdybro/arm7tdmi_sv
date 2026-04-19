`timescale 1ns/1ps

module tb_arm7tdmi_core_thumb_stack
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

  int push_seen;
  int push_wb_seen;
  int pop_r4_seen;
  int pop_r5_seen;
  int pop_r6_seen;
  int pop_wb_seen;
  int loop_seen;

  arm7tdmi_core dut (
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

  task automatic check_bus_contract;
    if (bus_valid && !(bus_size inside {BUS_SIZE_HALF, BUS_SIZE_WORD})) begin
      $fatal(1, "Thumb stack test saw invalid bus size");
    end

    if (bus_valid && !(bus_cycle inside {BUS_CYCLE_NONSEQ, BUS_CYCLE_SEQ})) begin
      $fatal(1, "Thumb stack test saw invalid cycle class");
    end

    if (unsupported) begin
      $fatal(1, "unexpected unsupported instruction at pc=%08x cpsr=%08x", debug_pc, debug_cpsr);
    end
  endtask

  initial begin
    rst_n = 1'b0;
    bus_ready = 1'b1;
    push_seen = 0;
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
      check_bus_contract();

      if (bus_valid && bus_write) begin
        if (bus_size !== BUS_SIZE_WORD) begin
          $fatal(1, "Thumb PUSH expected word transfer");
        end

        unique case (bus_addr)
          32'h0000_0070: begin
            if (bus_wdata !== 32'h0000_0011) begin
              $fatal(1, "Thumb PUSH r0 store mismatch: %08x", bus_wdata);
            end
            push_seen++;
          end
          32'h0000_0074: begin
            if (bus_wdata !== 32'h0000_0022) begin
              $fatal(1, "Thumb PUSH r1 store mismatch: %08x", bus_wdata);
            end
            push_seen++;
          end
          32'h0000_0078: begin
            if (bus_wdata !== 32'h0000_0033) begin
              $fatal(1, "Thumb PUSH r2 store mismatch: %08x", bus_wdata);
            end
            push_seen++;
          end
          32'h0000_007C: begin
            if (bus_wdata !== 32'h0000_0035) begin
              $fatal(1, "Thumb PUSH lr store mismatch: %08x", bus_wdata);
            end
            push_seen++;
          end
          default: begin
            $fatal(1, "unexpected Thumb PUSH addr=%08x data=%08x", bus_addr, bus_wdata);
          end
        endcase
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

    if (push_seen != 4 || push_wb_seen != 1) begin
      $fatal(1, "expected four Thumb PUSH stores and one writeback, saw stores=%0d wb=%0d",
             push_seen, push_wb_seen);
    end

    if (pop_r4_seen != 1 || pop_r5_seen != 1 || pop_r6_seen != 1 || pop_wb_seen != 1) begin
      $fatal(1, "expected one Thumb POP load/writeback, saw r4=%0d r5=%0d r6=%0d wb=%0d",
             pop_r4_seen, pop_r5_seen, pop_r6_seen, pop_wb_seen);
    end

    if (loop_seen < 2) begin
      $fatal(1, "expected Thumb POP PC loop to retire, saw %0d", loop_seen);
    end

    $display("tb_arm7tdmi_core_thumb_stack passed");
    $finish;
  end
endmodule
