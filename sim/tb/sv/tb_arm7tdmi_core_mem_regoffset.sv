`timescale 1ns/1ps

module tb_arm7tdmi_core_mem_regoffset
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

  logic [31:0] word_a;
  logic [31:0] word_b;
  int base_seen;
  int value_seen;
  int offset_seen;
  int scaled_offset_seen;
  int load_a_seen;
  int load_b_seen;
  int store_a_seen;
  int store_b_seen;
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
      32'h0000_0004: bus_rdata = 32'hE3A0_102A; // MOV r1, #0x2a
      32'h0000_0008: bus_rdata = 32'hE3A0_2004; // MOV r2, #4
      32'h0000_000C: bus_rdata = 32'hE780_1002; // STR r1, [r0, r2]
      32'h0000_0010: bus_rdata = 32'hE790_3002; // LDR r3, [r0, r2]
      32'h0000_0014: bus_rdata = 32'hE3A0_4002; // MOV r4, #2
      32'h0000_0018: bus_rdata = 32'hE780_1104; // STR r1, [r0, r4, LSL #2]
      32'h0000_001C: bus_rdata = 32'hE790_5104; // LDR r5, [r0, r4, LSL #2]
      32'h0000_0020: bus_rdata = 32'hEAFF_FFFE; // B .
      32'h0000_0084: bus_rdata = word_a;
      32'h0000_0088: bus_rdata = word_b;
      default:       bus_rdata = 32'hE1A0_0000; // MOV r0, r0
    endcase
  end

  always_ff @(posedge clk) begin
    if (bus_valid && bus_write) begin
      if (bus_size !== BUS_SIZE_WORD || bus_cycle !== BUS_CYCLE_NONSEQ) begin
        $fatal(1, "register-offset store expected word nonseq transfer");
      end

      if (bus_wdata !== 32'h0000_002A) begin
        $fatal(1, "register-offset store expected wdata 0x2a, got %08x", bus_wdata);
      end

      if (bus_addr == 32'h0000_0084) begin
        word_a <= bus_wdata;
        store_a_seen <= store_a_seen + 1;
      end else if (bus_addr == 32'h0000_0088) begin
        word_b <= bus_wdata;
        store_b_seen <= store_b_seen + 1;
      end else begin
        $fatal(1, "unexpected register-offset store address %08x", bus_addr);
      end
    end
  end

  initial begin
    rst_n = 1'b0;
    bus_ready = 1'b1;
    word_a = 32'hCAFE_0001;
    word_b = 32'hCAFE_0002;
    base_seen = 0;
    value_seen = 0;
    offset_seen = 0;
    scaled_offset_seen = 0;
    load_a_seen = 0;
    load_b_seen = 0;
    store_a_seen = 0;
    store_b_seen = 0;
    loop_seen = 0;

    repeat (2) @(posedge clk);
    rst_n = 1'b1;

    for (int cycle = 0; cycle < 80; cycle++) begin
      @(posedge clk);
      #1;

      if (unsupported) begin
        $fatal(1, "unexpected unsupported instruction at pc=%08x", debug_pc);
      end

      if (debug_reg_we && debug_reg_waddr == 4'd0 && debug_reg_wdata == 32'h0000_0080) begin
        base_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd1 && debug_reg_wdata == 32'h0000_002A) begin
        value_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd2 && debug_reg_wdata == 32'h0000_0004) begin
        offset_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd4 && debug_reg_wdata == 32'h0000_0002) begin
        scaled_offset_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd3 && debug_reg_wdata == 32'h0000_002A) begin
        load_a_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd5 && debug_reg_wdata == 32'h0000_002A) begin
        load_b_seen++;
      end

      if (retired && debug_pc == 32'h0000_0020) begin
        loop_seen++;
      end
    end

    if (base_seen != 1 || value_seen != 1 || offset_seen != 1 || scaled_offset_seen != 1) begin
      $fatal(1, "expected setup writes once, saw base=%0d value=%0d offset=%0d scaled=%0d",
             base_seen, value_seen, offset_seen, scaled_offset_seen);
    end

    if (store_a_seen != 1 || store_b_seen != 1) begin
      $fatal(1, "expected one unscaled and scaled register-offset store, saw a=%0d b=%0d",
             store_a_seen, store_b_seen);
    end

    if (load_a_seen != 1 || load_b_seen != 1) begin
      $fatal(1, "expected one unscaled and scaled register-offset load, saw a=%0d b=%0d",
             load_a_seen, load_b_seen);
    end

    if (loop_seen < 2) begin
      $fatal(1, "expected branch loop to retire at least twice, saw %0d", loop_seen);
    end

    $display("tb_arm7tdmi_core_mem_regoffset passed");
    $finish;
  end
endmodule
