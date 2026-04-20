`timescale 1ns/1ps

module tb_arm7tdmi_core_mem_pc_store
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
  /* verilator lint_off UNUSEDSIGNAL */
  logic [31:0] debug_cpsr;
  /* verilator lint_on UNUSEDSIGNAL */
  logic debug_reg_we;
  logic [3:0] debug_reg_waddr;
  logic [31:0] debug_reg_wdata;
  logic retired;
  logic unsupported;

  logic [31:0] data_word;
  int value_seen;
  int store_seen;
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
      32'h0000_0000: bus_rdata = 32'hE3A0_102A; // MOV r1, #0x2a
      32'h0000_0004: bus_rdata = 32'hE1A0_0000; // MOV r0, r0
      32'h0000_0008: bus_rdata = 32'hE58F_1030; // STR r1, [pc, #0x30]
      32'h0000_000C: bus_rdata = 32'hEAFF_FFFE; // B .
      32'h0000_0040: bus_rdata = data_word;
      default:       bus_rdata = 32'hE1A0_0000; // MOV r0, r0
    endcase
  end

  always_ff @(posedge clk) begin
    if (bus_valid && bus_write) begin
      if (bus_addr !== 32'h0000_0040 || bus_size !== BUS_SIZE_WORD ||
          bus_cycle !== BUS_CYCLE_NONSEQ || bus_wdata !== 32'h0000_002A) begin
        $fatal(1, "unexpected pc-relative STR addr=%08x size=%0d cycle=%0d data=%08x",
               bus_addr, bus_size, bus_cycle, bus_wdata);
      end

      data_word <= bus_wdata;
      store_seen <= store_seen + 1;
    end
  end

  initial begin
    rst_n = 1'b0;
    bus_ready = 1'b1;
    data_word = 32'hCAFE_F00D;
    value_seen = 0;
    store_seen = 0;
    loop_seen = 0;

    repeat (2) @(posedge clk);
    rst_n = 1'b1;

    for (int cycle = 0; cycle < 40; cycle++) begin
      @(posedge clk);
      #1;

      if (bus_valid && !(bus_size inside {BUS_SIZE_WORD})) begin
        $fatal(1, "pc-relative STR smoke expected word transfers");
      end

      if (bus_valid && !(bus_cycle inside {BUS_CYCLE_NONSEQ, BUS_CYCLE_SEQ})) begin
        $fatal(1, "pc-relative STR smoke saw invalid cycle class");
      end

      if (unsupported) begin
        $fatal(1, "unexpected unsupported instruction at pc=%08x", debug_pc);
      end

      if (debug_reg_we && debug_reg_waddr == 4'd1 && debug_reg_wdata == 32'h0000_002A) begin
        value_seen++;
      end

      if (retired && debug_pc == 32'h0000_000C) begin
        loop_seen++;
      end
    end

    if (value_seen != 1) begin
      $fatal(1, "expected one setup write, saw %0d", value_seen);
    end

    if (store_seen != 1) begin
      $fatal(1, "expected one pc-relative STR, saw %0d", store_seen);
    end

    if (data_word !== 32'h0000_002A) begin
      $fatal(1, "unexpected final memory word=%08x", data_word);
    end

    if (loop_seen < 2) begin
      $fatal(1, "expected pc-relative STR loop to retire, saw %0d", loop_seen);
    end

    $display("tb_arm7tdmi_core_mem_pc_store passed");
    $finish;
  end
endmodule
