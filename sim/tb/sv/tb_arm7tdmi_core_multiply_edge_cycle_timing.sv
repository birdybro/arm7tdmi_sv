`timescale 1ns/1ps

module tb_arm7tdmi_core_multiply_edge_cycle_timing
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
  int fetch_08;
  int fetch_0c;
  int fetch_10;
  int fetch_14;
  int fetch_18;
  int fetch_1c;
  int fetch_20;
  int fetch_24;
  int fetch_28;
  int r4_seen;
  int r5_seen;
  int r6_seen;
  int r7_seen;
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
      32'h0000_0000: bus_rdata = 32'hE3A0_0002; // MOV r0, #2
      32'h0000_0004: bus_rdata = 32'hE3A0_1001; // MOV r1, #1
      32'h0000_0008: bus_rdata = 32'hE004_0190; // MUL r4, r0, r1
      32'h0000_000C: bus_rdata = 32'hE3A0_1C01; // MOV r1, #0x00000100
      32'h0000_0010: bus_rdata = 32'hE005_0190; // MUL r5, r0, r1
      32'h0000_0014: bus_rdata = 32'hE3A0_1801; // MOV r1, #0x00010000
      32'h0000_0018: bus_rdata = 32'hE006_0190; // MUL r6, r0, r1
      32'h0000_001C: bus_rdata = 32'hE3A0_1401; // MOV r1, #0x01000000
      32'h0000_0020: bus_rdata = 32'hE007_0190; // MUL r7, r0, r1
      32'h0000_0024: bus_rdata = 32'hEAFF_FFFE; // B .
      default:       bus_rdata = 32'hE1A0_0000;
    endcase
  end

  initial begin
    rst_n = 1'b0;
    bus_ready = 1'b1;
    sim_cycle = 0;
    fetch_08 = -1;
    fetch_0c = -1;
    fetch_10 = -1;
    fetch_14 = -1;
    fetch_18 = -1;
    fetch_1c = -1;
    fetch_20 = -1;
    fetch_24 = -1;
    fetch_28 = -1;
    r4_seen = 0;
    r5_seen = 0;
    r6_seen = 0;
    r7_seen = 0;
    loop_seen = 0;

    repeat (2) @(posedge clk);
    rst_n = 1'b1;

    for (int cycle = 0; cycle < 140; cycle++) begin
      @(posedge clk);
      #1;
      sim_cycle++;

      if (unsupported) begin
        $fatal(1, "unexpected unsupported instruction at pc=%08x", debug_pc);
      end

      if (bus_write || bus_wdata !== 32'h0000_0000) begin
        $fatal(1, "multiply edge timing test should not write memory");
      end

      if (bus_valid) begin
        if (bus_size !== BUS_SIZE_WORD) begin
          $fatal(1, "multiply edge timing expected word fetches");
        end
        if (!(bus_cycle inside {BUS_CYCLE_NONSEQ, BUS_CYCLE_SEQ})) begin
          $fatal(1, "multiply edge timing fetch expected seq/nonseq, got %0d", bus_cycle);
        end

        unique case (bus_addr)
          32'h0000_0008: if (fetch_08 < 0) fetch_08 = sim_cycle;
          32'h0000_000C: if (fetch_0c < 0) fetch_0c = sim_cycle;
          32'h0000_0010: if (fetch_10 < 0) fetch_10 = sim_cycle;
          32'h0000_0014: if (fetch_14 < 0) fetch_14 = sim_cycle;
          32'h0000_0018: if (fetch_18 < 0) fetch_18 = sim_cycle;
          32'h0000_001C: if (fetch_1c < 0) fetch_1c = sim_cycle;
          32'h0000_0020: if (fetch_20 < 0) fetch_20 = sim_cycle;
          32'h0000_0024: if (fetch_24 < 0) fetch_24 = sim_cycle;
          32'h0000_0028: if (fetch_28 < 0) fetch_28 = sim_cycle;
          default: begin
          end
        endcase
      end

      if (debug_reg_we && debug_reg_waddr == 4'd4 && debug_reg_wdata == 32'h0000_0002) begin
        r4_seen++;
      end
      if (debug_reg_we && debug_reg_waddr == 4'd5 && debug_reg_wdata == 32'h0000_0200) begin
        r5_seen++;
      end
      if (debug_reg_we && debug_reg_waddr == 4'd6 && debug_reg_wdata == 32'h0002_0000) begin
        r6_seen++;
      end
      if (debug_reg_we && debug_reg_waddr == 4'd7 && debug_reg_wdata == 32'h0200_0000) begin
        r7_seen++;
      end

      if (retired && debug_pc == 32'h0000_0024) begin
        loop_seen++;
      end
    end

    if (fetch_08 < 0 || fetch_0c < 0 || fetch_10 < 0 || fetch_14 < 0 ||
        fetch_18 < 0 || fetch_1c < 0 || fetch_20 < 0 || fetch_24 < 0) begin
      $fatal(1, "missing multiply edge timing fetch timestamps");
    end

    if ((fetch_0c - fetch_08) != 3 || (fetch_14 - fetch_10) != 4 ||
        (fetch_1c - fetch_18) != 5 || (fetch_24 - fetch_20) != 6) begin
      $fatal(1, "unexpected multiply edge fetch spacing %0d %0d %0d %0d",
             fetch_0c - fetch_08, fetch_14 - fetch_10,
             fetch_1c - fetch_18, fetch_24 - fetch_20);
    end

    if (r4_seen != 1 || r5_seen != 1 || r6_seen != 1 || r7_seen != 1) begin
      $fatal(1, "expected multiply edge result writes once, saw r4=%0d r5=%0d r6=%0d r7=%0d",
             r4_seen, r5_seen, r6_seen, r7_seen);
    end
    if (loop_seen < 2) begin
      $fatal(1, "expected branch loop to retire at least twice, saw %0d", loop_seen);
    end
    if (debug_cpsr !== 32'h0000_00D3) begin
      $fatal(1, "expected multiply edge program to leave CPSR unchanged, got %08x", debug_cpsr);
    end

    $display("tb_arm7tdmi_core_multiply_edge_cycle_timing passed");
    $finish;
  end
endmodule
