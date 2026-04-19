`timescale 1ns/1ps

module tb_arm7tdmi_core_mem_pc
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

  int skipped_seen;
  int target_seen;
  int loop_seen;
  int literal_read_seen;

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
      32'h0000_0000: bus_rdata = 32'hE59F_F010; // LDR pc, [pc, #0x10]
      32'h0000_0004: bus_rdata = 32'hE3A0_00AA; // MOV r0, #0xaa
      32'h0000_0018: bus_rdata = 32'h0000_0020;
      32'h0000_0020: bus_rdata = 32'hE3A0_1033; // MOV r1, #0x33
      32'h0000_0024: bus_rdata = 32'hEAFF_FFFE; // B .
      default:       bus_rdata = 32'hE1A0_0000; // MOV r0, r0
    endcase
  end

  task automatic check_bus_contract;
    logic unused_wdata;
    logic unused_cpsr;
    unused_wdata = ^bus_wdata;
    unused_cpsr = ^debug_cpsr;

    if (bus_write) begin
      $fatal(1, "mem-pc smoke should not write memory");
    end

    if (bus_valid && bus_size !== BUS_SIZE_WORD) begin
      $fatal(1, "mem-pc smoke expected word transfers");
    end

    if (bus_valid && bus_cycle !== BUS_CYCLE_NONSEQ && bus_cycle !== BUS_CYCLE_SEQ) begin
      $fatal(1, "mem-pc smoke saw invalid bus cycle");
    end

    if (unsupported) begin
      $fatal(1, "unexpected unsupported instruction at pc=%08x", debug_pc);
    end
  endtask

  initial begin
    rst_n = 1'b0;
    bus_ready = 1'b1;
    skipped_seen = 0;
    target_seen = 0;
    loop_seen = 0;
    literal_read_seen = 0;

    repeat (2) @(posedge clk);
    rst_n = 1'b1;

    for (int cycle = 0; cycle < 40; cycle++) begin
      @(posedge clk);
      #1;
      check_bus_contract();

      if (bus_valid && !bus_write && bus_addr == 32'h0000_0018) begin
        literal_read_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd0 && debug_reg_wdata == 32'h0000_00AA) begin
        skipped_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd1 && debug_reg_wdata == 32'h0000_0033) begin
        target_seen++;
      end

      if (retired && debug_pc == 32'h0000_0024) begin
        loop_seen++;
      end
    end

    if (literal_read_seen != 1) begin
      $fatal(1, "expected one literal read at 0x18, saw %0d", literal_read_seen);
    end

    if (skipped_seen != 0 || target_seen != 1) begin
      $fatal(1, "expected LDR pc to skip r0 setup and reach target once, saw skipped=%0d target=%0d",
             skipped_seen, target_seen);
    end

    if (loop_seen < 2) begin
      $fatal(1, "expected LDR pc target loop to retire at least twice, saw %0d", loop_seen);
    end

    $display("tb_arm7tdmi_core_mem_pc passed");
    $finish;
  end
endmodule
