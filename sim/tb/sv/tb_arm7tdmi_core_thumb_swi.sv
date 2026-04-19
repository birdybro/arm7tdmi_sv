`timescale 1ns/1ps

module tb_arm7tdmi_core_thumb_swi
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

  int lr_seen;
  int cpsr_seen;
  int spsr_seen;
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
      32'h0000_0000: bus_rdata = 32'hEA00_000E; // B 0x40
      32'h0000_0008: bus_rdata = 32'hE10F_0000; // MRS r0, CPSR
      32'h0000_000C: bus_rdata = 32'hE14F_1000; // MRS r1, SPSR
      32'h0000_0010: bus_rdata = 32'hEAFF_FFFE; // B .
      32'h0000_0020: bus_rdata = 32'h0000_DF2A; // Thumb SWI #0x2a
      32'h0000_0040: bus_rdata = 32'hE3A0_6021; // MOV r6, #0x21
      32'h0000_0044: bus_rdata = 32'hE12F_FF16; // BX r6
      default:       bus_rdata = 32'hE1A0_0000; // MOV r0, r0
    endcase
  end

  initial begin
    rst_n = 1'b0;
    bus_ready = 1'b1;
    lr_seen = 0;
    cpsr_seen = 0;
    spsr_seen = 0;
    loop_seen = 0;

    repeat (2) @(posedge clk);
    rst_n = 1'b1;

    for (int cycle = 0; cycle < 80; cycle++) begin
      @(posedge clk);
      #1;

      if (bus_write || bus_wdata !== 32'h0000_0000) begin
        $fatal(1, "Thumb SWI smoke should not write memory");
      end

      if (bus_valid && !(bus_size inside {BUS_SIZE_HALF, BUS_SIZE_WORD})) begin
        $fatal(1, "Thumb SWI smoke saw invalid bus size");
      end

      if (bus_valid && !(bus_cycle inside {BUS_CYCLE_NONSEQ, BUS_CYCLE_SEQ})) begin
        $fatal(1, "Thumb SWI smoke saw invalid bus cycle");
      end

      if (unsupported) begin
        $fatal(1, "unexpected unsupported instruction at pc=%08x cpsr=%08x", debug_pc, debug_cpsr);
      end

      if (debug_reg_we && debug_reg_waddr == 4'd14 && debug_reg_wdata == 32'h0000_0022) begin
        lr_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd0 && debug_reg_wdata == 32'h0000_00D3) begin
        cpsr_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd1 && debug_reg_wdata == 32'h0000_00F3) begin
        spsr_seen++;
      end

      if (retired && debug_pc == 32'h0000_0010) begin
        loop_seen++;
      end
    end

    if (lr_seen != 1) begin
      $fatal(1, "expected one Thumb SWI LR write of 0x22, saw %0d", lr_seen);
    end

    if (cpsr_seen != 1) begin
      $fatal(1, "expected one MRS CPSR after Thumb SWI, saw %0d", cpsr_seen);
    end

    if (spsr_seen != 1) begin
      $fatal(1, "expected one MRS SPSR after Thumb SWI, saw %0d", spsr_seen);
    end

    if (debug_cpsr !== 32'h0000_00D3) begin
      $fatal(1, "expected Thumb SWI to enter ARM SVC mode with I set, got %08x", debug_cpsr);
    end

    if (loop_seen < 2) begin
      $fatal(1, "expected Thumb SWI vector loop to retire at least twice, saw %0d", loop_seen);
    end

    $display("tb_arm7tdmi_core_thumb_swi passed");
    $finish;
  end
endmodule
