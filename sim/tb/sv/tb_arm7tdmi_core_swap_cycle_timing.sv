`timescale 1ns/1ps

module tb_arm7tdmi_core_swap_cycle_timing
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
  int sim_cycle;
  int fetch_04;
  int fetch_08;
  int fetch_0c;
  int fetch_10;
  int fetch_14;
  int int_cycles_seen;
  int word_store_seen;
  int byte_store_seen;
  int old_word_seen;
  int old_byte_seen;
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
      32'h0000_000C: bus_rdata = 32'hE3A0_3055; // MOV r3, #0x55
      32'h0000_0010: bus_rdata = 32'hE140_4093; // SWPB r4, r3, [r0]
      32'h0000_0014: bus_rdata = 32'hEAFF_FFFE; // B .
      32'h0000_0080: bus_rdata = swap_word;
      default:       bus_rdata = 32'hE1A0_0000;
    endcase
  end

  always_ff @(posedge clk) begin
    if (bus_valid && bus_write) begin
      if (bus_addr != 32'h0000_0080 || !(bus_cycle inside {BUS_CYCLE_NONSEQ, BUS_CYCLE_SEQ})) begin
        $fatal(1, "unexpected swap timing write addr=%08x cycle=%0d", bus_addr, bus_cycle);
      end

      if (bus_size == BUS_SIZE_WORD) begin
        if (bus_wdata !== 32'h0000_002A) begin
          $fatal(1, "SWP expected word store 0x2a, got %08x", bus_wdata);
        end
        swap_word <= bus_wdata;
        word_store_seen <= word_store_seen + 1;
      end else if (bus_size == BUS_SIZE_BYTE) begin
        if (bus_wdata !== 32'h0000_0055) begin
          $fatal(1, "SWPB expected byte store 0x55, got %08x", bus_wdata);
        end
        swap_word <= {swap_word[31:8], bus_wdata[7:0]};
        byte_store_seen <= byte_store_seen + 1;
      end else begin
        $fatal(1, "swap timing expected word or byte store");
      end
    end
  end

  initial begin
    rst_n = 1'b0;
    bus_ready = 1'b1;
    swap_word = 32'hDEAD_BEEF;
    sim_cycle = 0;
    fetch_04 = -1;
    fetch_08 = -1;
    fetch_0c = -1;
    fetch_10 = -1;
    fetch_14 = -1;
    int_cycles_seen = 0;
    word_store_seen = 0;
    byte_store_seen = 0;
    old_word_seen = 0;
    old_byte_seen = 0;
    loop_seen = 0;

    repeat (2) @(posedge clk);
    rst_n = 1'b1;

    for (int cycle = 0; cycle < 90; cycle++) begin
      @(posedge clk);
      #1;
      sim_cycle++;

      if (unsupported) begin
        $fatal(1, "unexpected unsupported swap timing instruction at pc=%08x", debug_pc);
      end

      if (bus_valid) begin
        if (!(bus_size inside {BUS_SIZE_WORD, BUS_SIZE_BYTE})) begin
          $fatal(1, "swap timing saw invalid bus size %0d", bus_size);
        end
        if (!(bus_cycle inside {BUS_CYCLE_NONSEQ, BUS_CYCLE_SEQ})) begin
          $fatal(1, "swap timing saw invalid cycle class %0d", bus_cycle);
        end

        unique case (bus_addr)
          32'h0000_0004: if (fetch_04 < 0) fetch_04 = sim_cycle;
          32'h0000_0008: if (fetch_08 < 0) fetch_08 = sim_cycle;
          32'h0000_000C: if (fetch_0c < 0) fetch_0c = sim_cycle;
          32'h0000_0010: if (fetch_10 < 0) fetch_10 = sim_cycle;
          32'h0000_0014: if (fetch_14 < 0) fetch_14 = sim_cycle;
          32'h0000_0080: begin
          end
          default: begin
          end
        endcase
      end else if (bus_cycle == BUS_CYCLE_INT) begin
        int_cycles_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd2 && debug_reg_wdata == 32'hDEAD_BEEF) begin
        old_word_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd4 && debug_reg_wdata == 32'h0000_002A) begin
        old_byte_seen++;
      end

      if (retired && debug_pc == 32'h0000_0014) begin
        loop_seen++;
      end
    end

    if ((fetch_04 < 0) || (fetch_08 < 0) || (fetch_0c < 0) || (fetch_10 < 0) || (fetch_14 < 0)) begin
      $fatal(1, "missing swap timing fetch timestamps");
    end

    if ((fetch_08 - fetch_04) != 2) begin
      $fatal(1, "plain MOV fetch spacing should be 2 cycles, saw %0d", fetch_08 - fetch_04);
    end

    if ((fetch_0c - fetch_08) != 5) begin
      $fatal(1, "SWP should take 5 cycles to next fetch, saw %0d", fetch_0c - fetch_08);
    end

    if ((fetch_14 - fetch_10) != 5) begin
      $fatal(1, "SWPB should take 5 cycles to next fetch, saw %0d", fetch_14 - fetch_10);
    end

    if (int_cycles_seen < 2) begin
      $fatal(1, "expected visible swap writeback internal cycles, saw %0d", int_cycles_seen);
    end

    if (word_store_seen != 1 || byte_store_seen != 1 || old_word_seen != 1 || old_byte_seen != 1) begin
      $fatal(1, "unexpected swap timing observations word_store=%0d byte_store=%0d old_word=%0d old_byte=%0d",
             word_store_seen, byte_store_seen, old_word_seen, old_byte_seen);
    end

    if (swap_word !== 32'h0000_0055) begin
      $fatal(1, "expected final swapped memory 0x55, got %08x", swap_word);
    end

    if (loop_seen < 2) begin
      $fatal(1, "expected swap timing loop to retire at least twice, saw %0d", loop_seen);
    end

    $display("tb_arm7tdmi_core_swap_cycle_timing passed");
    $finish;
  end
endmodule
