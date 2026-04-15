`timescale 1ns/1ps

module tb_arm7tdmi_core_smoke
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
  logic irq;
  logic fiq;
  logic [31:0] debug_pc;
  logic [31:0] debug_cpsr;
  logic debug_reg_we;
  logic [3:0] debug_reg_waddr;
  logic [31:0] debug_reg_wdata;
  logic retired;
  logic unsupported;

  int r0_seen;
  int r1_seen;
  int r2_seen;
  int r3_seen;
  int r4_seen;
  int r5_seen;
  int r6_seen;
  int r7_seen;
  int branch_seen;

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
    .irq_i(irq),
    .fiq_i(fiq),
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
      32'h0000_0000: bus_rdata = 32'hE3A0_0001; // MOV r0, #1
      32'h0000_0004: bus_rdata = 32'hE3A0_2002; // MOV r2, #2
      32'h0000_0008: bus_rdata = 32'hE3A0_3001; // MOV r3, #1
      32'h0000_000C: bus_rdata = 32'hE080_1312; // ADD r1, r0, r2, LSL r3
      32'h0000_0010: bus_rdata = 32'hE3A0_4102; // MOV r4, #0x80000000
      32'h0000_0014: bus_rdata = 32'hE3A0_5001; // MOV r5, #1
      32'h0000_0018: bus_rdata = 32'hE3A0_601F; // MOV r6, #31
      32'h0000_001C: bus_rdata = 32'hE1B0_7615; // MOVS r7, r5, LSL r6
      32'h0000_0020: bus_rdata = 32'hEAFF_FFFE; // B .
      default:       bus_rdata = 32'hE1A0_0000; // MOV r0, r0
    endcase
  end

  initial begin
    rst_n = 1'b0;
    bus_ready = 1'b1;
    irq = 1'b0;
    fiq = 1'b0;
    r0_seen = 0;
    r1_seen = 0;
    r2_seen = 0;
    r3_seen = 0;
    r4_seen = 0;
    r5_seen = 0;
    r6_seen = 0;
    r7_seen = 0;
    branch_seen = 0;

    repeat (2) @(posedge clk);
    rst_n = 1'b1;

    for (int cycle = 0; cycle < 44; cycle++) begin
      @(posedge clk);
      #1;

      if (bus_write) begin
        $fatal(1, "core smoke test should not write memory");
      end

      if (bus_wdata !== 32'h0000_0000) begin
        $fatal(1, "instruction-only smoke test expected zero write data, got %08x", bus_wdata);
      end

      if (bus_valid && bus_size !== BUS_SIZE_WORD) begin
        $fatal(1, "instruction fetch expected word size, got %0d", bus_size);
      end

      if (bus_valid && !(bus_cycle inside {BUS_CYCLE_NONSEQ, BUS_CYCLE_SEQ})) begin
        $fatal(1, "instruction fetch expected nonseq/seq cycle, got %0d", bus_cycle);
      end

      if (unsupported) begin
        $fatal(1, "unexpected unsupported instruction at pc=%08x", debug_pc);
      end

      if (debug_reg_we && debug_reg_waddr == 4'd0 && debug_reg_wdata == 32'h0000_0001) begin
        r0_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd1 && debug_reg_wdata == 32'h0000_0005) begin
        r1_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd2 && debug_reg_wdata == 32'h0000_0002) begin
        r2_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd3 && debug_reg_wdata == 32'h0000_0001) begin
        r3_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd4 && debug_reg_wdata == 32'h8000_0000) begin
        r4_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd5 && debug_reg_wdata == 32'h0000_0001) begin
        r5_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd6 && debug_reg_wdata == 32'h0000_001F) begin
        r6_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd7 && debug_reg_wdata == 32'h8000_0000) begin
        r7_seen++;
      end

      if (retired && debug_pc == 32'h0000_0020) begin
        branch_seen++;
      end
    end

    if (r0_seen != 1) begin
      $fatal(1, "expected one r0 write of 1, saw %0d", r0_seen);
    end

    if (r1_seen != 1) begin
      $fatal(1, "expected one r1 write of 5, saw %0d", r1_seen);
    end

    if (r2_seen != 1) begin
      $fatal(1, "expected one r2 write of 2, saw %0d", r2_seen);
    end

    if (r3_seen != 1) begin
      $fatal(1, "expected one r3 write of 1, saw %0d", r3_seen);
    end

    if (r4_seen != 1) begin
      $fatal(1, "expected one r4 write of 0x80000000, saw %0d", r4_seen);
    end

    if (r5_seen != 1 || r6_seen != 1 || r7_seen != 1) begin
      $fatal(1, "expected register-shift setup/result writes once, saw r5=%0d r6=%0d r7=%0d",
             r5_seen, r6_seen, r7_seen);
    end

    if (branch_seen < 2) begin
      $fatal(1, "expected branch loop to retire at least twice, saw %0d", branch_seen);
    end

    if (debug_cpsr !== 32'h8000_00D3) begin
      $fatal(1, "expected MOVS register shift to set only N flag, got %08x", debug_cpsr);
    end

    $display("tb_arm7tdmi_core_smoke passed");
    $finish;
  end
endmodule
