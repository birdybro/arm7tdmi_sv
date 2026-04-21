`timescale 1ns/1ps

module tb_arm7tdmi_core_thumb_interwork_cycle_timing
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
  int fetch_04;
  int fetch_20;
  int fetch_22;
  int fetch_24;
  int thumb_fetch_seen;
  int bx_seen;
  int mov_seen;
  int add_seen;
  int cmp_seen;
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
      32'h0000_0000: bus_rdata = 32'hE3A0_0021; // MOV r0, #0x21
      32'h0000_0004: bus_rdata = 32'hE12F_FF10; // BX r0
      32'h0000_0020: bus_rdata = 32'h0000_212A; // Thumb MOV r1, #0x2a
      32'h0000_0022: bus_rdata = 32'h0000_3101; // Thumb ADD r1, #1
      32'h0000_0024: bus_rdata = 32'h0000_292B; // Thumb CMP r1, #0x2b
      32'h0000_0026: bus_rdata = 32'h0000_E7FE; // Thumb B .
      default:       bus_rdata = 32'hE1A0_0000;
    endcase
  end

  initial begin
    rst_n = 1'b0;
    bus_ready = 1'b1;
    sim_cycle = 0;
    fetch_04 = -1;
    fetch_20 = -1;
    fetch_22 = -1;
    fetch_24 = -1;
    thumb_fetch_seen = 0;
    bx_seen = 0;
    mov_seen = 0;
    add_seen = 0;
    cmp_seen = 0;
    loop_seen = 0;

    repeat (2) @(posedge clk);
    rst_n = 1'b1;

    for (int cycle = 0; cycle < 80; cycle++) begin
      @(posedge clk);
      #1;
      sim_cycle++;

      if (unsupported) begin
        $fatal(1, "unexpected unsupported instruction at pc=%08x cpsr=%08x", debug_pc, debug_cpsr);
      end

      if (bus_write || bus_wdata !== 32'h0000_0000) begin
        $fatal(1, "interwork timing test should not write memory");
      end

      if (bus_valid) begin
        if (!(bus_size inside {BUS_SIZE_HALF, BUS_SIZE_WORD})) begin
          $fatal(1, "interwork timing saw invalid bus size");
        end

        if (!(bus_cycle inside {BUS_CYCLE_NONSEQ, BUS_CYCLE_SEQ})) begin
          $fatal(1, "interwork timing saw invalid cycle class");
        end

        if (bus_addr == 32'h0000_0004 && fetch_04 < 0) fetch_04 = sim_cycle;
        if (bus_addr == 32'h0000_0020 && fetch_20 < 0) fetch_20 = sim_cycle;
        if (bus_addr == 32'h0000_0022 && fetch_22 < 0) fetch_22 = sim_cycle;
        if (bus_addr == 32'h0000_0024 && fetch_24 < 0) fetch_24 = sim_cycle;

        if (!bus_write && bus_size == BUS_SIZE_HALF &&
            (bus_addr inside {32'h0000_0020, 32'h0000_0022, 32'h0000_0024, 32'h0000_0026})) begin
          thumb_fetch_seen++;
        end
      end

      if (retired && debug_pc == 32'h0000_0022 && debug_cpsr[5]) begin
        bx_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd1 && debug_reg_wdata == 32'h0000_002A) begin
        mov_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd1 && debug_reg_wdata == 32'h0000_002B) begin
        add_seen++;
      end

      if (retired && debug_pc == 32'h0000_0026 && debug_cpsr[30]) begin
        cmp_seen++;
      end

      if (retired && debug_pc == 32'h0000_0026 && debug_cpsr[5]) begin
        loop_seen++;
      end
    end

    if ((fetch_04 < 0) || (fetch_20 < 0) || (fetch_22 < 0) || (fetch_24 < 0)) begin
      $fatal(1, "missing interwork timing fetch timestamps");
    end

    if ((fetch_20 - fetch_04) != 2) begin
      $fatal(1, "BX should redirect to first Thumb fetch on the next fetch slot, saw %0d",
             fetch_20 - fetch_04);
    end

    if ((fetch_22 - fetch_20) != 2 || (fetch_24 - fetch_22) != 2) begin
      $fatal(1, "Thumb fetch stream should advance every 2 cycles, saw %0d and %0d",
             fetch_22 - fetch_20, fetch_24 - fetch_22);
    end

    if (bx_seen != 1 || thumb_fetch_seen < 4 || mov_seen != 1 || add_seen != 1 || cmp_seen < 1) begin
      $fatal(1, "unexpected interwork timing observations bx=%0d thumb_fetch=%0d mov=%0d add=%0d cmp=%0d",
             bx_seen, thumb_fetch_seen, mov_seen, add_seen, cmp_seen);
    end

    if (loop_seen < 2) begin
      $fatal(1, "expected interwork timing loop to retire, saw %0d", loop_seen);
    end

    $display("tb_arm7tdmi_core_thumb_interwork_cycle_timing passed");
    $finish;
  end
endmodule
