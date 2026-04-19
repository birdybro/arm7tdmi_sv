`timescale 1ns/1ps

module tb_arm7tdmi_core_mem_unaligned
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

  int r1_seen;
  int r2_seen;
  int r3_seen;
  int read1_seen;
  int read2_seen;
  int read3_seen;
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
      32'h0000_0004: bus_rdata = 32'hE590_1001; // LDR r1, [r0, #1]
      32'h0000_0008: bus_rdata = 32'hE590_2002; // LDR r2, [r0, #2]
      32'h0000_000C: bus_rdata = 32'hE590_3003; // LDR r3, [r0, #3]
      32'h0000_0010: bus_rdata = 32'hEAFF_FFFE; // B .
      32'h0000_0041: bus_rdata = 32'h1122_3344;
      32'h0000_0042: bus_rdata = 32'h1122_3344;
      32'h0000_0043: bus_rdata = 32'h1122_3344;
      default:       bus_rdata = 32'hE1A0_0000; // MOV r0, r0
    endcase
  end

  task automatic check_bus_contract;
    logic unused_wdata;
    logic unused_cpsr;
    unused_wdata = ^bus_wdata;
    unused_cpsr = ^debug_cpsr;

    if (bus_write) begin
      $fatal(1, "unaligned LDR smoke should not write memory");
    end

    if (bus_valid && bus_size !== BUS_SIZE_WORD) begin
      $fatal(1, "unaligned LDR smoke expected word transfers");
    end

    if (bus_valid && bus_cycle !== BUS_CYCLE_NONSEQ && bus_cycle !== BUS_CYCLE_SEQ) begin
      $fatal(1, "unaligned LDR smoke saw invalid bus cycle");
    end

    if (unsupported) begin
      $fatal(1, "unexpected unsupported instruction at pc=%08x", debug_pc);
    end
  endtask

  initial begin
    rst_n = 1'b0;
    bus_ready = 1'b1;
    r1_seen = 0;
    r2_seen = 0;
    r3_seen = 0;
    read1_seen = 0;
    read2_seen = 0;
    read3_seen = 0;
    loop_seen = 0;

    repeat (2) @(posedge clk);
    rst_n = 1'b1;

    for (int cycle = 0; cycle < 60; cycle++) begin
      @(posedge clk);
      #1;
      check_bus_contract();

      if (bus_valid && !bus_write && bus_addr == 32'h0000_0041) begin
        read1_seen++;
      end

      if (bus_valid && !bus_write && bus_addr == 32'h0000_0042) begin
        read2_seen++;
      end

      if (bus_valid && !bus_write && bus_addr == 32'h0000_0043) begin
        read3_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd1 && debug_reg_wdata == 32'h4411_2233) begin
        r1_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd2 && debug_reg_wdata == 32'h3344_1122) begin
        r2_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd3 && debug_reg_wdata == 32'h2233_4411) begin
        r3_seen++;
      end

      if (retired && debug_pc == 32'h0000_0010) begin
        loop_seen++;
      end
    end

    if (read1_seen != 1 || read2_seen != 1 || read3_seen != 1) begin
      $fatal(1, "expected one unaligned word read each, saw +1=%0d +2=%0d +3=%0d",
             read1_seen, read2_seen, read3_seen);
    end

    if (r1_seen != 1 || r2_seen != 1 || r3_seen != 1) begin
      $fatal(1, "expected rotated unaligned loads once, saw r1=%0d r2=%0d r3=%0d",
             r1_seen, r2_seen, r3_seen);
    end

    if (loop_seen < 2) begin
      $fatal(1, "expected unaligned LDR loop to retire at least twice, saw %0d", loop_seen);
    end

    $display("tb_arm7tdmi_core_mem_unaligned passed");
    $finish;
  end
endmodule
