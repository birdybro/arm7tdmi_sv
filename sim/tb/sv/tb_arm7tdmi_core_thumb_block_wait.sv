`timescale 1ns/1ps

module tb_arm7tdmi_core_thumb_block_wait
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

  logic        stall_active;
  logic [31:0] stall_addr_q;
  logic [31:0] stall_wdata_q;
  int stm_seen;
  int ldm_seen;
  int wb_store_seen;
  int wb_load_seen;
  int store_wait_cycles;
  int load_wait_cycles;
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
      32'h0000_0000: bus_rdata = 32'hE3A0_0011;
      32'h0000_0004: bus_rdata = 32'hE3A0_1022;
      32'h0000_0008: bus_rdata = 32'hE3A0_2033;
      32'h0000_000C: bus_rdata = 32'hE3A0_3040;
      32'h0000_0010: bus_rdata = 32'hE3A0_7050;
      32'h0000_0014: bus_rdata = 32'hE3A0_6021;
      32'h0000_0018: bus_rdata = 32'hE12F_FF16;
      32'h0000_0020: bus_rdata = 32'h0000_C307;
      32'h0000_0022: bus_rdata = 32'h0000_CF70;
      32'h0000_0024: bus_rdata = 32'h0000_E7FE;
      32'h0000_0050: bus_rdata = 32'h0000_0044;
      32'h0000_0054: bus_rdata = 32'h0000_0055;
      32'h0000_0058: bus_rdata = 32'h0000_0066;
      default:       bus_rdata = 32'hE1A0_0000;
    endcase
  end

  always_comb begin
    bus_ready = 1'b1;
    if (bus_valid && (bus_addr inside {32'h0000_0040, 32'h0000_0044, 32'h0000_0048,
                                       32'h0000_0050, 32'h0000_0054, 32'h0000_0058})) begin
      if (bus_write && store_wait_cycles < 3) begin
        bus_ready = 1'b0;
      end else if (!bus_write && load_wait_cycles < 3) begin
        bus_ready = 1'b0;
      end
    end
  end

  always_ff @(posedge clk) begin
    if (bus_valid && !bus_ready) begin
      if (stall_active && (bus_addr !== stall_addr_q || bus_wdata !== stall_wdata_q)) begin
        $fatal(1, "Thumb block changed while stalled addr=%08x/%08x data=%08x/%08x",
               bus_addr, stall_addr_q, bus_wdata, stall_wdata_q);
      end
      stall_active <= 1'b1;
      stall_addr_q <= bus_addr;
      stall_wdata_q <= bus_wdata;
      if (bus_write) store_wait_cycles <= store_wait_cycles + 1;
      else load_wait_cycles <= load_wait_cycles + 1;
    end else begin
      stall_active <= 1'b0;
    end
  end

  initial begin
    rst_n = 1'b0;
    stall_active = 1'b0;
    stall_addr_q = 32'h0;
    stall_wdata_q = 32'h0;
    stm_seen = 0;
    ldm_seen = 0;
    wb_store_seen = 0;
    wb_load_seen = 0;
    store_wait_cycles = 0;
    load_wait_cycles = 0;
    loop_seen = 0;

    repeat (2) @(posedge clk);
    rst_n = 1'b1;

    for (int cycle = 0; cycle < 180; cycle++) begin
      @(posedge clk);
      #1;

      if (bus_valid && !(bus_size inside {BUS_SIZE_HALF, BUS_SIZE_WORD})) begin
        $fatal(1, "Thumb block wait saw invalid bus size");
      end
      if (bus_valid && !(bus_cycle inside {BUS_CYCLE_NONSEQ, BUS_CYCLE_SEQ})) begin
        $fatal(1, "Thumb block wait saw invalid cycle class");
      end
      if (unsupported) begin
        $fatal(1, "unexpected unsupported instruction at pc=%08x cpsr=%08x", debug_pc, debug_cpsr);
      end
      if (!bus_ready && retired) begin
        $fatal(1, "Thumb block should not retire while stalled");
      end
      if (!bus_ready && debug_reg_we && (debug_reg_waddr inside {4'd4, 4'd5, 4'd6})) begin
        $fatal(1, "Thumb block wrote load destination too early");
      end

      if (bus_valid && bus_ready && bus_write) stm_seen++;
      if (debug_reg_we && debug_reg_waddr == 4'd3 && debug_reg_wdata == 32'h0000_004C) wb_store_seen++;
      if (debug_reg_we && debug_reg_waddr == 4'd4 && debug_reg_wdata == 32'h0000_0044) ldm_seen++;
      if (debug_reg_we && debug_reg_waddr == 4'd5 && debug_reg_wdata == 32'h0000_0055) ldm_seen++;
      if (debug_reg_we && debug_reg_waddr == 4'd6 && debug_reg_wdata == 32'h0000_0066) ldm_seen++;
      if (debug_reg_we && debug_reg_waddr == 4'd7 && debug_reg_wdata == 32'h0000_005C) wb_load_seen++;
      if (retired && debug_pc == 32'h0000_0024 && debug_cpsr[5]) loop_seen++;
    end

    if (store_wait_cycles != 3 || load_wait_cycles != 3) begin
      $fatal(1, "expected three wait cycles on Thumb block store/load beats, saw store=%0d load=%0d",
             store_wait_cycles, load_wait_cycles);
    end
    if (stm_seen != 3 || ldm_seen != 3) begin
      $fatal(1, "expected three Thumb block stores and loads, saw stm=%0d ldm=%0d", stm_seen, ldm_seen);
    end
    if (wb_store_seen != 1 || wb_load_seen != 1) begin
      $fatal(1, "expected one Thumb block writeback each, saw store=%0d load=%0d", wb_store_seen, wb_load_seen);
    end
    if (loop_seen < 2) begin
      $fatal(1, "expected Thumb block wait loop to retire, saw %0d", loop_seen);
    end

    $display("tb_arm7tdmi_core_thumb_block_wait passed");
    $finish;
  end
endmodule
