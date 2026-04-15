`timescale 1ns/1ps

module tb_arm7tdmi_core_mem
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
  logic [31:0] wb_word;
  int r0_seen;
  int r1_seen;
  int r2_seen;
  int r3_seen;
  int r4_seen;
  int r5_seen;
  int r6_setup_seen;
  int r6_wb_seen;
  int word_store_seen;
  int down_store_seen;
  int wb_store_seen;
  int byte_store_seen;
  int word_load_seen;
  int down_load_seen;
  int byte_load_seen;
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
      32'h0000_0000: bus_rdata = 32'hE3A0_0040; // MOV r0, #0x40
      32'h0000_0004: bus_rdata = 32'hE3A0_102A; // MOV r1, #0x2a
      32'h0000_0008: bus_rdata = 32'hE580_1004; // STR r1, [r0, #4]
      32'h0000_000C: bus_rdata = 32'hE590_2004; // LDR r2, [r0, #4]
      32'h0000_0010: bus_rdata = 32'hE3A0_30FF; // MOV r3, #0xff
      32'h0000_0014: bus_rdata = 32'hE5C0_3005; // STRB r3, [r0, #5]
      32'h0000_0018: bus_rdata = 32'hE5D0_4005; // LDRB r4, [r0, #5]
      32'h0000_001C: bus_rdata = 32'hE500_1004; // STR r1, [r0, #-4]
      32'h0000_0020: bus_rdata = 32'hE510_5004; // LDR r5, [r0, #-4]
      32'h0000_0024: bus_rdata = 32'hE3A0_6050; // MOV r6, #0x50
      32'h0000_0028: bus_rdata = 32'hE5A6_1004; // STR r1, [r6, #4]!
      32'h0000_002C: bus_rdata = 32'hEAFF_FFFE; // B .
      32'h0000_003C: bus_rdata = data_word;
      32'h0000_0044: bus_rdata = data_word;
      32'h0000_0045: bus_rdata = {24'h0, data_word[15:8]};
      32'h0000_0054: bus_rdata = wb_word;
      default:       bus_rdata = 32'hE1A0_0000; // MOV r0, r0
    endcase
  end

  always_ff @(posedge clk) begin
    if (bus_valid && bus_write) begin
      if (bus_addr == 32'h0000_0044) begin
        if (bus_size !== BUS_SIZE_WORD || bus_cycle !== BUS_CYCLE_NONSEQ) begin
          $fatal(1, "word store expected word nonseq transfer");
        end

        if (bus_wdata !== 32'h0000_002A) begin
          $fatal(1, "word store expected wdata 0x2a, got %08x", bus_wdata);
        end

        data_word <= bus_wdata;
        word_store_seen <= word_store_seen + 1;
      end else if (bus_addr == 32'h0000_003C) begin
        if (bus_size !== BUS_SIZE_WORD || bus_cycle !== BUS_CYCLE_NONSEQ) begin
          $fatal(1, "down-offset store expected word nonseq transfer");
        end

        if (bus_wdata !== 32'h0000_002A) begin
          $fatal(1, "down-offset store expected wdata 0x2a, got %08x", bus_wdata);
        end

        data_word <= bus_wdata;
        down_store_seen <= down_store_seen + 1;
      end else if (bus_addr == 32'h0000_0054) begin
        if (bus_size !== BUS_SIZE_WORD || bus_cycle !== BUS_CYCLE_NONSEQ) begin
          $fatal(1, "writeback store expected word nonseq transfer");
        end

        if (bus_wdata !== 32'h0000_002A) begin
          $fatal(1, "writeback store expected wdata 0x2a, got %08x", bus_wdata);
        end

        wb_word <= bus_wdata;
        wb_store_seen <= wb_store_seen + 1;
      end else if (bus_addr == 32'h0000_0045) begin
        if (bus_size !== BUS_SIZE_BYTE || bus_cycle !== BUS_CYCLE_NONSEQ) begin
          $fatal(1, "byte store expected byte nonseq transfer");
        end

        if (bus_wdata !== 32'h0000_00FF) begin
          $fatal(1, "byte store expected wdata 0xff, got %08x", bus_wdata);
        end

        data_word <= {data_word[31:16], bus_wdata[7:0], data_word[7:0]};
        byte_store_seen <= byte_store_seen + 1;
      end else begin
        $fatal(1, "unexpected store address %08x", bus_addr);
      end
    end
  end

  initial begin
    rst_n = 1'b0;
    bus_ready = 1'b1;
    data_word = 32'hDEAD_BEEF;
    wb_word = 32'hCAFE_F00D;
    r0_seen = 0;
    r1_seen = 0;
    r2_seen = 0;
    r3_seen = 0;
    r4_seen = 0;
    r5_seen = 0;
    r6_setup_seen = 0;
    r6_wb_seen = 0;
    word_store_seen = 0;
    down_store_seen = 0;
    wb_store_seen = 0;
    byte_store_seen = 0;
    word_load_seen = 0;
    down_load_seen = 0;
    byte_load_seen = 0;
    loop_seen = 0;

    repeat (2) @(posedge clk);
    rst_n = 1'b1;

    for (int cycle = 0; cycle < 100; cycle++) begin
      @(posedge clk);
      #1;

      if (bus_valid && !(bus_size inside {BUS_SIZE_BYTE, BUS_SIZE_WORD})) begin
        $fatal(1, "memory smoke expected byte or word transfer");
      end

      if (unsupported) begin
        $fatal(1, "unexpected unsupported instruction at pc=%08x", debug_pc);
      end

      if (debug_reg_we && debug_reg_waddr == 4'd0 && debug_reg_wdata == 32'h0000_0040) begin
        r0_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd1 && debug_reg_wdata == 32'h0000_002A) begin
        r1_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd2 && debug_reg_wdata == 32'h0000_002A) begin
        r2_seen++;
        word_load_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd3 && debug_reg_wdata == 32'h0000_00FF) begin
        r3_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd4 && debug_reg_wdata == 32'h0000_00FF) begin
        r4_seen++;
        byte_load_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd5 && debug_reg_wdata == 32'h0000_002A) begin
        r5_seen++;
        down_load_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd6 && debug_reg_wdata == 32'h0000_0050) begin
        r6_setup_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd6 && debug_reg_wdata == 32'h0000_0054) begin
        r6_wb_seen++;
      end

      if (retired && debug_pc == 32'h0000_002C) begin
        loop_seen++;
      end
    end

    if (r0_seen != 1 || r1_seen != 1) begin
      $fatal(1, "expected one setup write each, saw r0=%0d r1=%0d", r0_seen, r1_seen);
    end

    if (r3_seen != 1) begin
      $fatal(1, "expected one byte setup write, saw %0d", r3_seen);
    end

    if (r6_setup_seen != 1 || r6_wb_seen != 1) begin
      $fatal(1, "expected r6 setup and writeback, saw setup=%0d wb=%0d",
             r6_setup_seen, r6_wb_seen);
    end

    if (word_store_seen != 1 || down_store_seen != 1 || wb_store_seen != 1 || byte_store_seen != 1) begin
      $fatal(1, "expected one word, down-offset, writeback, and byte store, saw word=%0d down=%0d wb=%0d byte=%0d",
             word_store_seen, down_store_seen, wb_store_seen, byte_store_seen);
    end

    if (word_load_seen != 1 || r2_seen != 1 || down_load_seen != 1 || r5_seen != 1 ||
        byte_load_seen != 1 || r4_seen != 1) begin
      $fatal(1, "expected word, down-offset, and byte loads, saw word=%0d r2=%0d down=%0d r5=%0d byte=%0d r4=%0d",
             word_load_seen, r2_seen, down_load_seen, r5_seen, byte_load_seen, r4_seen);
    end

    if (loop_seen < 2) begin
      $fatal(1, "expected branch loop to retire at least twice, saw %0d", loop_seen);
    end

    $display("tb_arm7tdmi_core_mem passed");
    $finish;
  end
endmodule
