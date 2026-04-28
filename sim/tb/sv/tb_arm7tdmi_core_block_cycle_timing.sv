`timescale 1ns/1ps

module tb_arm7tdmi_core_block_cycle_timing
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

  logic [31:0] mem0;
  logic [31:0] mem1;
  logic [31:0] mem2;
  int sim_cycle;
  int fetch_04;
  int fetch_08;
  int fetch_0c;
  int fetch_10;
  int fetch_14;
  int fetch_18;
  int fetch_1c;
  arm_bus_cycle_t cycle_04;
  arm_bus_cycle_t cycle_08;
  arm_bus_cycle_t cycle_0c;
  arm_bus_cycle_t cycle_10;
  arm_bus_cycle_t cycle_14;
  arm_bus_cycle_t cycle_18;
  arm_bus_cycle_t cycle_1c;
  int int_cycles_seen;
  int stm_seen;
  int ldm_seen;
  int r0_setup_seen;
  int r0_wb_seen;
  int r7_setup_seen;
  int r7_wb_seen;
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
      32'h0000_0000: bus_rdata = 32'hE3A0_0080; // MOV r0, #0x80
      32'h0000_0004: bus_rdata = 32'hE3A0_1011; // MOV r1, #0x11
      32'h0000_0008: bus_rdata = 32'hE3A0_2022; // MOV r2, #0x22
      32'h0000_000C: bus_rdata = 32'hE3A0_3033; // MOV r3, #0x33
      32'h0000_0010: bus_rdata = 32'hE8A0_000E; // STMIA r0!, {r1-r3}
      32'h0000_0014: bus_rdata = 32'hE3A0_7080; // MOV r7, #0x80
      32'h0000_0018: bus_rdata = 32'hE8B7_0070; // LDMIA r7!, {r4-r6}
      32'h0000_001C: bus_rdata = 32'hEAFF_FFFE; // B .
      32'h0000_0080: bus_rdata = mem0;
      32'h0000_0084: bus_rdata = mem1;
      32'h0000_0088: bus_rdata = mem2;
      default:       bus_rdata = 32'hE1A0_0000;
    endcase
  end

  always_ff @(posedge clk) begin
    if (bus_valid && bus_write) begin
      if (bus_size != BUS_SIZE_WORD) begin
        $fatal(1, "block timing expected word transfers");
      end

      unique case (bus_addr)
        32'h0000_0080: begin
          mem0 <= bus_wdata;
          stm_seen <= stm_seen + 1;
        end
        32'h0000_0084: begin
          mem1 <= bus_wdata;
          stm_seen <= stm_seen + 1;
        end
        32'h0000_0088: begin
          mem2 <= bus_wdata;
          stm_seen <= stm_seen + 1;
        end
        default: begin
          $fatal(1, "unexpected block timing store address %08x", bus_addr);
        end
      endcase
    end else if (bus_valid && !bus_write && (bus_addr inside {32'h0000_0080, 32'h0000_0084, 32'h0000_0088})) begin
      ldm_seen <= ldm_seen + 1;
    end
  end

  initial begin
    rst_n = 1'b0;
    bus_ready = 1'b1;
    mem0 = 32'hCAFE_0000;
    mem1 = 32'hCAFE_0001;
    mem2 = 32'hCAFE_0002;
    sim_cycle = 0;
    fetch_04 = -1;
    fetch_08 = -1;
    fetch_0c = -1;
    fetch_10 = -1;
    fetch_14 = -1;
    fetch_18 = -1;
    fetch_1c = -1;
    cycle_04 = BUS_CYCLE_INT;
    cycle_08 = BUS_CYCLE_INT;
    cycle_0c = BUS_CYCLE_INT;
    cycle_10 = BUS_CYCLE_INT;
    cycle_14 = BUS_CYCLE_INT;
    cycle_18 = BUS_CYCLE_INT;
    cycle_1c = BUS_CYCLE_INT;
    int_cycles_seen = 0;
    stm_seen = 0;
    ldm_seen = 0;
    r0_setup_seen = 0;
    r0_wb_seen = 0;
    r7_setup_seen = 0;
    r7_wb_seen = 0;
    r4_seen = 0;
    r5_seen = 0;
    r6_seen = 0;
    loop_seen = 0;

    repeat (2) @(posedge clk);
    rst_n = 1'b1;

    for (int cycle = 0; cycle < 120; cycle++) begin
      @(posedge clk);
      #1;
      sim_cycle++;

      if (unsupported) begin
        $fatal(1, "unexpected unsupported instruction at pc=%08x", debug_pc);
      end

      if (bus_valid) begin
        if (bus_size != BUS_SIZE_WORD) begin
          $fatal(1, "block timing expected word bus size");
        end

        if (!(bus_cycle inside {BUS_CYCLE_NONSEQ, BUS_CYCLE_SEQ})) begin
          $fatal(1, "block timing bus_valid expected seq/nonseq, got %0d", bus_cycle);
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
          32'h0000_001C: if (fetch_1c < 0) begin
            fetch_1c = sim_cycle;
            cycle_1c = bus_cycle;
          end
          default: begin
          end
        endcase
      end else if (bus_cycle == BUS_CYCLE_INT) begin
        int_cycles_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd0 && debug_reg_wdata == 32'h0000_0080) begin
        r0_setup_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd0 &&
          (debug_reg_wdata inside {32'h0000_008C, 32'h0000_0098})) begin
        r0_wb_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd7 && debug_reg_wdata == 32'h0000_0080) begin
        r7_setup_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd7 && debug_reg_wdata == 32'h0000_008C) begin
        r7_wb_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd4 && debug_reg_wdata == 32'h0000_0011) begin
        r4_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd5 && debug_reg_wdata == 32'h0000_0022) begin
        r5_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd6 && debug_reg_wdata == 32'h0000_0033) begin
        r6_seen++;
      end

      if (retired && debug_pc == 32'h0000_001C) begin
        loop_seen++;
      end
    end

    if ((fetch_04 < 0) || (fetch_08 < 0) || (fetch_0c < 0) || (fetch_10 < 0) ||
        (fetch_14 < 0) || (fetch_18 < 0) || (fetch_1c < 0)) begin
      $fatal(1, "missing block timing fetch timestamps");
    end

    if ((cycle_04 != BUS_CYCLE_SEQ) || (cycle_08 != BUS_CYCLE_SEQ) ||
        (cycle_0c != BUS_CYCLE_SEQ) || (cycle_10 != BUS_CYCLE_SEQ) ||
        (cycle_14 != BUS_CYCLE_NONSEQ) || (cycle_18 != BUS_CYCLE_SEQ) ||
        (cycle_1c != BUS_CYCLE_NONSEQ)) begin
      $fatal(1, "unexpected block timing fetch cycle classes 04=%0d 08=%0d 0c=%0d 10=%0d 14=%0d 18=%0d 1c=%0d",
             cycle_04, cycle_08, cycle_0c, cycle_10, cycle_14, cycle_18, cycle_1c);
    end

    if ((fetch_14 - fetch_10) != 6) begin
      $fatal(1, "STMIA with 3 beats and writeback should take 6 cycles to next fetch, saw %0d",
             fetch_14 - fetch_10);
    end

    if ((fetch_1c - fetch_18) != 6) begin
      $fatal(1, "LDMIA with 3 beats and writeback should take 6 cycles to next fetch, saw %0d",
             fetch_1c - fetch_18);
    end

    if (int_cycles_seen < 2) begin
      $fatal(1, "expected visible block writeback internal cycles, saw %0d", int_cycles_seen);
    end

    if (stm_seen != 3 || ldm_seen != 3 || r0_setup_seen != 1 || r0_wb_seen != 1 ||
        r7_setup_seen != 1 || r7_wb_seen != 1 || r4_seen != 1 || r5_seen != 1 || r6_seen != 1) begin
      $fatal(1, "unexpected block timing observations stm=%0d ldm=%0d r0_setup=%0d r0_wb=%0d r7_setup=%0d r7_wb=%0d r4=%0d r5=%0d r6=%0d",
             stm_seen, ldm_seen, r0_setup_seen, r0_wb_seen, r7_setup_seen, r7_wb_seen,
             r4_seen, r5_seen, r6_seen);
    end

    if (loop_seen < 2) begin
      $fatal(1, "expected block timing loop to retire at least twice, saw %0d", loop_seen);
    end

    $display("tb_arm7tdmi_core_block_cycle_timing passed");
    $finish;
  end
endmodule
