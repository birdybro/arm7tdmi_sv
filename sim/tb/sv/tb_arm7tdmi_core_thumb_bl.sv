`timescale 1ns/1ps

module tb_arm7tdmi_core_thumb_bl
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

  int bl_prefix_lr_seen;
  int bl_return_lr_seen;
  int target_seen;
  int return_seen;
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
      32'h0000_0000: bus_rdata = 32'hE3A0_0021; // MOV r0, #0x21
      32'h0000_0004: bus_rdata = 32'hE12F_FF10; // BX r0
      32'h0000_0020: bus_rdata = 32'h0000_F000; // Thumb BL prefix, target 0x30
      32'h0000_0022: bus_rdata = 32'h0000_F806; // Thumb BL suffix, +0x0c
      32'h0000_0024: bus_rdata = 32'h0000_2366; // Thumb MOV r3, #0x66
      32'h0000_0026: bus_rdata = 32'h0000_E7FE; // Thumb B .
      32'h0000_0030: bus_rdata = 32'h0000_2255; // Thumb MOV r2, #0x55
      32'h0000_0032: bus_rdata = 32'h0000_4770; // Thumb BX lr
      default:       bus_rdata = 32'hE1A0_0000;
    endcase
  end

  task automatic check_bus_contract;
    if (bus_write || bus_wdata !== 32'h0000_0000) begin
      $fatal(1, "thumb BL test should not write memory");
    end

    if (bus_valid && !(bus_size inside {BUS_SIZE_HALF, BUS_SIZE_WORD})) begin
      $fatal(1, "thumb BL saw invalid bus size");
    end

    if (bus_valid && !(bus_cycle inside {BUS_CYCLE_NONSEQ, BUS_CYCLE_SEQ})) begin
      $fatal(1, "thumb BL saw invalid cycle class");
    end

    if (unsupported) begin
      $fatal(1, "unexpected unsupported instruction at pc=%08x cpsr=%08x", debug_pc, debug_cpsr);
    end
  endtask

  initial begin
    rst_n = 1'b0;
    bus_ready = 1'b1;
    bl_prefix_lr_seen = 0;
    bl_return_lr_seen = 0;
    target_seen = 0;
    return_seen = 0;
    loop_seen = 0;

    repeat (2) @(posedge clk);
    rst_n = 1'b1;

    for (int cycle = 0; cycle < 80; cycle++) begin
      @(posedge clk);
      #1;
      check_bus_contract();

      if (debug_reg_we && debug_reg_waddr == 4'd14 && debug_reg_wdata == 32'h0000_0024) begin
        bl_prefix_lr_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd14 && debug_reg_wdata == 32'h0000_0025) begin
        bl_return_lr_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd2 && debug_reg_wdata == 32'h0000_0055) begin
        target_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd3 && debug_reg_wdata == 32'h0000_0066) begin
        return_seen++;
      end

      if (retired && debug_pc == 32'h0000_0026 && debug_cpsr[5]) begin
        loop_seen++;
      end
    end

    if (bl_prefix_lr_seen != 1 || bl_return_lr_seen != 1) begin
      $fatal(1, "expected BL LR writes once each, saw prefix=%0d return=%0d",
             bl_prefix_lr_seen, bl_return_lr_seen);
    end

    if (target_seen != 1 || return_seen != 1) begin
      $fatal(1, "expected BL target and return path once, saw target=%0d return=%0d",
             target_seen, return_seen);
    end

    if (loop_seen < 2) begin
      $fatal(1, "expected Thumb return loop to retire, saw %0d", loop_seen);
    end

    $display("tb_arm7tdmi_core_thumb_bl passed");
    $finish;
  end
endmodule
