`timescale 1ns/1ps

module tb_arm7tdmi_core_unsupported
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

  int unsupported_seen;
  int r0_seen;
  int r1_seen;
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
      32'h0000_0000: bus_rdata = 32'hE10F_F000; // MRS pc, CPSR (unsupported PSR transfer)
      32'h0000_0004: bus_rdata = 32'hE3A0_0011; // MOV r0, #0x11
      32'h0000_0008: bus_rdata = 32'hE3A0_1022; // MOV r1, #0x22
      32'h0000_000C: bus_rdata = 32'hEAFF_FFFE; // B .
      default:       bus_rdata = 32'hE1A0_0000;
    endcase
  end

  task automatic check_bus_contract;
    if (bus_write || bus_wdata !== 32'h0000_0000) begin
      $fatal(1, "ARM unsupported test should not write memory");
    end

    if (bus_valid && bus_size !== BUS_SIZE_WORD) begin
      $fatal(1, "ARM unsupported test expected word fetches");
    end

    if (bus_valid && !(bus_cycle inside {BUS_CYCLE_NONSEQ, BUS_CYCLE_SEQ})) begin
      $fatal(1, "ARM unsupported test saw invalid cycle class");
    end
  endtask

  initial begin
    rst_n = 1'b0;
    bus_ready = 1'b1;
    unsupported_seen = 0;
    r0_seen = 0;
    r1_seen = 0;
    loop_seen = 0;

    repeat (2) @(posedge clk);
    rst_n = 1'b1;

    for (int cycle = 0; cycle < 40; cycle++) begin
      @(posedge clk);
      #1;
      check_bus_contract();

      if (unsupported) begin
        if (debug_pc !== 32'h0000_0004) begin
          $fatal(1, "ARM unsupported pulse should advance pc to 0x4, saw %08x", debug_pc);
        end
        unsupported_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd0 && debug_reg_wdata == 32'h0000_0011) begin
        r0_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd1 && debug_reg_wdata == 32'h0000_0022) begin
        r1_seen++;
      end

      if (retired && debug_pc == 32'h0000_000C) begin
        loop_seen++;
      end
    end

    if (unsupported_seen != 1) begin
      $fatal(1, "expected one ARM unsupported pulse, saw %0d", unsupported_seen);
    end

    if (r0_seen != 1 || r1_seen != 1) begin
      $fatal(1, "expected MOV results after unsupported instruction, saw r0=%0d r1=%0d",
             r0_seen, r1_seen);
    end

    if (debug_cpsr !== 32'h0000_00D3) begin
      $fatal(1, "ARM unsupported should leave CPSR unchanged, got %08x", debug_cpsr);
    end

    if (loop_seen < 2) begin
      $fatal(1, "expected ARM unsupported loop to retire at least twice, saw %0d", loop_seen);
    end

    $display("tb_arm7tdmi_core_unsupported passed");
    $finish;
  end
endmodule
