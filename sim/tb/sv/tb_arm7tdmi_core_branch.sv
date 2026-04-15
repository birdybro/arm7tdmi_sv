`timescale 1ns/1ps

module tb_arm7tdmi_core_branch
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

  int lr_seen;
  int r5_seen;
  int r6_seen;
  int bx_seen;
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
      32'h0000_0000: bus_rdata = 32'hEB00_0002; // BL 0x10
      32'h0000_0004: bus_rdata = 32'hE3A0_6006; // MOV r6, #6
      32'h0000_0008: bus_rdata = 32'hEAFF_FFFE; // B .
      32'h0000_0010: bus_rdata = 32'hE3A0_5004; // MOV r5, #4
      32'h0000_0014: bus_rdata = 32'hE12F_FF15; // BX r5
      default:       bus_rdata = 32'hE1A0_0000; // MOV r0, r0
    endcase
  end

  initial begin
    rst_n = 1'b0;
    bus_ready = 1'b1;
    lr_seen = 0;
    r5_seen = 0;
    r6_seen = 0;
    bx_seen = 0;
    loop_seen = 0;

    repeat (2) @(posedge clk);
    rst_n = 1'b1;

    for (int cycle = 0; cycle < 40; cycle++) begin
      @(posedge clk);
      #1;

      if (bus_write || bus_wdata !== 32'h0000_0000) begin
        $fatal(1, "branch smoke test should not write memory");
      end

      if (bus_valid && bus_size !== BUS_SIZE_WORD) begin
        $fatal(1, "ARM branch fetch expected word size");
      end

      if (bus_valid && !(bus_cycle inside {BUS_CYCLE_NONSEQ, BUS_CYCLE_SEQ})) begin
        $fatal(1, "unexpected branch fetch cycle class %0d", bus_cycle);
      end

      if (unsupported) begin
        $fatal(1, "unexpected unsupported instruction at pc=%08x", debug_pc);
      end

      if (debug_reg_we && debug_reg_waddr == 4'd14 && debug_reg_wdata == 32'h0000_0004) begin
        lr_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd5 && debug_reg_wdata == 32'h0000_0004) begin
        r5_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd6 && debug_reg_wdata == 32'h0000_0006) begin
        r6_seen++;
      end

      if (retired && debug_pc == 32'h0000_0014 && debug_cpsr[5] == 1'b0) begin
        bx_seen++;
      end

      if (retired && debug_pc == 32'h0000_0008) begin
        loop_seen++;
      end
    end

    if (lr_seen != 1) begin
      $fatal(1, "expected BL to write LR=4 once, saw %0d", lr_seen);
    end

    if (r5_seen != 1) begin
      $fatal(1, "expected callee to write r5=4 once, saw %0d", r5_seen);
    end

    if (r6_seen != 1) begin
      $fatal(1, "expected return path to write r6=6 once, saw %0d", r6_seen);
    end

    if (bx_seen != 1) begin
      $fatal(1, "expected one BX retirement in ARM state, saw %0d", bx_seen);
    end

    if (loop_seen < 2) begin
      $fatal(1, "expected branch loop at 0x8 to retire at least twice, saw %0d", loop_seen);
    end

    $display("tb_arm7tdmi_core_branch passed");
    $finish;
  end
endmodule
