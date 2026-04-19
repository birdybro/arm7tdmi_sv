`timescale 1ns/1ps

module tb_arm7tdmi_core_block_pc_restore
  import arm7tdmi_pkg::*;
;
  logic clk;
  logic rst_n;
  logic irq;
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

  int base_seen;
  int lr_seen;
  int target_seen;
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
    .irq_i(irq),
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
      32'h0000_0000: bus_rdata = 32'hE3A0_0090; // MOV r0, #0x90
      32'h0000_0004: bus_rdata = 32'hE321_F013; // MSR CPSR_c, #0x13
      32'h0000_0008: bus_rdata = 32'hE3A0_1011; // MOV r1, #0x11
      32'h0000_000C: bus_rdata = 32'hE3A0_2022; // MOV r2, #0x22
      32'h0000_0010: bus_rdata = 32'hEAFF_FFFE; // B .
      32'h0000_0018: bus_rdata = 32'hE8D0_8000; // LDMIA r0, {pc}^
      32'h0000_0090: bus_rdata = 32'h0000_000C;
      default:       bus_rdata = 32'hE1A0_0000; // MOV r0, r0
    endcase
  end

  task automatic check_bus_contract;
    logic unused_wdata;
    unused_wdata = ^bus_wdata;

    if (bus_write) begin
      $fatal(1, "block-pc-restore smoke should not write memory");
    end

    if (bus_valid && bus_size !== BUS_SIZE_WORD) begin
      $fatal(1, "block-pc-restore smoke expected word transfers");
    end

    if (bus_valid && bus_cycle !== BUS_CYCLE_NONSEQ && bus_cycle !== BUS_CYCLE_SEQ) begin
      $fatal(1, "block-pc-restore smoke saw invalid bus cycle");
    end

    if (unsupported) begin
      $fatal(1, "unexpected unsupported instruction at pc=%08x", debug_pc);
    end
  endtask

  initial begin
    irq = 1'b1;
    rst_n = 1'b0;
    bus_ready = 1'b1;
    base_seen = 0;
    lr_seen = 0;
    target_seen = 0;
    loop_seen = 0;

    repeat (2) @(posedge clk);
    rst_n = 1'b1;

    for (int cycle = 0; cycle < 80; cycle++) begin
      @(posedge clk);
      #1;
      check_bus_contract();

      if (debug_reg_we && debug_reg_waddr == 4'd0 && debug_reg_wdata == 32'h0000_0090) begin
        base_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd14 && debug_reg_wdata == 32'h0000_0010) begin
        lr_seen++;
        irq = 1'b0;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd2 && debug_reg_wdata == 32'h0000_0022) begin
        target_seen++;
      end

      if (retired && debug_pc == 32'h0000_0010) begin
        loop_seen++;
      end
    end

    if (base_seen != 1 || lr_seen != 1 || target_seen != 1) begin
      $fatal(1, "expected LDM pc^ return path once, saw base=%0d lr=%0d target=%0d",
             base_seen, lr_seen, target_seen);
    end

    if (debug_cpsr !== 32'h0000_0013) begin
      $fatal(1, "expected LDM pc^ to restore CPSR 0x13, got %08x", debug_cpsr);
    end

    if (loop_seen < 2) begin
      $fatal(1, "expected LDM pc^ return loop to retire at least twice, saw %0d", loop_seen);
    end

    $display("tb_arm7tdmi_core_block_pc_restore passed");
    $finish;
  end
endmodule
