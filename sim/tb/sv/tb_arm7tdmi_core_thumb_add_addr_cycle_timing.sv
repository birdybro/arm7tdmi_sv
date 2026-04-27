`timescale 1ns/1ps

module tb_arm7tdmi_core_thumb_add_addr_cycle_timing
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
  int fetch_20;
  int fetch_22;
  int fetch_24;
  int pc_add_seen;
  int sp_add_seen;
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
      32'h0000_0000: bus_rdata = 32'hE3A0_D040; // MOV sp, #0x40
      32'h0000_0004: bus_rdata = 32'hE3A0_6021; // MOV r6, #0x21
      32'h0000_0008: bus_rdata = 32'hE12F_FF16; // BX r6
      32'h0000_0020: bus_rdata = 32'h0000_A305; // Thumb ADD r3, PC, #20
      32'h0000_0022: bus_rdata = 32'h0000_AC06; // Thumb ADD r4, SP, #24
      32'h0000_0024: bus_rdata = 32'h0000_E7FE; // Thumb B .
      default:       bus_rdata = 32'hE1A0_0000;
    endcase
  end

  initial begin
    rst_n = 1'b0;
    bus_ready = 1'b1;
    sim_cycle = 0;
    fetch_20 = -1;
    fetch_22 = -1;
    fetch_24 = -1;
    pc_add_seen = 0;
    sp_add_seen = 0;
    loop_seen = 0;

    repeat (2) @(posedge clk);
    rst_n = 1'b1;

    for (int cycle = 0; cycle < 100; cycle++) begin
      @(posedge clk);
      #1;
      sim_cycle++;

      if (unsupported) begin
        $fatal(1, "unexpected unsupported instruction at pc=%08x cpsr=%08x", debug_pc, debug_cpsr);
      end

      if (bus_write || bus_wdata !== 32'h0000_0000) begin
        $fatal(1, "Thumb address add timing should not write memory");
      end

      if (bus_valid) begin
        if (!(bus_size inside {BUS_SIZE_HALF, BUS_SIZE_WORD})) begin
          $fatal(1, "Thumb address add timing saw invalid bus size");
        end
        if (!(bus_cycle inside {BUS_CYCLE_NONSEQ, BUS_CYCLE_SEQ})) begin
          $fatal(1, "Thumb address add timing saw invalid cycle class");
        end

        if (bus_addr == 32'h0000_0020 && fetch_20 < 0) fetch_20 = sim_cycle;
        if (bus_addr == 32'h0000_0022 && fetch_22 < 0) fetch_22 = sim_cycle;
        if (bus_addr == 32'h0000_0024 && fetch_24 < 0) fetch_24 = sim_cycle;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd3 && debug_reg_wdata == 32'h0000_0038) begin
        pc_add_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd4 && debug_reg_wdata == 32'h0000_0058) begin
        sp_add_seen++;
      end

      if (retired && debug_pc == 32'h0000_0024 && debug_cpsr[5]) begin
        loop_seen++;
      end
    end

    if (fetch_20 < 0 || fetch_22 < 0 || fetch_24 < 0) begin
      $fatal(1, "missing Thumb address add fetch timestamps");
    end
    if ((fetch_22 - fetch_20) != 2 || (fetch_24 - fetch_22) != 2) begin
      $fatal(1, "unexpected Thumb address add fetch spacing %0d %0d",
             fetch_22 - fetch_20, fetch_24 - fetch_22);
    end
    if (pc_add_seen != 1 || sp_add_seen != 1) begin
      $fatal(1, "expected one PC/SP address add, saw pc=%0d sp=%0d",
             pc_add_seen, sp_add_seen);
    end
    if (loop_seen < 2) begin
      $fatal(1, "expected Thumb address add timing loop to retire, saw %0d", loop_seen);
    end

    $display("tb_arm7tdmi_core_thumb_add_addr_cycle_timing passed");
    $finish;
  end
endmodule
