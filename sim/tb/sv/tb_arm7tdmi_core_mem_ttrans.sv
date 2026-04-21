`timescale 1ns/1ps

module tb_arm7tdmi_core_mem_ttrans
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

  logic [31:0] data_word0;
  logic [31:0] data_word1;
  logic [31:0] data_word2;
  int base_setup_seen;
  int value_seen;
  int byte_value_seen;
  int strt_store_seen;
  int ldrt_load_seen;
  int base_wb_seen;
  int byte_store_seen;
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
      32'h0000_0008: bus_rdata = 32'hE4A0_1004; // STRT r1, [r0], #4
      32'h0000_000C: bus_rdata = 32'hE4B0_2004; // LDRT r2, [r0], #4
      32'h0000_0010: bus_rdata = 32'hE3A0_0048; // MOV r0, #0x48
      32'h0000_0014: bus_rdata = 32'hE3A0_108C; // MOV r1, #0x8c
      32'h0000_0018: bus_rdata = 32'hE4E0_1001; // STRBT r1, [r0], #1
      32'h0000_001C: bus_rdata = 32'hE3A0_0048; // MOV r0, #0x48
      32'h0000_0020: bus_rdata = 32'hE4F0_3001; // LDRBT r3, [r0], #1
      32'h0000_0024: bus_rdata = 32'hEAFF_FFFE; // B .
      32'h0000_0040: bus_rdata = data_word0;
      32'h0000_0044: bus_rdata = data_word1;
      32'h0000_0048: bus_rdata = data_word2;
      default:       bus_rdata = 32'hE1A0_0000; // MOV r0, r0
    endcase
  end

  always_ff @(posedge clk) begin
    if (bus_valid && bus_write) begin
      if (bus_cycle !== BUS_CYCLE_NONSEQ) begin
        $fatal(1, "unexpected T-transfer store cycle=%0d", bus_cycle);
      end

      if (bus_addr == 32'h0000_0040) begin
        if (bus_size !== BUS_SIZE_WORD || bus_wdata !== 32'h0000_002A) begin
          $fatal(1, "unexpected STRT transfer addr=%08x size=%0d data=%08x",
                 bus_addr, bus_size, bus_wdata);
        end

        data_word0 <= bus_wdata;
        strt_store_seen <= strt_store_seen + 1;
      end else if (bus_addr == 32'h0000_0048) begin
        if (bus_size !== BUS_SIZE_BYTE || bus_wdata[7:0] !== 8'h8C) begin
          $fatal(1, "unexpected STRBT transfer addr=%08x size=%0d data=%08x",
                 bus_addr, bus_size, bus_wdata);
        end

        data_word2 <= {data_word2[31:8], bus_wdata[7:0]};
        byte_store_seen <= byte_store_seen + 1;
      end else begin
        $fatal(1, "unexpected T-transfer store address %08x", bus_addr);
      end
    end
  end

  initial begin
    rst_n = 1'b0;
    bus_ready = 1'b1;
    data_word0 = 32'hCAFE_F00D;
    data_word1 = 32'h1234_5678;
    data_word2 = 32'hA1B2_C3D4;
    base_setup_seen = 0;
    value_seen = 0;
    byte_value_seen = 0;
    strt_store_seen = 0;
    ldrt_load_seen = 0;
    base_wb_seen = 0;
    byte_store_seen = 0;
    byte_load_seen = 0;
    loop_seen = 0;

    repeat (2) @(posedge clk);
    rst_n = 1'b1;

    for (int cycle = 0; cycle < 90; cycle++) begin
      @(posedge clk);
      #1;

      if (bus_valid && !(bus_size inside {BUS_SIZE_WORD, BUS_SIZE_BYTE})) begin
        $fatal(1, "T-transfer smoke expected word/byte transfers");
      end

      if (bus_valid && !(bus_cycle inside {BUS_CYCLE_NONSEQ, BUS_CYCLE_SEQ})) begin
        $fatal(1, "T-transfer smoke saw invalid cycle class");
      end

      if (unsupported) begin
        $fatal(1, "unexpected unsupported instruction at pc=%08x", debug_pc);
      end

      if (debug_reg_we && debug_reg_waddr == 4'd0 && debug_reg_wdata == 32'h0000_0040) begin
        base_setup_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd0 && debug_reg_wdata == 32'h0000_0048) begin
        base_setup_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd1 && debug_reg_wdata == 32'h0000_002A) begin
        value_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd1 && debug_reg_wdata == 32'h0000_008C) begin
        byte_value_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd0 && debug_reg_wdata == 32'h0000_0044) begin
        base_wb_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd2 && debug_reg_wdata == 32'h1234_5678) begin
        ldrt_load_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd0 && debug_reg_wdata == 32'h0000_0049) begin
        base_wb_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd3 && debug_reg_wdata == 32'h0000_008C) begin
        byte_load_seen++;
      end

      if (retired && debug_pc == 32'h0000_0024) begin
        loop_seen++;
      end
    end

    if (base_setup_seen != 4 || value_seen != 1 || byte_value_seen != 1) begin
      $fatal(1, "expected observed base/value writes base=4 word=1 byte=1, saw base=%0d word=%0d byte=%0d",
             base_setup_seen, value_seen, byte_value_seen);
    end

    if (strt_store_seen != 1) begin
      $fatal(1, "expected one STRT store, saw %0d", strt_store_seen);
    end

    if (ldrt_load_seen != 1) begin
      $fatal(1, "expected one LDRT load, saw %0d", ldrt_load_seen);
    end

    if (byte_store_seen != 1 || byte_load_seen != 1) begin
      $fatal(1, "expected one STRBT/LDRBT pair, saw stores=%0d loads=%0d",
             byte_store_seen, byte_load_seen);
    end

    if (base_wb_seen != 3) begin
      $fatal(1, "expected three unambiguous post-index base writebacks, saw %0d", base_wb_seen);
    end

    if (data_word0 !== 32'h0000_002A || data_word1 !== 32'h1234_5678 ||
        data_word2 !== 32'hA1B2_C38C) begin
      $fatal(1, "unexpected final memory word0=%08x word1=%08x word2=%08x",
             data_word0, data_word1, data_word2);
    end

    if (loop_seen < 2) begin
      $fatal(1, "expected T-transfer loop to retire, saw %0d", loop_seen);
    end

    $display("tb_arm7tdmi_core_mem_ttrans passed");
    $finish;
  end
endmodule
