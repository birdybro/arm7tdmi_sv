`timescale 1ns/1ps

module tb_arm7tdmi_core_thumb_ls_imm_wait_cycle_timing
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

  logic [31:0] data_word;
  logic        stall_active;
  logic        stall_write_q;
  logic [31:0] stall_wdata_q;
  int sim_cycle;
  int fetch_22;
  int fetch_24;
  int fetch_26;
  int fetch_28;
  int int_cycles_seen;
  int value_seen;
  int load_seen;
  int store_seen;
  int store_wait_cycles;
  int load_wait_cycles;
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
      32'h0000_0000: bus_rdata = 32'hE3A0_6021; // MOV r6, #0x21
      32'h0000_0004: bus_rdata = 32'hE12F_FF16; // BX r6
      32'h0000_0020: bus_rdata = 32'h0000_2040; // Thumb MOV r0, #0x40
      32'h0000_0022: bus_rdata = 32'h0000_212A; // Thumb MOV r1, #0x2a
      32'h0000_0024: bus_rdata = 32'h0000_6041; // Thumb STR r1, [r0, #4]
      32'h0000_0026: bus_rdata = 32'h0000_6842; // Thumb LDR r2, [r0, #4]
      32'h0000_0028: bus_rdata = 32'h0000_E7FE; // Thumb B .
      32'h0000_0044: bus_rdata = data_word;
      default:       bus_rdata = 32'hE1A0_0000;
    endcase
  end

  always_comb begin
    bus_ready = 1'b1;
    if (bus_valid && bus_addr == 32'h0000_0044 && bus_size == BUS_SIZE_WORD) begin
      if (bus_write && store_wait_cycles < 2) begin
        bus_ready = 1'b0;
      end else if (!bus_write && load_wait_cycles < 2) begin
        bus_ready = 1'b0;
      end
    end
  end

  always_ff @(posedge clk) begin
    if (bus_valid && !bus_ready) begin
      if (stall_active && (bus_write !== stall_write_q || bus_wdata !== stall_wdata_q)) begin
        $fatal(1, "thumb LS immediate wait timing changed while stalled write=%0d/%0d data=%08x/%08x",
               bus_write, stall_write_q, bus_wdata, stall_wdata_q);
      end
      stall_active <= 1'b1;
      stall_write_q <= bus_write;
      stall_wdata_q <= bus_wdata;
      if (bus_write) store_wait_cycles <= store_wait_cycles + 1;
      else load_wait_cycles <= load_wait_cycles + 1;
    end else begin
      stall_active <= 1'b0;
    end

    if (bus_valid && bus_ready && bus_write) begin
      if (bus_addr !== 32'h0000_0044 || bus_size !== BUS_SIZE_WORD ||
          !(bus_cycle inside {BUS_CYCLE_NONSEQ, BUS_CYCLE_SEQ}) ||
          bus_wdata !== 32'h0000_002A) begin
        $fatal(1, "unexpected waited Thumb STR timing write addr=%08x size=%0d cycle=%0d data=%08x",
               bus_addr, bus_size, bus_cycle, bus_wdata);
      end
      data_word <= bus_wdata;
      store_seen <= store_seen + 1;
    end
  end

  initial begin
    rst_n = 1'b0;
    data_word = 32'hDEAD_BEEF;
    stall_active = 1'b0;
    stall_write_q = 1'b0;
    stall_wdata_q = 32'h0;
    sim_cycle = 0;
    fetch_22 = -1;
    fetch_24 = -1;
    fetch_26 = -1;
    fetch_28 = -1;
    int_cycles_seen = 0;
    value_seen = 0;
    load_seen = 0;
    store_seen = 0;
    store_wait_cycles = 0;
    load_wait_cycles = 0;
    loop_seen = 0;

    repeat (2) @(posedge clk);
    rst_n = 1'b1;

    for (int cycle = 0; cycle < 140; cycle++) begin
      @(posedge clk);
      #1;
      sim_cycle++;

      if (bus_valid && !(bus_size inside {BUS_SIZE_HALF, BUS_SIZE_WORD})) begin
        $fatal(1, "Thumb LS immediate wait timing saw invalid bus size");
      end
      if (bus_valid && !(bus_cycle inside {BUS_CYCLE_NONSEQ, BUS_CYCLE_SEQ})) begin
        $fatal(1, "Thumb LS immediate wait timing saw invalid cycle class");
      end
      if (unsupported) begin
        $fatal(1, "unexpected unsupported instruction at pc=%08x cpsr=%08x", debug_pc, debug_cpsr);
      end
      if (!bus_ready && retired) begin
        $fatal(1, "Thumb LS immediate should not retire while stalled");
      end
      if (!bus_ready && debug_reg_we && debug_reg_waddr == 4'd2) begin
        $fatal(1, "Thumb waited load wrote destination too early");
      end

      if (bus_valid) begin
        if (bus_addr == 32'h0000_0022 && fetch_22 < 0) fetch_22 = sim_cycle;
        if (bus_addr == 32'h0000_0024 && fetch_24 < 0) fetch_24 = sim_cycle;
        if (bus_addr == 32'h0000_0026 && fetch_26 < 0) fetch_26 = sim_cycle;
        if (bus_addr == 32'h0000_0028 && fetch_28 < 0) fetch_28 = sim_cycle;
      end else if (bus_cycle == BUS_CYCLE_INT) begin
        int_cycles_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd1 && debug_reg_wdata == 32'h0000_002A) value_seen++;
      if (debug_reg_we && debug_reg_waddr == 4'd2 && debug_reg_wdata == 32'h0000_002A) load_seen++;
      if (retired && debug_pc == 32'h0000_0028 && debug_cpsr[5]) loop_seen++;
    end

    if ((fetch_22 < 0) || (fetch_24 < 0) || (fetch_26 < 0) || (fetch_28 < 0)) begin
      $fatal(1, "missing Thumb LS immediate wait timing fetch timestamps");
    end
    if ((fetch_24 - fetch_22) != 2) begin
      $fatal(1, "plain Thumb MOV should fetch every 2 cycles, saw %0d", fetch_24 - fetch_22);
    end
    if ((fetch_26 - fetch_24) != 5) begin
      $fatal(1, "waited Thumb STR should take 5 cycles to next fetch, saw %0d",
             fetch_26 - fetch_24);
    end
    if ((fetch_28 - fetch_26) != 5) begin
      $fatal(1, "waited Thumb LDR should take 5 cycles to next fetch, saw %0d",
             fetch_28 - fetch_26);
    end
    if (store_wait_cycles != 2 || load_wait_cycles != 2) begin
      $fatal(1, "expected two wait cycles on Thumb STR/LDR, saw store=%0d load=%0d",
             store_wait_cycles, load_wait_cycles);
    end
    if (int_cycles_seen < 1) begin
      $fatal(1, "expected visible Thumb load writeback internal cycle, saw %0d", int_cycles_seen);
    end
    if (value_seen != 1 || store_seen != 1 || load_seen != 1) begin
      $fatal(1, "expected one Thumb setup/write/load, saw value=%0d store=%0d load=%0d",
             value_seen, store_seen, load_seen);
    end
    if (data_word != 32'h0000_002A) begin
      $fatal(1, "unexpected waited Thumb LS memory %08x", data_word);
    end
    if (loop_seen < 2) begin
      $fatal(1, "expected Thumb LS immediate wait timing loop to retire, saw %0d", loop_seen);
    end

    $display("tb_arm7tdmi_core_thumb_ls_imm_wait_cycle_timing passed");
    $finish;
  end
endmodule
