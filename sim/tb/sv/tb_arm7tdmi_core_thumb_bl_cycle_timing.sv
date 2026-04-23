`timescale 1ns/1ps

module tb_arm7tdmi_core_thumb_bl_cycle_timing
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
  int fetch_04;
  int fetch_20;
  int fetch_22;
  int fetch_30;
  int fetch_32;
  int fetch_24;
  int bl_prefix_lr_seen;
  int bl_return_lr_seen;
  int target_seen;
  int return_seen;
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

  initial begin
    rst_n = 1'b0;
    bus_ready = 1'b1;
    sim_cycle = 0;
    fetch_04 = -1;
    fetch_20 = -1;
    fetch_22 = -1;
    fetch_30 = -1;
    fetch_32 = -1;
    fetch_24 = -1;
    bl_prefix_lr_seen = 0;
    bl_return_lr_seen = 0;
    target_seen = 0;
    return_seen = 0;
    loop_seen = 0;

    repeat (2) @(posedge clk);
    rst_n = 1'b1;

    for (int cycle = 0; cycle < 90; cycle++) begin
      @(posedge clk);
      #1;
      sim_cycle++;

      if (unsupported) begin
        $fatal(1, "unexpected unsupported instruction at pc=%08x cpsr=%08x", debug_pc, debug_cpsr);
      end

      if (bus_write || bus_wdata !== 32'h0000_0000) begin
        $fatal(1, "Thumb BL timing test should not write memory");
      end

      if (bus_valid) begin
        if (!(bus_size inside {BUS_SIZE_HALF, BUS_SIZE_WORD})) begin
          $fatal(1, "Thumb BL timing saw invalid bus size");
        end

        if (!(bus_cycle inside {BUS_CYCLE_NONSEQ, BUS_CYCLE_SEQ})) begin
          $fatal(1, "Thumb BL timing saw invalid cycle class");
        end

        unique case (bus_addr)
          32'h0000_0004: if (fetch_04 < 0) fetch_04 = sim_cycle;
          32'h0000_0020: if (fetch_20 < 0) fetch_20 = sim_cycle;
          32'h0000_0022: if (fetch_22 < 0) fetch_22 = sim_cycle;
          32'h0000_0030: if (fetch_30 < 0) fetch_30 = sim_cycle;
          32'h0000_0032: if (fetch_32 < 0) fetch_32 = sim_cycle;
          32'h0000_0024: if (fetch_24 < 0) fetch_24 = sim_cycle;
          default: begin
          end
        endcase
      end

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

    if ((fetch_04 < 0) || (fetch_20 < 0) || (fetch_22 < 0) ||
        (fetch_30 < 0) || (fetch_32 < 0) || (fetch_24 < 0)) begin
      $fatal(1, "missing Thumb BL timing fetch timestamps");
    end

    if ((fetch_20 - fetch_04) != 2) begin
      $fatal(1, "BX should redirect to Thumb BL prefix on the next fetch slot, saw %0d",
             fetch_20 - fetch_04);
    end

    if ((fetch_22 - fetch_20) != 2) begin
      $fatal(1, "Thumb BL prefix should feed suffix on the next Thumb fetch slot, saw %0d",
             fetch_22 - fetch_20);
    end

    if ((fetch_30 - fetch_22) != 2) begin
      $fatal(1, "Thumb BL suffix should redirect to target on the next fetch slot, saw %0d",
             fetch_30 - fetch_22);
    end

    if ((fetch_32 - fetch_30) != 2 || (fetch_24 - fetch_32) != 2) begin
      $fatal(1, "Thumb BL target/return fetch spacing should stay two cycles, saw %0d and %0d",
             fetch_32 - fetch_30, fetch_24 - fetch_32);
    end

    if (bl_prefix_lr_seen != 1 || bl_return_lr_seen != 1 || target_seen != 1 || return_seen != 1) begin
      $fatal(1, "unexpected Thumb BL timing observations prefix=%0d return_lr=%0d target=%0d return=%0d",
             bl_prefix_lr_seen, bl_return_lr_seen, target_seen, return_seen);
    end

    if (loop_seen < 2) begin
      $fatal(1, "expected Thumb BL timing return loop to retire, saw %0d", loop_seen);
    end

    $display("tb_arm7tdmi_core_thumb_bl_cycle_timing passed");
    $finish;
  end
endmodule
