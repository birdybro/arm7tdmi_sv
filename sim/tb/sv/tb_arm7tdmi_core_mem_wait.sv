`timescale 1ns/1ps

module tb_arm7tdmi_core_mem_wait
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

  logic [31:0] data_word;
  logic        stall_active;
  logic [31:0] stall_addr_q;
  logic        stall_write_q;
  arm_bus_size_t stall_size_q;
  logic [31:0] stall_wdata_q;
  int value_seen;
  int load_seen;
  int store_seen;
  int loop_seen;
  int store_wait_cycles;
  int load_wait_cycles;

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
      32'h0000_0000: bus_rdata = 32'hE3A0_0040; // MOV r0, #0x40
      32'h0000_0004: bus_rdata = 32'hE3A0_102A; // MOV r1, #0x2a
      32'h0000_0008: bus_rdata = 32'hE580_1004; // STR r1, [r0, #4]
      32'h0000_000C: bus_rdata = 32'hE590_2004; // LDR r2, [r0, #4]
      32'h0000_0010: bus_rdata = 32'hEAFF_FFFE; // B .
      32'h0000_0044: bus_rdata = data_word;
      default:       bus_rdata = 32'hE1A0_0000; // MOV r0, r0
    endcase
  end

  always_comb begin
    bus_ready = 1'b1;
    if (bus_valid && bus_addr == 32'h0000_0044 && bus_size == BUS_SIZE_WORD) begin
      if (bus_write && (store_wait_cycles < 2)) begin
        bus_ready = 1'b0;
      end else if (!bus_write && (load_wait_cycles < 2)) begin
        bus_ready = 1'b0;
      end
    end
  end

  always_ff @(posedge clk) begin
    if (bus_valid && !bus_ready) begin
      if (stall_active) begin
        if (bus_addr !== stall_addr_q || bus_write !== stall_write_q ||
            bus_size !== stall_size_q || bus_wdata !== stall_wdata_q) begin
          $fatal(1, "wait-state transfer changed while stalled addr=%08x/%08x write=%0d/%0d size=%0d/%0d data=%08x/%08x",
                 bus_addr, stall_addr_q, bus_write, stall_write_q, bus_size, stall_size_q,
                 bus_wdata, stall_wdata_q);
        end
      end

      stall_active <= 1'b1;
      stall_addr_q <= bus_addr;
      stall_write_q <= bus_write;
      stall_size_q <= bus_size;
      stall_wdata_q <= bus_wdata;

      if (bus_addr == 32'h0000_0044 && bus_write) begin
        store_wait_cycles <= store_wait_cycles + 1;
      end else if (bus_addr == 32'h0000_0044 && !bus_write) begin
        load_wait_cycles <= load_wait_cycles + 1;
      end
    end else begin
      stall_active <= 1'b0;
    end

    if (bus_valid && bus_ready && bus_write) begin
      if (bus_addr !== 32'h0000_0044 || bus_size !== BUS_SIZE_WORD ||
          bus_cycle !== BUS_CYCLE_NONSEQ || bus_wdata !== 32'h0000_002A) begin
        $fatal(1, "unexpected waited store addr=%08x size=%0d cycle=%0d data=%08x",
               bus_addr, bus_size, bus_cycle, bus_wdata);
      end

      data_word <= bus_wdata;
      store_seen <= store_seen + 1;
    end
  end

  initial begin
    rst_n = 1'b0;
    data_word = 32'hCAFE_F00D;
    stall_active = 1'b0;
    stall_addr_q = 32'h0000_0000;
    stall_write_q = 1'b0;
    stall_size_q = BUS_SIZE_WORD;
    stall_wdata_q = 32'h0000_0000;
    value_seen = 0;
    load_seen = 0;
    store_seen = 0;
    loop_seen = 0;
    store_wait_cycles = 0;
    load_wait_cycles = 0;

    repeat (2) @(posedge clk);
    rst_n = 1'b1;

    for (int cycle = 0; cycle < 80; cycle++) begin
      @(posedge clk);
      #1;

      if (bus_valid && !(bus_size inside {BUS_SIZE_WORD})) begin
        $fatal(1, "wait-state smoke expected word transfers");
      end

      if (bus_valid && !(bus_cycle inside {BUS_CYCLE_NONSEQ, BUS_CYCLE_SEQ})) begin
        $fatal(1, "wait-state smoke saw invalid cycle class");
      end

      if (unsupported) begin
        $fatal(1, "unexpected unsupported instruction at pc=%08x", debug_pc);
      end

      if (!bus_ready && (debug_reg_we || retired)) begin
        $fatal(1, "core should not retire or write registers while memory is stalled");
      end

      if (debug_reg_we && debug_reg_waddr == 4'd1 && debug_reg_wdata == 32'h0000_002A) begin
        value_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd2 && debug_reg_wdata == 32'h0000_002A) begin
        load_seen++;
      end

      if (retired && debug_pc == 32'h0000_0010) begin
        loop_seen++;
      end
    end

    if (store_wait_cycles != 2 || load_wait_cycles != 2) begin
      $fatal(1, "expected two wait cycles on store and load, saw store=%0d load=%0d",
             store_wait_cycles, load_wait_cycles);
    end

    if (value_seen != 1 || store_seen != 1 || load_seen != 1) begin
      $fatal(1, "expected one setup write, waited store, and waited load, saw value=%0d store=%0d load=%0d",
             value_seen, store_seen, load_seen);
    end

    if (data_word != 32'h0000_002A) begin
      $fatal(1, "unexpected final waited memory word=%08x", data_word);
    end

    if (loop_seen < 2) begin
      $fatal(1, "expected wait-state loop to retire, saw %0d", loop_seen);
    end

    $display("tb_arm7tdmi_core_mem_wait passed");
    $finish;
  end
endmodule
