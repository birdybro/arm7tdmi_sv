`timescale 1ns/1ps

module tb_arm7tdmi_core_swap_wait_cycle_timing
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

  logic [31:0] swap_word;
  logic stall_active;
  logic stall_write_q;
  logic [31:0] stall_wdata_q;
  int sim_cycle;
  int fetch_04;
  int fetch_08;
  int fetch_0c;
  arm_bus_cycle_t cycle_04;
  arm_bus_cycle_t cycle_08;
  arm_bus_cycle_t cycle_0c;
  int int_cycles_seen;
  int store_seen;
  int old_value_seen;
  int read_wait_cycles;
  int write_wait_cycles;
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
      32'h0000_0004: bus_rdata = 32'hE3A0_102A; // MOV r1, #0x2a
      32'h0000_0008: bus_rdata = 32'hE100_2091; // SWP r2, r1, [r0]
      32'h0000_000C: bus_rdata = 32'hEAFF_FFFE; // B .
      32'h0000_0080: bus_rdata = swap_word;
      default:       bus_rdata = 32'hE1A0_0000;
    endcase
  end

  always_comb begin
    bus_ready = 1'b1;
    if (bus_valid && bus_addr == 32'h0000_0080 && bus_size == BUS_SIZE_WORD) begin
      if (!bus_write && read_wait_cycles < 2) begin
        bus_ready = 1'b0;
      end else if (bus_write && write_wait_cycles < 2) begin
        bus_ready = 1'b0;
      end
    end
  end

  always_ff @(posedge clk) begin
    if (bus_valid && !bus_ready) begin
      if (stall_active) begin
        if (bus_write !== stall_write_q || bus_wdata !== stall_wdata_q) begin
          $fatal(1, "swap wait timing transfer changed while stalled write=%0d/%0d data=%08x/%08x",
                 bus_write, stall_write_q, bus_wdata, stall_wdata_q);
        end
      end
      stall_active <= 1'b1;
      stall_write_q <= bus_write;
      stall_wdata_q <= bus_wdata;

      if (bus_write) begin
        write_wait_cycles <= write_wait_cycles + 1;
      end else begin
        read_wait_cycles <= read_wait_cycles + 1;
      end
    end else begin
      stall_active <= 1'b0;
    end

    if (bus_valid && bus_ready && bus_write) begin
      if (bus_addr !== 32'h0000_0080 || bus_size !== BUS_SIZE_WORD ||
          !(bus_cycle inside {BUS_CYCLE_NONSEQ, BUS_CYCLE_SEQ}) ||
          bus_wdata !== 32'h0000_002A) begin
        $fatal(1, "unexpected waited swap timing write addr=%08x size=%0d cycle=%0d data=%08x",
               bus_addr, bus_size, bus_cycle, bus_wdata);
      end
      swap_word <= bus_wdata;
      store_seen <= store_seen + 1;
    end
  end

  initial begin
    rst_n = 1'b0;
    swap_word = 32'hDEAD_BEEF;
    stall_active = 1'b0;
    stall_write_q = 1'b0;
    stall_wdata_q = 32'h0;
    sim_cycle = 0;
    fetch_04 = -1;
    fetch_08 = -1;
    fetch_0c = -1;
    cycle_04 = BUS_CYCLE_INT;
    cycle_08 = BUS_CYCLE_INT;
    cycle_0c = BUS_CYCLE_INT;
    int_cycles_seen = 0;
    store_seen = 0;
    old_value_seen = 0;
    read_wait_cycles = 0;
    write_wait_cycles = 0;
    loop_seen = 0;

    repeat (2) @(posedge clk);
    rst_n = 1'b1;

    for (int cycle = 0; cycle < 110; cycle++) begin
      @(posedge clk);
      #1;
      sim_cycle++;

      if (unsupported) begin
        $fatal(1, "unexpected unsupported swap wait timing instruction at pc=%08x", debug_pc);
      end
      if (bus_valid && bus_size !== BUS_SIZE_WORD) begin
        $fatal(1, "swap wait timing expected word transfers");
      end
      if (bus_valid && !(bus_cycle inside {BUS_CYCLE_NONSEQ, BUS_CYCLE_SEQ})) begin
        $fatal(1, "swap wait timing saw invalid cycle class %0d", bus_cycle);
      end
      if (!bus_ready && retired) begin
        $fatal(1, "swap should not retire while stalled");
      end
      if (!bus_ready && debug_reg_we && debug_reg_waddr == 4'd2) begin
        $fatal(1, "swap wrote destination too early while stalled");
      end

      if (bus_valid) begin
        if (bus_addr == 32'h0000_0004 && fetch_04 < 0) begin
          fetch_04 = sim_cycle;
          cycle_04 = bus_cycle;
        end
        if (bus_addr == 32'h0000_0008 && fetch_08 < 0) begin
          fetch_08 = sim_cycle;
          cycle_08 = bus_cycle;
        end
        if (bus_addr == 32'h0000_000C && fetch_0c < 0) begin
          fetch_0c = sim_cycle;
          cycle_0c = bus_cycle;
        end
      end else if (bus_cycle == BUS_CYCLE_INT) begin
        int_cycles_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd2 && debug_reg_wdata == 32'hDEAD_BEEF) begin
        old_value_seen++;
      end
      if (retired && debug_pc == 32'h0000_000C) begin
        loop_seen++;
      end
    end

    if ((fetch_04 < 0) || (fetch_08 < 0) || (fetch_0c < 0)) begin
      $fatal(1, "missing swap wait timing fetch timestamps");
    end
    if ((cycle_04 != BUS_CYCLE_SEQ) || (cycle_08 != BUS_CYCLE_SEQ) ||
        (cycle_0c != BUS_CYCLE_NONSEQ)) begin
      $fatal(1, "unexpected swap wait timing fetch cycle classes 04=%0d 08=%0d 0c=%0d",
             cycle_04, cycle_08, cycle_0c);
    end
    if ((fetch_08 - fetch_04) != 2) begin
      $fatal(1, "plain MOV fetch spacing should be 2 cycles, saw %0d", fetch_08 - fetch_04);
    end
    if ((fetch_0c - fetch_08) != 9) begin
      $fatal(1, "waited SWP should take 9 cycles to next fetch, saw %0d", fetch_0c - fetch_08);
    end
    if (read_wait_cycles != 2 || write_wait_cycles != 2) begin
      $fatal(1, "expected two wait cycles on swap read and write, saw read=%0d write=%0d",
             read_wait_cycles, write_wait_cycles);
    end
    if (int_cycles_seen < 1) begin
      $fatal(1, "expected visible swap writeback internal cycle, saw %0d", int_cycles_seen);
    end
    if (store_seen != 1 || old_value_seen != 1) begin
      $fatal(1, "expected one waited swap store and result write, saw store=%0d old=%0d",
             store_seen, old_value_seen);
    end
    if (swap_word != 32'h0000_002A) begin
      $fatal(1, "unexpected waited swap memory %08x", swap_word);
    end
    if (loop_seen < 2) begin
      $fatal(1, "expected swap wait timing loop to retire, saw %0d", loop_seen);
    end

    $display("tb_arm7tdmi_core_swap_wait_cycle_timing passed");
    $finish;
  end
endmodule
