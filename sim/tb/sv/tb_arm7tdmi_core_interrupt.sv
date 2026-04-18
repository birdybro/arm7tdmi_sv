`timescale 1ns/1ps

module tb_arm7tdmi_core_interrupt
  import arm7tdmi_pkg::*;
;
  logic clk;
  logic rst_n;
  logic irq;
  logic fiq;
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
  logic fiq_scenario;

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
    bus_rdata = 32'hE1A0_0000; // MOV r0, r0

    unique case (bus_addr)
      32'h0000_0000: bus_rdata = 32'hE321_F013; // MSR CPSR_c, #0x13
      32'h0000_0018: bus_rdata = fiq_scenario ? 32'hE1A0_0000 : 32'hE10F_0000; // MRS r0, CPSR
      32'h0000_001C: bus_rdata = fiq_scenario ? 32'hE10F_0000 : 32'hE14F_1000; // MRS r0/r1
      32'h0000_0020: bus_rdata = fiq_scenario ? 32'hE14F_1000 : 32'hEAFF_FFFE; // MRS r1 or B .
      32'h0000_0024: bus_rdata = 32'hEAFF_FFFE; // B .
      default: begin end
    endcase
  end

  task automatic run_case(
      input logic use_fiq,
      input logic [31:0] expected_cpsr,
      input logic [31:0] expected_loop_pc
  );
    int lr_seen;
    int cpsr_seen;
    int spsr_seen;
    int loop_seen;

    lr_seen = 0;
    cpsr_seen = 0;
    spsr_seen = 0;
    loop_seen = 0;

    fiq_scenario = use_fiq;
    irq = 1'b1;
    fiq = use_fiq;
    rst_n = 1'b0;
    bus_ready = 1'b1;

    repeat (2) @(posedge clk);
    rst_n = 1'b1;

    for (int cycle = 0; cycle < 60; cycle++) begin
      @(posedge clk);
      #1;

      if (bus_write || bus_wdata !== 32'h0000_0000) begin
        $fatal(1, "interrupt smoke should not write memory");
      end

      if (bus_valid && bus_size !== BUS_SIZE_WORD) begin
        $fatal(1, "interrupt smoke expected word fetches");
      end

      if (bus_valid && bus_cycle !== BUS_CYCLE_NONSEQ && bus_cycle !== BUS_CYCLE_SEQ) begin
        $fatal(1, "interrupt smoke saw invalid bus cycle");
      end

      if (unsupported) begin
        $fatal(1, "unexpected unsupported instruction at pc=%08x", debug_pc);
      end

      if (debug_reg_we && debug_reg_waddr == 4'd14 && debug_reg_wdata == 32'h0000_000C) begin
        lr_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd0 && debug_reg_wdata == expected_cpsr) begin
        cpsr_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd1 && debug_reg_wdata == 32'h0000_0013) begin
        spsr_seen++;
      end

      if (retired && debug_pc == expected_loop_pc) begin
        loop_seen++;
      end
    end

    if (lr_seen != 1) begin
      $fatal(1, "expected one interrupt LR write of 0xC, saw %0d", lr_seen);
    end

    if (cpsr_seen != 1) begin
      $fatal(1, "expected one interrupt-vector CPSR read of %08x, saw %0d", expected_cpsr, cpsr_seen);
    end

    if (spsr_seen != 1) begin
      $fatal(1, "expected one interrupt-vector SPSR read of 0x13, saw %0d", spsr_seen);
    end

    if (debug_cpsr !== expected_cpsr) begin
      $fatal(1, "expected final interrupt CPSR %08x, got %08x", expected_cpsr, debug_cpsr);
    end

    if (loop_seen < 2) begin
      $fatal(1, "expected interrupt vector loop to retire at least twice, saw %0d", loop_seen);
    end
  endtask

  initial begin
    irq = 1'b0;
    fiq = 1'b0;
    fiq_scenario = 1'b0;
    bus_ready = 1'b1;
    rst_n = 1'b0;

    run_case(1'b0, 32'h0000_0092, 32'h0000_0020);
    run_case(1'b1, 32'h0000_00D1, 32'h0000_0024);

    $display("tb_arm7tdmi_core_interrupt passed");
    $finish;
  end
endmodule
