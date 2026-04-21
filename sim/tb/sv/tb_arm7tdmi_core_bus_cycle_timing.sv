`timescale 1ns/1ps

module tb_arm7tdmi_core_bus_cycle_timing
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

  logic [31:0] mem0;
  logic [31:0] mem1;
  logic [31:0] mem2;
  int stm_seen;
  int swap_store_seen;
  arm_bus_cycle_t stm_cycle_0;
  arm_bus_cycle_t stm_cycle_1;
  arm_bus_cycle_t stm_cycle_2;
  arm_bus_cycle_t swap_store_cycle;
  int r5_seen;
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
      32'h0000_0000: bus_rdata = 32'hE3A0_0080; // MOV r0, #0x80
      32'h0000_0004: bus_rdata = 32'hE3A0_1011; // MOV r1, #0x11
      32'h0000_0008: bus_rdata = 32'hE3A0_2022; // MOV r2, #0x22
      32'h0000_000C: bus_rdata = 32'hE3A0_3033; // MOV r3, #0x33
      32'h0000_0010: bus_rdata = 32'hE8A0_000E; // STMIA r0!, {r1-r3}
      32'h0000_0014: bus_rdata = 32'hE3A0_4080; // MOV r4, #0x80
      32'h0000_0018: bus_rdata = 32'hE104_5091; // SWP r5, r1, [r4]
      32'h0000_001C: bus_rdata = 32'hEAFF_FFFE; // B .
      32'h0000_0080: bus_rdata = mem0;
      32'h0000_0084: bus_rdata = mem1;
      32'h0000_0088: bus_rdata = mem2;
      default:       bus_rdata = 32'hE1A0_0000; // MOV r0, r0
    endcase
  end

  always_ff @(posedge clk) begin
    if (bus_valid && bus_write) begin
      if (bus_size !== BUS_SIZE_WORD) begin
        $fatal(1, "bus cycle timing test expected word writes");
      end

      unique case (bus_addr)
        32'h0000_0080: begin
          if (stm_seen == 0) begin
            stm_cycle_0 <= bus_cycle;
            mem0 <= bus_wdata;
            stm_seen <= stm_seen + 1;
          end else begin
            swap_store_cycle <= bus_cycle;
            mem0 <= bus_wdata;
            swap_store_seen <= swap_store_seen + 1;
          end
        end
        32'h0000_0084: begin
          stm_cycle_1 <= bus_cycle;
          mem1 <= bus_wdata;
          stm_seen <= stm_seen + 1;
        end
        32'h0000_0088: begin
          stm_cycle_2 <= bus_cycle;
          mem2 <= bus_wdata;
          stm_seen <= stm_seen + 1;
        end
        default: begin
          $fatal(1, "unexpected write address %08x", bus_addr);
        end
      endcase
    end
  end

  initial begin
    rst_n = 1'b0;
    bus_ready = 1'b1;
    mem0 = 32'hCAFE_0000;
    mem1 = 32'hCAFE_0001;
    mem2 = 32'hCAFE_0002;
    stm_seen = 0;
    swap_store_seen = 0;
    stm_cycle_0 = BUS_CYCLE_COPROC;
    stm_cycle_1 = BUS_CYCLE_COPROC;
    stm_cycle_2 = BUS_CYCLE_COPROC;
    swap_store_cycle = BUS_CYCLE_COPROC;
    r5_seen = 0;
    loop_seen = 0;

    repeat (2) @(posedge clk);
    rst_n = 1'b1;

    for (int cycle = 0; cycle < 80; cycle++) begin
      @(posedge clk);
      #1;

      if (unsupported) begin
        $fatal(1, "unexpected unsupported instruction at pc=%08x", debug_pc);
      end

      if (debug_reg_we && debug_reg_waddr == 4'd5 && debug_reg_wdata == 32'h0000_0011) begin
        r5_seen++;
      end

      if (retired && debug_pc == 32'h0000_001C) begin
        loop_seen++;
      end
    end

    if (stm_seen != 3) begin
      $fatal(1, "expected three STMIA beats, saw %0d", stm_seen);
    end

    if ((stm_cycle_0 != BUS_CYCLE_NONSEQ) ||
        (stm_cycle_1 != BUS_CYCLE_SEQ) ||
        (stm_cycle_2 != BUS_CYCLE_SEQ)) begin
      $fatal(1, "expected STMIA beat classes N,S,S and saw %0d,%0d,%0d",
             stm_cycle_0, stm_cycle_1, stm_cycle_2);
    end

    if ((swap_store_seen != 1) || (swap_store_cycle != BUS_CYCLE_SEQ)) begin
      $fatal(1, "expected swap write to be sequential once, saw count=%0d cycle=%0d",
             swap_store_seen, swap_store_cycle);
    end

    if (r5_seen != 1) begin
      $fatal(1, "expected SWP to return the pre-swap word once, saw %0d", r5_seen);
    end

    if (loop_seen < 2) begin
      $fatal(1, "expected branch loop to retire at least twice, saw %0d", loop_seen);
    end

    if (mem0 !== 32'h0000_0011 || mem1 !== 32'h0000_0022 || mem2 !== 32'h0000_0033) begin
      $fatal(1, "unexpected final memory image %08x %08x %08x", mem0, mem1, mem2);
    end

    if (debug_cpsr !== 32'h0000_00D3) begin
      $fatal(1, "expected timing-mode bus test to leave CPSR unchanged, got %08x", debug_cpsr);
    end

    $display("tb_arm7tdmi_core_bus_cycle_timing passed");
    $finish;
  end
endmodule
