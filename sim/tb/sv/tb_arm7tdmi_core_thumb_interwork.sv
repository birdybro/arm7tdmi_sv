`timescale 1ns/1ps

module tb_arm7tdmi_core_thumb_interwork
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

  int thumb_fetch_seen;
  int arm_bx_seen;
  int mov_seen;
  int add_seen;
  int cmp_seen;
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
      32'h0000_0000: bus_rdata = 32'hE3A0_0021; // MOV r0, #0x21
      32'h0000_0004: bus_rdata = 32'hE12F_FF10; // BX r0
      32'h0000_0020: bus_rdata = 32'h0000_212A; // Thumb MOV r1, #0x2a
      32'h0000_0022: bus_rdata = 32'h0000_3101; // Thumb ADD r1, #1
      32'h0000_0024: bus_rdata = 32'h0000_292B; // Thumb CMP r1, #0x2b
      32'h0000_0026: bus_rdata = 32'h0000_E7FE; // Thumb B .
      default:       bus_rdata = 32'hE1A0_0000;
    endcase
  end

  task automatic check_bus_contract;
    if (bus_write || bus_wdata !== 32'h0000_0000) begin
      $fatal(1, "thumb interwork test should not write memory");
    end

    if (bus_valid && !(bus_size inside {BUS_SIZE_HALF, BUS_SIZE_WORD})) begin
      $fatal(1, "thumb interwork saw invalid bus size");
    end

    if (bus_valid && !(bus_cycle inside {BUS_CYCLE_NONSEQ, BUS_CYCLE_SEQ})) begin
      $fatal(1, "thumb interwork saw invalid cycle class");
    end

      if (unsupported) begin
        $fatal(1, "unexpected unsupported instruction at pc=%08x cpsr=%08x", debug_pc, debug_cpsr);
      end

  endtask

  initial begin
    rst_n = 1'b0;
    bus_ready = 1'b1;
    thumb_fetch_seen = 0;
    arm_bx_seen = 0;
    mov_seen = 0;
    add_seen = 0;
    cmp_seen = 0;
    loop_seen = 0;

    repeat (2) @(posedge clk);
    rst_n = 1'b1;

    for (int cycle = 0; cycle < 60; cycle++) begin
      @(posedge clk);
      #1;
      check_bus_contract();

      if (bus_valid && !bus_write && bus_size == BUS_SIZE_HALF &&
          bus_addr inside {32'h0000_0020, 32'h0000_0022, 32'h0000_0024, 32'h0000_0026}) begin
        thumb_fetch_seen++;
      end

      if (retired && debug_pc == 32'h0000_0022 && debug_cpsr[5]) begin
        arm_bx_seen++;
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

    if (arm_bx_seen != 1) begin
      $fatal(1, "expected one ARM-to-Thumb BX retirement, saw %0d", arm_bx_seen);
    end

    if (thumb_fetch_seen < 4) begin
      $fatal(1, "expected Thumb halfword fetches, saw %0d", thumb_fetch_seen);
    end

    if (mov_seen != 1 || add_seen != 1 || cmp_seen < 1) begin
      $fatal(1, "expected MOV/ADD once and CMP flags to become visible, saw mov=%0d add=%0d cmp=%0d",
             mov_seen, add_seen, cmp_seen);
    end

    if (loop_seen < 2) begin
      $fatal(1, "expected Thumb branch loop to retire, saw %0d", loop_seen);
    end

    $display("tb_arm7tdmi_core_thumb_interwork passed");
    $finish;
  end
endmodule
