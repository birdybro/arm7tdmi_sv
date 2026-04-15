`timescale 1ns/1ps

module tb_arm7tdmi_core_swap
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
  int base_seen;
  int word_value_seen;
  int byte_value_seen;
  int old_word_seen;
  int old_byte_seen;
  int word_store_seen;
  int byte_store_seen;
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
      32'h0000_000C: bus_rdata = 32'hE3A0_3055; // MOV r3, #0x55
      32'h0000_0010: bus_rdata = 32'hE140_4093; // SWPB r4, r3, [r0]
      32'h0000_0014: bus_rdata = 32'hEAFF_FFFE; // B .
      32'h0000_0080: bus_rdata = swap_word;
      default:       bus_rdata = 32'hE1A0_0000; // MOV r0, r0
    endcase
  end

  always_ff @(posedge clk) begin
    if (bus_valid && bus_write) begin
      if (bus_addr != 32'h0000_0080 || bus_cycle !== BUS_CYCLE_NONSEQ) begin
        $fatal(1, "unexpected swap write addr=%08x cycle=%0d", bus_addr, bus_cycle);
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
        $fatal(1, "swap expected word or byte store");
      end
    end
  end

  initial begin
    rst_n = 1'b0;
    bus_ready = 1'b1;
    swap_word = 32'hDEAD_BEEF;
    base_seen = 0;
    word_value_seen = 0;
    byte_value_seen = 0;
    old_word_seen = 0;
    old_byte_seen = 0;
    word_store_seen = 0;
    byte_store_seen = 0;
    loop_seen = 0;

    repeat (2) @(posedge clk);
    rst_n = 1'b1;

    for (int cycle = 0; cycle < 80; cycle++) begin
      @(posedge clk);
      #1;

      if (unsupported) begin
        $fatal(1, "unexpected unsupported instruction at pc=%08x", debug_pc);
      end

      if (debug_reg_we && debug_reg_waddr == 4'd0 && debug_reg_wdata == 32'h0000_0080) begin
        base_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd1 && debug_reg_wdata == 32'h0000_002A) begin
        word_value_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd3 && debug_reg_wdata == 32'h0000_0055) begin
        byte_value_seen++;
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

    if (base_seen != 1 || word_value_seen != 1 || byte_value_seen != 1) begin
      $fatal(1, "expected setup writes once, saw base=%0d word=%0d byte=%0d",
             base_seen, word_value_seen, byte_value_seen);
    end

    if (old_word_seen != 1 || old_byte_seen != 1) begin
      $fatal(1, "expected swap result writes once, saw word=%0d byte=%0d",
             old_word_seen, old_byte_seen);
    end

    if (word_store_seen != 1 || byte_store_seen != 1) begin
      $fatal(1, "expected one SWP and one SWPB store, saw word=%0d byte=%0d",
             word_store_seen, byte_store_seen);
    end

    if (swap_word !== 32'h0000_0055) begin
      $fatal(1, "expected final swapped memory 0x55, got %08x", swap_word);
    end

    if (loop_seen < 2) begin
      $fatal(1, "expected branch loop to retire at least twice, saw %0d", loop_seen);
    end

    $display("tb_arm7tdmi_core_swap passed");
    $finish;
  end
endmodule
