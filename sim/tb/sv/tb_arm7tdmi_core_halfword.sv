`timescale 1ns/1ps

module tb_arm7tdmi_core_halfword
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

  logic [15:0] halfword;
  int base_seen;
  int value_seen;
  int load_seen;
  int signed_byte_seen;
  int signed_half_seen;
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
      32'h0000_0000: bus_rdata = 32'hE3A0_0080; // MOV r0, #0x80
      32'h0000_0004: bus_rdata = 32'hE3A0_10AB; // MOV r1, #0xab
      32'h0000_0008: bus_rdata = 32'hE1C0_10B2; // STRH r1, [r0, #2]
      32'h0000_000C: bus_rdata = 32'hE1D0_20B2; // LDRH r2, [r0, #2]
      32'h0000_0010: bus_rdata = 32'hE1D0_30D4; // LDRSB r3, [r0, #4]
      32'h0000_0014: bus_rdata = 32'hE1D0_40F6; // LDRSH r4, [r0, #6]
      32'h0000_0018: bus_rdata = 32'hEAFF_FFFE; // B .
      32'h0000_0082: bus_rdata = {16'h0, halfword};
      32'h0000_0084: bus_rdata = 32'h0000_0080;
      32'h0000_0086: bus_rdata = 32'h0000_8001;
      default:       bus_rdata = 32'hE1A0_0000; // MOV r0, r0
    endcase
  end

  always_ff @(posedge clk) begin
    if (bus_valid && bus_write) begin
      if (bus_addr !== 32'h0000_0082) begin
        $fatal(1, "unexpected halfword store address %08x", bus_addr);
      end

      if (bus_size !== BUS_SIZE_HALF || bus_cycle !== BUS_CYCLE_NONSEQ) begin
        $fatal(1, "halfword store expected halfword nonseq transfer");
      end

      if (bus_wdata !== 32'h0000_00AB) begin
        $fatal(1, "halfword store expected wdata 0xab, got %08x", bus_wdata);
      end

      halfword <= bus_wdata[15:0];
      store_seen <= store_seen + 1;
    end
  end

  initial begin
    rst_n = 1'b0;
    bus_ready = 1'b1;
    halfword = 16'hCAFE;
    base_seen = 0;
    value_seen = 0;
    load_seen = 0;
    signed_byte_seen = 0;
    signed_half_seen = 0;
    store_seen = 0;
    loop_seen = 0;

    repeat (2) @(posedge clk);
    rst_n = 1'b1;

    for (int cycle = 0; cycle < 50; cycle++) begin
      @(posedge clk);
      #1;

      if (bus_valid && !(bus_size inside {BUS_SIZE_BYTE, BUS_SIZE_HALF, BUS_SIZE_WORD})) begin
        $fatal(1, "halfword smoke expected instruction word, data byte, or data halfword transfer");
      end

      if (unsupported) begin
        $fatal(1, "unexpected unsupported instruction at pc=%08x", debug_pc);
      end

      if (debug_reg_we && debug_reg_waddr == 4'd0 && debug_reg_wdata == 32'h0000_0080) begin
        base_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd1 && debug_reg_wdata == 32'h0000_00AB) begin
        value_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd2 && debug_reg_wdata == 32'h0000_00AB) begin
        load_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd3 && debug_reg_wdata == 32'hFFFF_FF80) begin
        signed_byte_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd4 && debug_reg_wdata == 32'hFFFF_8001) begin
        signed_half_seen++;
      end

      if (retired && debug_pc == 32'h0000_0018) begin
        loop_seen++;
      end
    end

    if (base_seen != 1 || value_seen != 1) begin
      $fatal(1, "expected setup writes once, saw base=%0d value=%0d", base_seen, value_seen);
    end

    if (store_seen != 1 || load_seen != 1 || signed_byte_seen != 1 || signed_half_seen != 1) begin
      $fatal(1, "expected one halfword store, unsigned load, signed byte, and signed half load; saw store=%0d load=%0d sb=%0d sh=%0d",
             store_seen, load_seen, signed_byte_seen, signed_half_seen);
    end

    if (loop_seen < 2) begin
      $fatal(1, "expected branch loop to retire at least twice, saw %0d", loop_seen);
    end

    $display("tb_arm7tdmi_core_halfword passed");
    $finish;
  end
endmodule
