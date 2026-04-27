`timescale 1ns/1ps

module tb_arm7tdmi_core_thumb_ldr_pc_cycle_timing
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
  int fetch_24;
  int fetch_2c;
  int int_cycles_seen;
  int literal_read_seen;
  int ldr_seen;
  int following_seen;
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
      32'h0000_0000: bus_rdata = 32'hE3A0_6021; // MOV r6, #0x21
      32'h0000_0004: bus_rdata = 32'hE12F_FF16; // BX r6
      32'h0000_0020: bus_rdata = 32'h0000_4A01; // Thumb LDR r2, [PC, #4]
      32'h0000_0022: bus_rdata = 32'h0000_2301; // Thumb MOV r3, #1
      32'h0000_0024: bus_rdata = 32'h0000_E002; // Thumb B +4, over literal
      32'h0000_0028: bus_rdata = 32'h1234_5678; // Literal pool word
      32'h0000_002C: bus_rdata = 32'h0000_E7FE; // Thumb B .
      default:       bus_rdata = 32'hE1A0_0000;
    endcase
  end

  initial begin
    rst_n = 1'b0;
    bus_ready = 1'b1;
    sim_cycle = 0;
    fetch_20 = -1;
    fetch_22 = -1;
    fetch_24 = -1;
    fetch_2c = -1;
    int_cycles_seen = 0;
    literal_read_seen = 0;
    ldr_seen = 0;
    following_seen = 0;
    loop_seen = 0;

    repeat (2) @(posedge clk);
    rst_n = 1'b1;

    for (int cycle = 0; cycle < 120; cycle++) begin
      @(posedge clk);
      #1;
      sim_cycle++;

      if (bus_write || bus_wdata !== 32'h0000_0000) begin
        $fatal(1, "thumb PC-relative LDR timing test should not write memory");
      end
      if (bus_valid && !(bus_size inside {BUS_SIZE_HALF, BUS_SIZE_WORD})) begin
        $fatal(1, "thumb PC-relative LDR timing saw invalid bus size");
      end
      if (bus_valid && !(bus_cycle inside {BUS_CYCLE_NONSEQ, BUS_CYCLE_SEQ})) begin
        $fatal(1, "thumb PC-relative LDR timing saw invalid cycle class");
      end
      if (unsupported) begin
        $fatal(1, "unexpected unsupported instruction at pc=%08x cpsr=%08x", debug_pc, debug_cpsr);
      end

      if (bus_valid) begin
        if (bus_addr == 32'h0000_0020 && fetch_20 < 0) fetch_20 = sim_cycle;
        if (bus_addr == 32'h0000_0022 && fetch_22 < 0) fetch_22 = sim_cycle;
        if (bus_addr == 32'h0000_0024 && fetch_24 < 0) fetch_24 = sim_cycle;
        if (bus_addr == 32'h0000_002C && fetch_2c < 0) fetch_2c = sim_cycle;

        if (!bus_write && bus_addr == 32'h0000_0028 && bus_size == BUS_SIZE_WORD) begin
          literal_read_seen++;
        end
      end else if (bus_cycle == BUS_CYCLE_INT) begin
        int_cycles_seen++;
      end

      if (debug_reg_we && debug_pc == 32'h0000_0022 &&
          debug_reg_waddr == 4'd2 && debug_reg_wdata == 32'h1234_5678) begin
        ldr_seen++;
      end
      if (debug_reg_we && debug_pc == 32'h0000_0024 &&
          debug_reg_waddr == 4'd3 && debug_reg_wdata == 32'h0000_0001) begin
        following_seen++;
      end
      if (retired && debug_pc == 32'h0000_002C && debug_cpsr[5]) begin
        loop_seen++;
      end
    end

    if (fetch_20 < 0 || fetch_22 < 0 || fetch_24 < 0 || fetch_2c < 0) begin
      $fatal(1, "missing Thumb PC-relative LDR timing fetch timestamps");
    end
    if ((fetch_22 - fetch_20) != 3) begin
      $fatal(1, "Thumb PC-relative LDR should take 3 cycles to next fetch, saw %0d",
             fetch_22 - fetch_20);
    end
    if ((fetch_24 - fetch_22) != 2 || (fetch_2c - fetch_24) != 2) begin
      $fatal(1, "Thumb fetch stream after PC-relative LDR should return to 2-cycle spacing, saw %0d and %0d",
             fetch_24 - fetch_22, fetch_2c - fetch_24);
    end
    if (literal_read_seen != 1 || ldr_seen != 1 || following_seen != 1) begin
      $fatal(1, "expected one PC-relative literal load path, saw literal=%0d ldr=%0d following=%0d",
             literal_read_seen, ldr_seen, following_seen);
    end
    if (int_cycles_seen < 1) begin
      $fatal(1, "expected visible Thumb PC-relative load writeback internal cycle, saw %0d", int_cycles_seen);
    end
    if (loop_seen < 2) begin
      $fatal(1, "expected Thumb PC-relative LDR timing loop to retire, saw %0d", loop_seen);
    end

    $display("tb_arm7tdmi_core_thumb_ldr_pc_cycle_timing passed");
    $finish;
  end
endmodule
