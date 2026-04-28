`timescale 1ns/1ps

module tb_arm7tdmi_core_mem_cycle_timing
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

  logic [31:0] mem54;
  logic [31:0] mem58;
  logic [31:0] mem5c;
  int sim_cycle;
  int fetch_04;
  int fetch_08;
  int fetch_0c;
  int fetch_10;
  int fetch_14;
  int fetch_18;
  arm_bus_cycle_t cycle_04;
  arm_bus_cycle_t cycle_08;
  arm_bus_cycle_t cycle_0c;
  arm_bus_cycle_t cycle_10;
  arm_bus_cycle_t cycle_14;
  arm_bus_cycle_t cycle_18;
  int int_cycles_seen;
  int store_seen;
  int post_store_seen;
  int r2_seen;
  int r3_seen;
  int r0_setup_seen;
  int r0_wb_seen;
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
      32'h0000_0000: bus_rdata = 32'hE3A0_0050; // MOV r0, #0x50
      32'h0000_0004: bus_rdata = 32'hE3A0_102A; // MOV r1, #0x2a
      32'h0000_0008: bus_rdata = 32'hE5A0_1004; // STR r1, [r0, #4]!
      32'h0000_000C: bus_rdata = 32'hE5B0_2004; // LDR r2, [r0, #4]!
      32'h0000_0010: bus_rdata = 32'hE480_1004; // STR r1, [r0], #4
      32'h0000_0014: bus_rdata = 32'hE410_3004; // LDR r3, [r0], #-4
      32'h0000_0018: bus_rdata = 32'hEAFF_FFFE; // B .
      32'h0000_0054: bus_rdata = mem54;
      32'h0000_0058: bus_rdata = mem58;
      32'h0000_005C: bus_rdata = mem5c;
      default:       bus_rdata = 32'hE1A0_0000;
    endcase
  end

  always_ff @(posedge clk) begin
    if (bus_valid && bus_write) begin
      if (bus_size !== BUS_SIZE_WORD || bus_cycle != BUS_CYCLE_NONSEQ) begin
        $fatal(1, "mem timing store expected nonseq word beat");
      end

      unique case (bus_addr)
        32'h0000_0054: begin
          if (bus_wdata !== 32'h0000_002A) begin
            $fatal(1, "writeback store expected 0x2a, got %08x", bus_wdata);
          end
          mem54 <= bus_wdata;
          store_seen <= store_seen + 1;
        end
        32'h0000_0058: begin
          if (bus_wdata !== 32'h0000_002A) begin
            $fatal(1, "post-index store expected 0x2a, got %08x", bus_wdata);
          end
          mem58 <= bus_wdata;
          post_store_seen <= post_store_seen + 1;
        end
        default: begin
          $fatal(1, "unexpected mem timing store address %08x", bus_addr);
        end
      endcase
    end
  end

  initial begin
    rst_n = 1'b0;
    bus_ready = 1'b1;
    mem54 = 32'hCAFE_0000;
    mem58 = 32'h1234_5678;
    mem5c = 32'h8765_4321;
    sim_cycle = 0;
    fetch_04 = -1;
    fetch_08 = -1;
    fetch_0c = -1;
    fetch_10 = -1;
    fetch_14 = -1;
    fetch_18 = -1;
    cycle_04 = BUS_CYCLE_INT;
    cycle_08 = BUS_CYCLE_INT;
    cycle_0c = BUS_CYCLE_INT;
    cycle_10 = BUS_CYCLE_INT;
    cycle_14 = BUS_CYCLE_INT;
    cycle_18 = BUS_CYCLE_INT;
    int_cycles_seen = 0;
    store_seen = 0;
    post_store_seen = 0;
    r2_seen = 0;
    r3_seen = 0;
    r0_setup_seen = 0;
    r0_wb_seen = 0;
    loop_seen = 0;

    repeat (2) @(posedge clk);
    rst_n = 1'b1;

    for (int cycle = 0; cycle < 90; cycle++) begin
      @(posedge clk);
      #1;
      sim_cycle++;

      if (unsupported) begin
        $fatal(1, "unexpected unsupported instruction at pc=%08x", debug_pc);
      end

      if (bus_valid) begin
        if (!(bus_size inside {BUS_SIZE_WORD})) begin
          $fatal(1, "mem timing test expected word transfers only");
        end

        if (!(bus_cycle inside {BUS_CYCLE_NONSEQ, BUS_CYCLE_SEQ})) begin
          $fatal(1, "mem timing bus_valid expected seq/nonseq, got %0d", bus_cycle);
        end

        unique case (bus_addr)
          32'h0000_0004: if (fetch_04 < 0) begin
            fetch_04 = sim_cycle;
            cycle_04 = bus_cycle;
          end
          32'h0000_0008: if (fetch_08 < 0) begin
            fetch_08 = sim_cycle;
            cycle_08 = bus_cycle;
          end
          32'h0000_000C: if (fetch_0c < 0) begin
            fetch_0c = sim_cycle;
            cycle_0c = bus_cycle;
          end
          32'h0000_0010: if (fetch_10 < 0) begin
            fetch_10 = sim_cycle;
            cycle_10 = bus_cycle;
          end
          32'h0000_0014: if (fetch_14 < 0) begin
            fetch_14 = sim_cycle;
            cycle_14 = bus_cycle;
          end
          32'h0000_0018: if (fetch_18 < 0) begin
            fetch_18 = sim_cycle;
            cycle_18 = bus_cycle;
          end
          default: begin
          end
        endcase
      end else if (bus_cycle == BUS_CYCLE_INT) begin
        int_cycles_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd0 && debug_reg_wdata == 32'h0000_0050) begin
        r0_setup_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd0 &&
          (debug_reg_wdata inside {32'h0000_0054, 32'h0000_0058, 32'h0000_005C})) begin
        r0_wb_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd2 && debug_reg_wdata == 32'h1234_5678) begin
        r2_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd3 && debug_reg_wdata == 32'h8765_4321) begin
        r3_seen++;
      end

      if (retired && debug_pc == 32'h0000_0018) begin
        loop_seen++;
      end
    end

    if ((fetch_04 < 0) || (fetch_08 < 0) || (fetch_0c < 0) ||
        (fetch_10 < 0) || (fetch_14 < 0) || (fetch_18 < 0)) begin
      $fatal(1, "missing mem timing fetch timestamps");
    end

    if ((cycle_04 != BUS_CYCLE_SEQ) || (cycle_08 != BUS_CYCLE_SEQ) ||
        (cycle_0c != BUS_CYCLE_NONSEQ) || (cycle_10 != BUS_CYCLE_NONSEQ) ||
        (cycle_14 != BUS_CYCLE_NONSEQ) || (cycle_18 != BUS_CYCLE_NONSEQ)) begin
      $fatal(1, "unexpected mem timing fetch cycle classes %0d %0d %0d %0d %0d %0d",
             cycle_04, cycle_08, cycle_0c, cycle_10, cycle_14, cycle_18);
    end

    if ((fetch_0c - fetch_08) != 3) begin
      $fatal(1, "pre-index writeback store should take 3 cycles to next fetch, saw %0d",
             fetch_0c - fetch_08);
    end

    if ((fetch_10 - fetch_0c) != 4) begin
      $fatal(1, "pre-index writeback load should take 4 cycles to next fetch, saw %0d",
             fetch_10 - fetch_0c);
    end

    if ((fetch_14 - fetch_10) != 3) begin
      $fatal(1, "post-index store should take 3 cycles to next fetch, saw %0d",
             fetch_14 - fetch_10);
    end

    if ((fetch_18 - fetch_14) != 4) begin
      $fatal(1, "post-index load should take 4 cycles to next fetch, saw %0d",
             fetch_18 - fetch_14);
    end

    if (int_cycles_seen < 2) begin
      $fatal(1, "expected visible load-writeback internal cycles, saw %0d", int_cycles_seen);
    end

    if (store_seen != 1 || post_store_seen != 1 || r2_seen != 1 || r3_seen != 1 ||
        r0_setup_seen != 1 || r0_wb_seen != 4) begin
      $fatal(1, "unexpected mem timing observations store=%0d post_store=%0d r2=%0d r3=%0d r0_setup=%0d r0_wb=%0d",
             store_seen, post_store_seen, r2_seen, r3_seen, r0_setup_seen, r0_wb_seen);
    end

    if (loop_seen < 2) begin
      $fatal(1, "expected mem timing loop to retire at least twice, saw %0d", loop_seen);
    end

    $display("tb_arm7tdmi_core_mem_cycle_timing passed");
    $finish;
  end
endmodule
