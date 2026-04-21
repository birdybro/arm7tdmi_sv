`timescale 1ns/1ps

module tb_arm7tdmi_core_thumb_cycle_timing
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
  int fetch_22;
  int fetch_24;
  int fetch_26;
  int fetch_28;
  int fetch_2a;
  int fetch_2c;
  int int_cycles_seen;
  int r0_mov_seen;
  int r0_mul_seen;
  int r1_seen;
  int r2_seen;
  int r3_seen;
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
      32'h0000_0000: bus_rdata = 32'hE3A0_6021; // MOV r6, #0x21
      32'h0000_0004: bus_rdata = 32'hE12F_FF16; // BX r6
      32'h0000_0020: bus_rdata = 32'h0000_2001; // Thumb MOV r0, #1
      32'h0000_0022: bus_rdata = 32'h0000_2102; // Thumb MOV r1, #2
      32'h0000_0024: bus_rdata = 32'h0000_2201; // Thumb MOV r2, #1
      32'h0000_0026: bus_rdata = 32'h0000_4091; // Thumb LSL r1, r2
      32'h0000_0028: bus_rdata = 32'h0000_2302; // Thumb MOV r3, #2
      32'h0000_002A: bus_rdata = 32'h0000_4358; // Thumb MUL r0, r3
      32'h0000_002C: bus_rdata = 32'h0000_E7FE; // Thumb B .
      default:       bus_rdata = 32'hE1A0_0000;
    endcase
  end

  initial begin
    rst_n = 1'b0;
    bus_ready = 1'b1;
    sim_cycle = 0;
    fetch_22 = -1;
    fetch_24 = -1;
    fetch_26 = -1;
    fetch_28 = -1;
    fetch_2a = -1;
    fetch_2c = -1;
    int_cycles_seen = 0;
    r0_mov_seen = 0;
    r0_mul_seen = 0;
    r1_seen = 0;
    r2_seen = 0;
    r3_seen = 0;
    loop_seen = 0;

    repeat (2) @(posedge clk);
    rst_n = 1'b1;

    for (int cycle = 0; cycle < 90; cycle++) begin
      @(posedge clk);
      #1;
      sim_cycle++;

      if (unsupported) begin
        $fatal(1, "unexpected unsupported instruction at pc=%08x cpsr=%08x", debug_pc, debug_cpsr);
      end

      if (bus_write || bus_wdata !== 32'h0000_0000) begin
        $fatal(1, "thumb timing test should not write memory");
      end

      if (bus_valid) begin
        if (!(bus_size inside {BUS_SIZE_HALF, BUS_SIZE_WORD})) begin
          $fatal(1, "thumb timing test saw invalid size");
        end

        if (!(bus_cycle inside {BUS_CYCLE_NONSEQ, BUS_CYCLE_SEQ})) begin
          $fatal(1, "thumb timing test bus_valid expected seq/nonseq, got %0d", bus_cycle);
        end

        unique case (bus_addr)
          32'h0000_0022: if (fetch_22 < 0) fetch_22 = sim_cycle;
          32'h0000_0024: if (fetch_24 < 0) fetch_24 = sim_cycle;
          32'h0000_0026: if (fetch_26 < 0) fetch_26 = sim_cycle;
          32'h0000_0028: if (fetch_28 < 0) fetch_28 = sim_cycle;
          32'h0000_002A: if (fetch_2a < 0) fetch_2a = sim_cycle;
          32'h0000_002C: if (fetch_2c < 0) fetch_2c = sim_cycle;
          default: begin
          end
        endcase
      end else if (bus_cycle == BUS_CYCLE_INT) begin
        int_cycles_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd0 && debug_reg_wdata == 32'h0000_0001) begin
        r0_mov_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd0 && debug_reg_wdata == 32'h0000_0002) begin
        r0_mul_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd1 && debug_reg_wdata == 32'h0000_0004) begin
        r1_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd2 && debug_reg_wdata == 32'h0000_0001) begin
        r2_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd3 && debug_reg_wdata == 32'h0000_0002) begin
        r3_seen++;
      end

      if (retired && debug_pc == 32'h0000_002C && debug_cpsr[5]) begin
        loop_seen++;
      end
    end

    if ((fetch_22 < 0) || (fetch_24 < 0) || (fetch_26 < 0) ||
        (fetch_28 < 0) || (fetch_2a < 0) || (fetch_2c < 0)) begin
      $fatal(1, "missing thumb timing fetch timestamps");
    end

    if ((fetch_24 - fetch_22) != 2) begin
      $fatal(1, "plain Thumb MOV should fetch every 2 cycles, saw %0d", fetch_24 - fetch_22);
    end

    if ((fetch_28 - fetch_26) != 3) begin
      $fatal(1, "Thumb register-shift ALU op should add one internal cycle, saw %0d",
             fetch_28 - fetch_26);
    end

    if ((fetch_2c - fetch_2a) != 3) begin
      $fatal(1, "Thumb MUL should add one internal cycle for small multiplier, saw %0d",
             fetch_2c - fetch_2a);
    end

    if (int_cycles_seen < 2) begin
      $fatal(1, "expected visible Thumb internal cycles, saw %0d", int_cycles_seen);
    end

    if (r0_mov_seen != 1 || r0_mul_seen != 1 || r1_seen != 1 || r2_seen != 1 || r3_seen != 1) begin
      $fatal(1, "unexpected Thumb timing writes r0_mov=%0d r0_mul=%0d r1=%0d r2=%0d r3=%0d",
             r0_mov_seen, r0_mul_seen, r1_seen, r2_seen, r3_seen);
    end

    if (loop_seen < 2) begin
      $fatal(1, "expected Thumb timing loop to retire at least twice, saw %0d", loop_seen);
    end

    $display("tb_arm7tdmi_core_thumb_cycle_timing passed");
    $finish;
  end
endmodule
