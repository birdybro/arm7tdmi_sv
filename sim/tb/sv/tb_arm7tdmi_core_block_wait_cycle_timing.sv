`timescale 1ns/1ps

module tb_arm7tdmi_core_block_wait_cycle_timing
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

  logic [31:0] mem0;
  logic [31:0] mem1;
  logic [31:0] mem2;
  logic        stall_active;
  logic [31:0] stall_addr_q;
  logic        stall_write_q;
  logic [31:0] stall_wdata_q;
  int sim_cycle;
  int fetch_04;
  int fetch_08;
  int fetch_0c;
  int fetch_10;
  int fetch_14;
  int fetch_18;
  int fetch_1c;
  int int_cycles_seen;
  int r4_seen;
  int r5_seen;
  int r6_seen;
  int base_wb_seen;
  int store_seen;
  int load_seen;
  int stall_store_cycles;
  int stall_load_cycles;
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
      32'h0000_0000: bus_rdata = 32'hE3A0_0080; // MOV r0, #0x80
      32'h0000_0004: bus_rdata = 32'hE3A0_1011; // MOV r1, #0x11
      32'h0000_0008: bus_rdata = 32'hE3A0_2022; // MOV r2, #0x22
      32'h0000_000C: bus_rdata = 32'hE3A0_3033; // MOV r3, #0x33
      32'h0000_0010: bus_rdata = 32'hE8A0_000E; // STMIA r0!, {r1-r3}
      32'h0000_0014: bus_rdata = 32'hE3A0_7080; // MOV r7, #0x80
      32'h0000_0018: bus_rdata = 32'hE8B7_0070; // LDMIA r7!, {r4-r6}
      32'h0000_001C: bus_rdata = 32'hEAFF_FFFE; // B .
      32'h0000_0080: bus_rdata = mem0;
      32'h0000_0084: bus_rdata = mem1;
      32'h0000_0088: bus_rdata = mem2;
      default:       bus_rdata = 32'hE1A0_0000;
    endcase
  end

  always_comb begin
    bus_ready = 1'b1;
    if (bus_valid && (bus_addr inside {32'h0000_0080, 32'h0000_0084, 32'h0000_0088})) begin
      if (bus_write && (stall_store_cycles < 3)) begin
        bus_ready = 1'b0;
      end else if (!bus_write && (stall_load_cycles < 3)) begin
        bus_ready = 1'b0;
      end
    end
  end

  always_ff @(posedge clk) begin
    if (bus_valid && !bus_ready) begin
      if (stall_active) begin
        if (bus_addr !== stall_addr_q || bus_write !== stall_write_q || bus_wdata !== stall_wdata_q) begin
          $fatal(1, "block wait timing transfer changed while stalled addr=%08x/%08x write=%0d/%0d data=%08x/%08x",
                 bus_addr, stall_addr_q, bus_write, stall_write_q, bus_wdata, stall_wdata_q);
        end
      end
      stall_active <= 1'b1;
      stall_addr_q <= bus_addr;
      stall_write_q <= bus_write;
      stall_wdata_q <= bus_wdata;

      if (bus_write) begin
        stall_store_cycles <= stall_store_cycles + 1;
      end else begin
        stall_load_cycles <= stall_load_cycles + 1;
      end
    end else begin
      stall_active <= 1'b0;
    end

    if (bus_valid && bus_ready && bus_write) begin
      if (bus_size !== BUS_SIZE_WORD) begin
        $fatal(1, "block wait timing expected word transfers");
      end
      unique case (bus_addr)
        32'h0000_0080: begin
          if (bus_wdata !== 32'h0000_0011) $fatal(1, "waited STMIA r1 mismatch %08x", bus_wdata);
          mem0 <= bus_wdata;
          store_seen <= store_seen + 1;
        end
        32'h0000_0084: begin
          if (bus_wdata !== 32'h0000_0022) $fatal(1, "waited STMIA r2 mismatch %08x", bus_wdata);
          mem1 <= bus_wdata;
          store_seen <= store_seen + 1;
        end
        32'h0000_0088: begin
          if (bus_wdata !== 32'h0000_0033) $fatal(1, "waited STMIA r3 mismatch %08x", bus_wdata);
          mem2 <= bus_wdata;
          store_seen <= store_seen + 1;
        end
        default: $fatal(1, "unexpected waited block timing store address %08x", bus_addr);
      endcase
    end else if (bus_valid && bus_ready && !bus_write &&
                 (bus_addr inside {32'h0000_0080, 32'h0000_0084, 32'h0000_0088})) begin
      load_seen <= load_seen + 1;
    end
  end

  initial begin
    rst_n = 1'b0;
    mem0 = 32'hCAFE_0000;
    mem1 = 32'hCAFE_0001;
    mem2 = 32'hCAFE_0002;
    stall_active = 1'b0;
    stall_addr_q = 32'h0;
    stall_write_q = 1'b0;
    stall_wdata_q = 32'h0;
    sim_cycle = 0;
    fetch_04 = -1;
    fetch_08 = -1;
    fetch_0c = -1;
    fetch_10 = -1;
    fetch_14 = -1;
    fetch_18 = -1;
    fetch_1c = -1;
    int_cycles_seen = 0;
    r4_seen = 0;
    r5_seen = 0;
    r6_seen = 0;
    base_wb_seen = 0;
    store_seen = 0;
    load_seen = 0;
    stall_store_cycles = 0;
    stall_load_cycles = 0;
    loop_seen = 0;

    repeat (2) @(posedge clk);
    rst_n = 1'b1;

    for (int cycle = 0; cycle < 180; cycle++) begin
      @(posedge clk);
      #1;
      sim_cycle++;

      if (bus_valid && bus_size !== BUS_SIZE_WORD) begin
        $fatal(1, "block wait timing expected word transfers");
      end
      if (bus_valid && !(bus_cycle inside {BUS_CYCLE_NONSEQ, BUS_CYCLE_SEQ})) begin
        $fatal(1, "block wait timing saw invalid cycle class %0d", bus_cycle);
      end
      if (unsupported) begin
        $fatal(1, "unexpected unsupported instruction at pc=%08x", debug_pc);
      end
      if (!bus_ready && (retired || debug_reg_we)) begin
        $fatal(1, "block transfer should not retire or write registers while stalled");
      end

      if (bus_valid) begin
        if (bus_addr == 32'h0000_0004 && fetch_04 < 0) fetch_04 = sim_cycle;
        if (bus_addr == 32'h0000_0008 && fetch_08 < 0) fetch_08 = sim_cycle;
        if (bus_addr == 32'h0000_000C && fetch_0c < 0) fetch_0c = sim_cycle;
        if (bus_addr == 32'h0000_0010 && fetch_10 < 0) fetch_10 = sim_cycle;
        if (bus_addr == 32'h0000_0014 && fetch_14 < 0) fetch_14 = sim_cycle;
        if (bus_addr == 32'h0000_0018 && fetch_18 < 0) fetch_18 = sim_cycle;
        if (bus_addr == 32'h0000_001C && fetch_1c < 0) fetch_1c = sim_cycle;
      end else if (bus_cycle == BUS_CYCLE_INT) begin
        int_cycles_seen++;
      end

      if (debug_reg_we && ((debug_reg_waddr == 4'd0 && debug_reg_wdata == 32'h0000_008C) ||
                           (debug_reg_waddr == 4'd7 && debug_reg_wdata == 32'h0000_008C))) begin
        base_wb_seen++;
      end
      if (debug_reg_we && debug_reg_waddr == 4'd4 && debug_reg_wdata == 32'h0000_0011) r4_seen++;
      if (debug_reg_we && debug_reg_waddr == 4'd5 && debug_reg_wdata == 32'h0000_0022) r5_seen++;
      if (debug_reg_we && debug_reg_waddr == 4'd6 && debug_reg_wdata == 32'h0000_0033) r6_seen++;
      if (retired && debug_pc == 32'h0000_001C) loop_seen++;
    end

    if ((fetch_04 < 0) || (fetch_08 < 0) || (fetch_0c < 0) || (fetch_10 < 0) ||
        (fetch_14 < 0) || (fetch_18 < 0) || (fetch_1c < 0)) begin
      $fatal(1, "missing block wait timing fetch timestamps");
    end
    if ((fetch_14 - fetch_10) != 9) begin
      $fatal(1, "waited STMIA with 3 beats and writeback should take 9 cycles to next fetch, saw %0d",
             fetch_14 - fetch_10);
    end
    if ((fetch_1c - fetch_18) != 9) begin
      $fatal(1, "waited LDMIA with 3 beats and writeback should take 9 cycles to next fetch, saw %0d",
             fetch_1c - fetch_18);
    end
    if (stall_store_cycles != 3 || stall_load_cycles != 3) begin
      $fatal(1, "expected one wait cycle per block beat across 3 stores and 3 loads, saw store=%0d load=%0d",
             stall_store_cycles, stall_load_cycles);
    end
    if (store_seen != 3 || load_seen != 3) begin
      $fatal(1, "expected three waited stores and loads, saw store=%0d load=%0d", store_seen, load_seen);
    end
    if (base_wb_seen != 2) begin
      $fatal(1, "expected two base writebacks, saw %0d", base_wb_seen);
    end
    if (r4_seen != 1 || r5_seen != 1 || r6_seen != 1) begin
      $fatal(1, "unexpected load scoreboard r4=%0d r5=%0d r6=%0d", r4_seen, r5_seen, r6_seen);
    end
    if (int_cycles_seen < 2) begin
      $fatal(1, "expected visible block writeback internal cycles, saw %0d", int_cycles_seen);
    end
    if (mem0 != 32'h0000_0011 || mem1 != 32'h0000_0022 || mem2 != 32'h0000_0033) begin
      $fatal(1, "unexpected final waited block memory %08x %08x %08x", mem0, mem1, mem2);
    end
    if (loop_seen < 2) begin
      $fatal(1, "expected block wait timing loop to retire, saw %0d", loop_seen);
    end

    $display("tb_arm7tdmi_core_block_wait_cycle_timing passed");
    $finish;
  end
endmodule
