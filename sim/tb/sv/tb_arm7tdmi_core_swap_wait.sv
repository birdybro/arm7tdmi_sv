`timescale 1ns/1ps

module tb_arm7tdmi_core_swap_wait
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
  logic        stall_active;
  logic        stall_write_q;
  logic [31:0] stall_wdata_q;
  int base_seen;
  int value_seen;
  int old_value_seen;
  int store_seen;
  int read_wait_cycles;
  int write_wait_cycles;
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
          $fatal(1, "swap transfer changed while stalled write=%0d/%0d data=%08x/%08x",
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
          bus_cycle !== BUS_CYCLE_NONSEQ || bus_wdata !== 32'h0000_002A) begin
        $fatal(1, "unexpected waited swap write addr=%08x size=%0d cycle=%0d data=%08x",
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
    base_seen = 0;
    value_seen = 0;
    old_value_seen = 0;
    store_seen = 0;
    read_wait_cycles = 0;
    write_wait_cycles = 0;
    loop_seen = 0;

    repeat (2) @(posedge clk);
    rst_n = 1'b1;

    for (int cycle = 0; cycle < 90; cycle++) begin
      @(posedge clk);
      #1;

      if (unsupported) begin
        $fatal(1, "unexpected unsupported instruction at pc=%08x", debug_pc);
      end
      if (bus_valid && bus_size !== BUS_SIZE_WORD) begin
        $fatal(1, "swap wait smoke expected word transfers");
      end
      if (bus_valid && !(bus_cycle inside {BUS_CYCLE_NONSEQ, BUS_CYCLE_SEQ})) begin
        $fatal(1, "swap wait smoke saw invalid cycle class");
      end
      if (!bus_ready && retired) begin
        $fatal(1, "swap should not retire while stalled");
      end
      if (!bus_ready && debug_reg_we && debug_reg_waddr == 4'd2) begin
        $fatal(1, "swap wrote destination too early while stalled");
      end

      if (debug_reg_we && debug_reg_waddr == 4'd0 && debug_reg_wdata == 32'h0000_0080) base_seen++;
      if (debug_reg_we && debug_reg_waddr == 4'd1 && debug_reg_wdata == 32'h0000_002A) value_seen++;
      if (debug_reg_we && debug_reg_waddr == 4'd2 && debug_reg_wdata == 32'hDEAD_BEEF) old_value_seen++;
      if (retired && debug_pc == 32'h0000_000C) loop_seen++;
    end

    if (read_wait_cycles != 2 || write_wait_cycles != 2) begin
      $fatal(1, "expected two wait cycles on swap read and write, saw read=%0d write=%0d",
             read_wait_cycles, write_wait_cycles);
    end
    if (base_seen != 1 || value_seen != 1 || old_value_seen != 1) begin
      $fatal(1, "expected setup/result writes once, saw base=%0d value=%0d old=%0d",
             base_seen, value_seen, old_value_seen);
    end
    if (store_seen != 1) begin
      $fatal(1, "expected one waited swap store, saw %0d", store_seen);
    end
    if (swap_word != 32'h0000_002A) begin
      $fatal(1, "unexpected waited swap memory %08x", swap_word);
    end
    if (loop_seen < 2) begin
      $fatal(1, "expected swap wait loop to retire, saw %0d", loop_seen);
    end

    $display("tb_arm7tdmi_core_swap_wait passed");
    $finish;
  end
endmodule
