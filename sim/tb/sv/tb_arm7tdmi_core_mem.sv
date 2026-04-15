`timescale 1ns/1ps

module tb_arm7tdmi_core_mem
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
  int r0_seen;
  int r1_seen;
  int r2_seen;
  int store_seen;
  int load_seen;
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
      32'h0000_0000: bus_rdata = 32'hE3A0_0040; // MOV r0, #0x40
      32'h0000_0004: bus_rdata = 32'hE3A0_102A; // MOV r1, #0x2a
      32'h0000_0008: bus_rdata = 32'hE580_1004; // STR r1, [r0, #4]
      32'h0000_000C: bus_rdata = 32'hE590_2004; // LDR r2, [r0, #4]
      32'h0000_0010: bus_rdata = 32'hEAFF_FFFE; // B .
      32'h0000_0044: bus_rdata = data_word;
      default:       bus_rdata = 32'hE1A0_0000; // MOV r0, r0
    endcase
  end

  always_ff @(posedge clk) begin
    if (bus_valid && bus_write) begin
      if (bus_addr !== 32'h0000_0044) begin
        $fatal(1, "unexpected store address %08x", bus_addr);
      end

      if (bus_size !== BUS_SIZE_WORD || bus_cycle !== BUS_CYCLE_NONSEQ) begin
        $fatal(1, "store expected word nonseq transfer");
      end

      if (bus_wdata !== 32'h0000_002A) begin
        $fatal(1, "store expected wdata 0x2a, got %08x", bus_wdata);
      end

      data_word <= bus_wdata;
      store_seen <= store_seen + 1;
    end
  end

  initial begin
    rst_n = 1'b0;
    bus_ready = 1'b1;
    data_word = 32'hDEAD_BEEF;
    r0_seen = 0;
    r1_seen = 0;
    r2_seen = 0;
    store_seen = 0;
    load_seen = 0;
    loop_seen = 0;

    repeat (2) @(posedge clk);
    rst_n = 1'b1;

    for (int cycle = 0; cycle < 40; cycle++) begin
      @(posedge clk);
      #1;

      if (bus_valid && bus_size !== BUS_SIZE_WORD) begin
        $fatal(1, "memory smoke expected word transfer");
      end

      if (unsupported) begin
        $fatal(1, "unexpected unsupported instruction at pc=%08x", debug_pc);
      end

      if (debug_reg_we && debug_reg_waddr == 4'd0 && debug_reg_wdata == 32'h0000_0040) begin
        r0_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd1 && debug_reg_wdata == 32'h0000_002A) begin
        r1_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd2 && debug_reg_wdata == 32'h0000_002A) begin
        r2_seen++;
        load_seen++;
      end

      if (retired && debug_pc == 32'h0000_0010) begin
        loop_seen++;
      end
    end

    if (r0_seen != 1 || r1_seen != 1) begin
      $fatal(1, "expected one setup write each, saw r0=%0d r1=%0d", r0_seen, r1_seen);
    end

    if (store_seen != 1) begin
      $fatal(1, "expected one store, saw %0d", store_seen);
    end

    if (load_seen != 1 || r2_seen != 1) begin
      $fatal(1, "expected one load into r2, saw load=%0d r2=%0d", load_seen, r2_seen);
    end

    if (loop_seen < 2) begin
      $fatal(1, "expected branch loop to retire at least twice, saw %0d", loop_seen);
    end

    $display("tb_arm7tdmi_core_mem passed");
    $finish;
  end
endmodule
