`timescale 1ns/1ps

module tb_arm7tdmi_core_halfword_modes
  import arm7tdmi_pkg::*;
;
  logic clk;
  logic rst_n;
  logic [31:0] bus_addr;
  logic bus_valid;
  logic bus_write;
  arm_bus_size_t bus_size;
  logic [1:0] unused_bus_cycle;
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

  int store_seen;
  int ldrh_pre_seen;
  int ldrh_post_seen;
  int ldrsb_seen;
  int ldrsh_seen;
  int wb_82_seen;
  int wb_84_seen;
  int loop_seen;

  arm7tdmi_core dut (
    .clk_i(clk),
    .rst_ni(rst_n),
    .bus_addr_o(bus_addr),
    .bus_valid_o(bus_valid),
    .bus_write_o(bus_write),
    .bus_size_o(bus_size),
    .bus_cycle_o(unused_bus_cycle),
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
      32'h0000_0004: bus_rdata = 32'hE3A0_5002; // MOV r5, #2
      32'h0000_0008: bus_rdata = 32'hE3A0_7004; // MOV r7, #4
      32'h0000_000C: bus_rdata = 32'hE3A0_8006; // MOV r8, #6
      32'h0000_0010: bus_rdata = 32'hE3A0_1034; // MOV r1, #0x34
      32'h0000_0014: bus_rdata = 32'hE180_10B5; // STRH r1, [r0, r5]
      32'h0000_0018: bus_rdata = 32'hE1B0_20B5; // LDRH r2, [r0, r5]!
      32'h0000_001C: bus_rdata = 32'hE080_10B5; // STRH r1, [r0], r5
      32'h0000_0020: bus_rdata = 32'hE010_30B5; // LDRH r3, [r0], -r5
      32'h0000_0024: bus_rdata = 32'hE190_40D7; // LDRSB r4, [r0, r7]
      32'h0000_0028: bus_rdata = 32'hE190_60F8; // LDRSH r6, [r0, r8]
      32'h0000_002C: bus_rdata = 32'hEAFF_FFFE; // B .
      32'h0000_0082: bus_rdata = 32'h0000_0034;
      32'h0000_0084: bus_rdata = 32'h0000_5678;
      32'h0000_0086: bus_rdata = 32'h0000_0080;
      32'h0000_0088: bus_rdata = 32'h0000_8001;
      default:       bus_rdata = 32'hE1A0_0000; // MOV r0, r0
    endcase
  end

  always_ff @(posedge clk) begin
    if (bus_valid && bus_write) begin
      if (bus_addr !== 32'h0000_0082) begin
        $fatal(1, "halfword mode store expected address 0x82, got %08x", bus_addr);
      end

      if (bus_size !== BUS_SIZE_HALF) begin
        $fatal(1, "halfword mode store expected BUS_SIZE_HALF");
      end

      if (bus_wdata !== 32'h0000_0034) begin
        $fatal(1, "halfword mode store expected wdata 0x34, got %08x", bus_wdata);
      end

      store_seen <= store_seen + 1;
    end
  end

  initial begin
    rst_n = 1'b0;
    bus_ready = 1'b1;
    store_seen = 0;
    ldrh_pre_seen = 0;
    ldrh_post_seen = 0;
    ldrsb_seen = 0;
    ldrsh_seen = 0;
    wb_82_seen = 0;
    wb_84_seen = 0;
    loop_seen = 0;

    repeat (2) @(posedge clk);
    rst_n = 1'b1;

    for (int cycle = 0; cycle < 80; cycle++) begin
      @(posedge clk);
      #1;

      if (unsupported) begin
        $fatal(1, "unexpected unsupported halfword-mode instruction at pc=%08x", debug_pc);
      end

      if (bus_valid && bus_addr >= 32'h0000_0080 && bus_size === BUS_SIZE_WORD) begin
        $fatal(1, "halfword-mode data transfer used word bus size at %08x", bus_addr);
      end

      if (debug_reg_we && debug_reg_waddr == 4'd0 && debug_reg_wdata == 32'h0000_0082) begin
        wb_82_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd0 && debug_reg_wdata == 32'h0000_0084) begin
        wb_84_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd2 && debug_reg_wdata == 32'h0000_0034) begin
        ldrh_pre_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd3 && debug_reg_wdata == 32'h0000_5678) begin
        ldrh_post_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd4 && debug_reg_wdata == 32'hFFFF_FF80) begin
        ldrsb_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd6 && debug_reg_wdata == 32'hFFFF_8001) begin
        ldrsh_seen++;
      end

      if (retired && debug_pc == 32'h0000_002C) begin
        loop_seen++;
      end
    end

    if (store_seen != 2) begin
      $fatal(1, "expected two register-offset halfword stores, saw %0d", store_seen);
    end

    if (ldrh_pre_seen != 1 || ldrh_post_seen != 1 || ldrsb_seen != 1 || ldrsh_seen != 1) begin
      $fatal(1, "expected one load of each halfword mode, saw pre=%0d post=%0d sb=%0d sh=%0d",
             ldrh_pre_seen, ldrh_post_seen, ldrsb_seen, ldrsh_seen);
    end

    if (wb_82_seen != 2 || wb_84_seen != 1) begin
      $fatal(1, "expected writeback r0=0x82 twice and r0=0x84 once, saw 0x82=%0d 0x84=%0d",
             wb_82_seen, wb_84_seen);
    end

    if (loop_seen < 2) begin
      $fatal(1, "expected halfword-mode branch loop to retire at least twice, saw %0d", loop_seen);
    end

    $display("tb_arm7tdmi_core_halfword_modes passed");
    $finish;
  end
endmodule
