`timescale 1ns/1ps

module tb_arm7tdmi_core_cycle_timing
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
  int fetch_00;
  int fetch_04;
  int fetch_08;
  int fetch_0c;
  int fetch_10;
  int fetch_14;
  int fetch_18;
  int int_cycles_seen;
  arm_bus_cycle_t cycle_04;
  arm_bus_cycle_t cycle_08;
  arm_bus_cycle_t cycle_0c;
  arm_bus_cycle_t cycle_10;
  arm_bus_cycle_t cycle_14;
  arm_bus_cycle_t cycle_18;
  int r2_seen;
  int r4_seen;
  int r5_seen;
  int r6_seen;
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
      32'h0000_0000: bus_rdata = 32'hE3A0_0001; // MOV r0, #1
      32'h0000_0004: bus_rdata = 32'hE3A0_1002; // MOV r1, #2
      32'h0000_0008: bus_rdata = 32'hE3A0_3001; // MOV r3, #1
      32'h0000_000C: bus_rdata = 32'hE080_2311; // ADD r2, r0, r1, LSL r3
      32'h0000_0010: bus_rdata = 32'hE004_0190; // MUL r4, r0, r1
      32'h0000_0014: bus_rdata = 32'hE086_5190; // UMULL r5, r6, r0, r1
      32'h0000_0018: bus_rdata = 32'hEAFF_FFFE; // B .
      default:       bus_rdata = 32'hE1A0_0000; // MOV r0, r0
    endcase
  end

  initial begin
    rst_n = 1'b0;
    bus_ready = 1'b1;
    sim_cycle = 0;
    fetch_00 = -1;
    fetch_04 = -1;
    fetch_08 = -1;
    fetch_0c = -1;
    fetch_10 = -1;
    fetch_14 = -1;
    fetch_18 = -1;
    int_cycles_seen = 0;
    cycle_04 = BUS_CYCLE_INT;
    cycle_08 = BUS_CYCLE_INT;
    cycle_0c = BUS_CYCLE_INT;
    cycle_10 = BUS_CYCLE_INT;
    cycle_14 = BUS_CYCLE_INT;
    cycle_18 = BUS_CYCLE_INT;
    r2_seen = 0;
    r4_seen = 0;
    r5_seen = 0;
    r6_seen = 0;
    loop_seen = 0;

    repeat (2) @(posedge clk);
    rst_n = 1'b1;

    for (int cycle = 0; cycle < 80; cycle++) begin
      @(posedge clk);
      #1;
      sim_cycle++;

      if (unsupported) begin
        $fatal(1, "unexpected unsupported instruction at pc=%08x", debug_pc);
      end

      if (bus_write || (bus_wdata !== 32'h0000_0000)) begin
        $fatal(1, "cycle timing test should not write memory");
      end

      if (bus_valid) begin
        if (bus_size !== BUS_SIZE_WORD) begin
          $fatal(1, "cycle timing fetch expected word size");
        end

        if (!(bus_cycle inside {BUS_CYCLE_NONSEQ, BUS_CYCLE_SEQ})) begin
          $fatal(1, "cycle timing fetch expected seq/nonseq, got %0d", bus_cycle);
        end

        unique case (bus_addr)
          32'h0000_0000: if (fetch_00 < 0) fetch_00 = sim_cycle;
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

      if (debug_reg_we && debug_reg_waddr == 4'd2 && debug_reg_wdata == 32'h0000_0005) begin
        r2_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd4 && debug_reg_wdata == 32'h0000_0002) begin
        r4_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd5 && debug_reg_wdata == 32'h0000_0002) begin
        r5_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd6 && debug_reg_wdata == 32'h0000_0000) begin
        r6_seen++;
      end

      if (retired && debug_pc == 32'h0000_0018) begin
        loop_seen++;
      end
    end

    if ((fetch_04 < 0) || (fetch_08 < 0) || (fetch_0c < 0) || (fetch_10 < 0) ||
        (fetch_14 < 0) || (fetch_18 < 0)) begin
      $fatal(1, "missing fetch timestamps 04=%0d 08=%0d 0c=%0d 10=%0d 14=%0d 18=%0d",
             fetch_04, fetch_08, fetch_0c, fetch_10, fetch_14, fetch_18);
    end

    if ((fetch_08 - fetch_04) != 2) begin
      $fatal(1, "plain MOV fetch spacing should be 2 cycles, saw %0d", fetch_08 - fetch_04);
    end
    if ((cycle_04 != BUS_CYCLE_SEQ) || (cycle_08 != BUS_CYCLE_SEQ) ||
        (cycle_0c != BUS_CYCLE_SEQ) ||
        (cycle_10 != BUS_CYCLE_SEQ) || (cycle_14 != BUS_CYCLE_SEQ) ||
        (cycle_18 != BUS_CYCLE_SEQ)) begin
      $fatal(1, "unexpected ARM follow-on fetch cycle classes 04=%0d 08=%0d 0c=%0d 10=%0d 14=%0d 18=%0d",
             cycle_04, cycle_08, cycle_0c, cycle_10, cycle_14, cycle_18);
    end

    if ((fetch_10 - fetch_0c) != 3) begin
      $fatal(1, "register-shift ADD should add one internal cycle, saw spacing %0d",
             fetch_10 - fetch_0c);
    end

    if ((fetch_14 - fetch_10) != 3) begin
      $fatal(1, "MUL should add one extra internal cycle for small multiplier, saw spacing %0d",
             fetch_14 - fetch_10);
    end

    if ((fetch_18 - fetch_14) != 4) begin
      $fatal(1, "UMULL should include extra multiply timing plus high-word writeback, saw spacing %0d",
             fetch_18 - fetch_14);
    end

    if (int_cycles_seen < 10) begin
      $fatal(1, "expected visible internal cycles in timing mode, saw %0d", int_cycles_seen);
    end

    if ((r2_seen != 1) || (r4_seen != 1) || (r5_seen != 1) || (r6_seen != 1)) begin
      $fatal(1, "expected arithmetic result writes once, saw r2=%0d r4=%0d r5=%0d r6=%0d",
             r2_seen, r4_seen, r5_seen, r6_seen);
    end

    if (loop_seen < 2) begin
      $fatal(1, "expected branch loop to retire at least twice, saw %0d", loop_seen);
    end

    if (debug_cpsr !== 32'h0000_00D3) begin
      $fatal(1, "expected multiply program to leave CPSR unchanged, got %08x", debug_cpsr);
    end

    $display("tb_arm7tdmi_core_cycle_timing passed");
    $finish;
  end
endmodule
