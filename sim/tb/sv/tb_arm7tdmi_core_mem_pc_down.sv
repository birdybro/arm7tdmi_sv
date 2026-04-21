`timescale 1ns/1ps

module tb_arm7tdmi_core_mem_pc_down
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

  logic [31:0] literal_word;
  logic [7:0]  literal_byte;
  int word_read_seen;
  int byte_store_seen;
  int byte_load_seen;
  int setup_seen;
  int word_load_seen;
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
      32'h0000_0000: bus_rdata = 32'hEA00_0002; // B 0x10
      32'h0000_0004: bus_rdata = literal_word;
      32'h0000_0008: bus_rdata = {24'h0, literal_byte};
      32'h0000_0010: bus_rdata = 32'hE3A0_108C; // MOV r1, #0x8c
      32'h0000_0014: bus_rdata = 32'hE51F_2018; // LDR r2, [pc, #-0x18]
      32'h0000_0018: bus_rdata = 32'hE54F_1018; // STRB r1, [pc, #-0x18]
      32'h0000_001C: bus_rdata = 32'hE55F_301C; // LDRB r3, [pc, #-0x1c]
      32'h0000_0020: bus_rdata = 32'hEAFF_FFFE; // B .
      default:       bus_rdata = 32'hE1A0_0000; // MOV r0, r0
    endcase
  end

  always_ff @(posedge clk) begin
    if (bus_valid && bus_write) begin
      if (bus_addr !== 32'h0000_0008 || bus_size !== BUS_SIZE_BYTE ||
          bus_cycle !== BUS_CYCLE_NONSEQ || bus_wdata[7:0] !== 8'h8C) begin
        $fatal(1, "unexpected negative pc-relative STRB addr=%08x size=%0d cycle=%0d data=%08x",
               bus_addr, bus_size, bus_cycle, bus_wdata);
      end

      literal_byte <= bus_wdata[7:0];
      byte_store_seen <= byte_store_seen + 1;
    end
  end

  initial begin
    rst_n = 1'b0;
    bus_ready = 1'b1;
    literal_word = 32'h1234_5678;
    literal_byte = 8'hD4;
    word_read_seen = 0;
    byte_store_seen = 0;
    byte_load_seen = 0;
    setup_seen = 0;
    word_load_seen = 0;
    loop_seen = 0;

    repeat (2) @(posedge clk);
    rst_n = 1'b1;

    for (int cycle = 0; cycle < 70; cycle++) begin
      @(posedge clk);
      #1;

      if (bus_valid && bus_addr == 32'h0000_0008 && bus_size !== BUS_SIZE_BYTE) begin
        $fatal(1, "negative pc-relative smoke expected byte access at 0x08");
      end

      if (bus_valid && bus_addr != 32'h0000_0008 && bus_size !== BUS_SIZE_WORD) begin
        $fatal(1, "negative pc-relative smoke expected word fetch/load accesses elsewhere");
      end

      if (bus_valid && !(bus_cycle inside {BUS_CYCLE_NONSEQ, BUS_CYCLE_SEQ})) begin
        $fatal(1, "negative pc-relative smoke saw invalid cycle class");
      end

      if (unsupported) begin
        $fatal(1, "unexpected unsupported instruction at pc=%08x", debug_pc);
      end

      if (bus_valid && !bus_write && bus_addr == 32'h0000_0004) begin
        word_read_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd1 && debug_reg_wdata == 32'h0000_008C) begin
        setup_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd2 && debug_reg_wdata == 32'h1234_5678) begin
        word_load_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd3 && debug_reg_wdata == 32'h0000_008C) begin
        byte_load_seen++;
      end

      if (retired && debug_pc == 32'h0000_0020) begin
        loop_seen++;
      end
    end

    if (setup_seen != 1 || word_load_seen != 1 || byte_load_seen != 1) begin
      $fatal(1, "expected one setup, one negative LDR, and one negative LDRB; saw setup=%0d word=%0d byte=%0d",
             setup_seen, word_load_seen, byte_load_seen);
    end

    if (word_read_seen != 1 || byte_store_seen != 1) begin
      $fatal(1, "expected one negative literal read and one negative STRB store; saw read=%0d store=%0d",
             word_read_seen, byte_store_seen);
    end

    if (literal_word !== 32'h1234_5678 || literal_byte !== 8'h8C) begin
      $fatal(1, "unexpected final literal state word=%08x byte=%02x", literal_word, literal_byte);
    end

    if (loop_seen < 2) begin
      $fatal(1, "expected negative pc-relative loop to retire, saw %0d", loop_seen);
    end

    $display("tb_arm7tdmi_core_mem_pc_down passed");
    $finish;
  end
endmodule
