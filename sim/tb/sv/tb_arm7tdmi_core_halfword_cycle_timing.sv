`timescale 1ns/1ps

module tb_arm7tdmi_core_halfword_cycle_timing
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

  logic [15:0] mem82;
  int sim_cycle;
  int fetch_14;
  int fetch_18;
  int fetch_1c;
  int fetch_20;
  int fetch_24;
  int fetch_28;
  int fetch_2c;
  int int_cycles_seen;
  int store_seen;
  int ldrh_pre_seen;
  int ldrh_post_seen;
  int ldrsb_seen;
  int ldrsh_seen;
  int wb_82_seen;
  int wb_84_seen;
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
      32'h0000_0082: bus_rdata = {16'h0000, mem82};
      32'h0000_0084: bus_rdata = 32'h0000_5678;
      32'h0000_0086: bus_rdata = 32'h0000_0080;
      32'h0000_0088: bus_rdata = 32'h0000_8001;
      default:       bus_rdata = 32'hE1A0_0000;
    endcase
  end

  always_ff @(posedge clk) begin
    if (bus_valid && bus_write) begin
      if (bus_addr !== 32'h0000_0082 || bus_size !== BUS_SIZE_HALF ||
          bus_cycle !== BUS_CYCLE_NONSEQ || bus_wdata !== 32'h0000_0034) begin
        $fatal(1, "unexpected halfword timing store addr=%08x size=%0d cycle=%0d data=%08x",
               bus_addr, bus_size, bus_cycle, bus_wdata);
      end

      mem82 <= bus_wdata[15:0];
      store_seen <= store_seen + 1;
    end
  end

  initial begin
    rst_n = 1'b0;
    bus_ready = 1'b1;
    mem82 = 16'h0034;
    sim_cycle = 0;
    fetch_14 = -1;
    fetch_18 = -1;
    fetch_1c = -1;
    fetch_20 = -1;
    fetch_24 = -1;
    fetch_28 = -1;
    fetch_2c = -1;
    int_cycles_seen = 0;
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

    for (int cycle = 0; cycle < 110; cycle++) begin
      @(posedge clk);
      #1;
      sim_cycle++;

      if (unsupported) begin
        $fatal(1, "unexpected unsupported halfword timing instruction at pc=%08x", debug_pc);
      end

      if (bus_valid) begin
        if (!(bus_cycle inside {BUS_CYCLE_NONSEQ, BUS_CYCLE_SEQ})) begin
          $fatal(1, "halfword timing saw invalid cycle class %0d", bus_cycle);
        end

        unique case (bus_addr)
          32'h0000_0014: if (fetch_14 < 0) fetch_14 = sim_cycle;
          32'h0000_0018: if (fetch_18 < 0) fetch_18 = sim_cycle;
          32'h0000_001C: if (fetch_1c < 0) fetch_1c = sim_cycle;
          32'h0000_0020: if (fetch_20 < 0) fetch_20 = sim_cycle;
          32'h0000_0024: if (fetch_24 < 0) fetch_24 = sim_cycle;
          32'h0000_0028: if (fetch_28 < 0) fetch_28 = sim_cycle;
          32'h0000_002C: if (fetch_2c < 0) fetch_2c = sim_cycle;
          32'h0000_0082: begin
            if (bus_size !== BUS_SIZE_HALF) begin
              $fatal(1, "halfword timing expected halfword transfer at 0x82");
            end
          end
          32'h0000_0084: begin
            if (bus_size !== BUS_SIZE_HALF) begin
              $fatal(1, "halfword timing expected halfword transfer at 0x84");
            end
          end
          32'h0000_0086: begin
            if (bus_size !== BUS_SIZE_BYTE) begin
              $fatal(1, "halfword timing expected byte transfer at 0x86");
            end
          end
          32'h0000_0088: begin
            if (bus_size !== BUS_SIZE_HALF) begin
              $fatal(1, "halfword timing expected halfword transfer at 0x88");
            end
          end
          default: begin
            if (bus_size !== BUS_SIZE_WORD) begin
              $fatal(1, "halfword timing expected word fetch size at %08x", bus_addr);
            end
          end
        endcase
      end else if (bus_cycle == BUS_CYCLE_INT) begin
        int_cycles_seen++;
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

    if ((fetch_14 < 0) || (fetch_18 < 0) || (fetch_1c < 0) || (fetch_20 < 0) ||
        (fetch_24 < 0) || (fetch_28 < 0) || (fetch_2c < 0)) begin
      $fatal(1, "missing halfword timing fetch timestamps");
    end

    if ((fetch_18 - fetch_14) != 3) begin
      $fatal(1, "register-offset STRH should take 3 cycles to next fetch, saw %0d",
             fetch_18 - fetch_14);
    end

    if ((fetch_1c - fetch_18) != 4) begin
      $fatal(1, "pre-index writeback LDRH should take 4 cycles to next fetch, saw %0d",
             fetch_1c - fetch_18);
    end

    if ((fetch_20 - fetch_1c) != 3) begin
      $fatal(1, "post-index STRH should take 3 cycles to next fetch, saw %0d",
             fetch_20 - fetch_1c);
    end

    if ((fetch_24 - fetch_20) != 4) begin
      $fatal(1, "post-index writeback LDRH should take 4 cycles to next fetch, saw %0d",
             fetch_24 - fetch_20);
    end

    if ((fetch_28 - fetch_24) != 3) begin
      $fatal(1, "LDRSB should take 3 cycles to next fetch, saw %0d",
             fetch_28 - fetch_24);
    end

    if ((fetch_2c - fetch_28) != 3) begin
      $fatal(1, "LDRSH should take 3 cycles to next fetch, saw %0d",
             fetch_2c - fetch_28);
    end

    if (int_cycles_seen < 2) begin
      $fatal(1, "expected visible halfword load writeback internal cycles, saw %0d",
             int_cycles_seen);
    end

    if (store_seen != 2 || ldrh_pre_seen != 1 || ldrh_post_seen != 1 ||
        ldrsb_seen != 1 || ldrsh_seen != 1 || wb_82_seen != 2 || wb_84_seen != 1) begin
      $fatal(1, "unexpected halfword timing observations store=%0d pre=%0d post=%0d sb=%0d sh=%0d wb82=%0d wb84=%0d",
             store_seen, ldrh_pre_seen, ldrh_post_seen, ldrsb_seen, ldrsh_seen,
             wb_82_seen, wb_84_seen);
    end

    if (loop_seen < 2) begin
      $fatal(1, "expected halfword timing loop to retire at least twice, saw %0d", loop_seen);
    end

    $display("tb_arm7tdmi_core_halfword_cycle_timing passed");
    $finish;
  end
endmodule
