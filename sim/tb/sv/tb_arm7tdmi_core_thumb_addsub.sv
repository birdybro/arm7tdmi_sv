`timescale 1ns/1ps

module tb_arm7tdmi_core_thumb_addsub
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

  int add_reg_seen;
  int sub_imm_seen;
  int add_imm_seen;
  int sub_reg_seen;
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
      32'h0000_0000: bus_rdata = 32'hE3A0_0005; // MOV r0, #5
      32'h0000_0004: bus_rdata = 32'hE3A0_1007; // MOV r1, #7
      32'h0000_0008: bus_rdata = 32'hE3A0_6021; // MOV r6, #0x21
      32'h0000_000C: bus_rdata = 32'hE12F_FF16; // BX r6
      32'h0000_0020: bus_rdata = 32'h0000_1842; // Thumb ADD r2, r0, r1
      32'h0000_0022: bus_rdata = 32'h0000_1ED3; // Thumb SUB r3, r2, #3
      32'h0000_0024: bus_rdata = 32'h0000_1DDC; // Thumb ADD r4, r3, #7
      32'h0000_0026: bus_rdata = 32'h0000_1A65; // Thumb SUB r5, r4, r1
      32'h0000_0028: bus_rdata = 32'h0000_E7FE; // Thumb B .
      default:       bus_rdata = 32'hE1A0_0000;
    endcase
  end

  task automatic check_bus_contract;
    if (bus_write || bus_wdata !== 32'h0000_0000) begin
      $fatal(1, "thumb add/sub test should not write memory");
    end

    if (bus_valid && !(bus_size inside {BUS_SIZE_HALF, BUS_SIZE_WORD})) begin
      $fatal(1, "thumb add/sub saw invalid bus size");
    end

    if (bus_valid && !(bus_cycle inside {BUS_CYCLE_NONSEQ, BUS_CYCLE_SEQ})) begin
      $fatal(1, "thumb add/sub saw invalid cycle class");
    end

    if (unsupported) begin
      $fatal(1, "unexpected unsupported instruction at pc=%08x cpsr=%08x", debug_pc, debug_cpsr);
    end
  endtask

  initial begin
    rst_n = 1'b0;
    bus_ready = 1'b1;
    add_reg_seen = 0;
    sub_imm_seen = 0;
    add_imm_seen = 0;
    sub_reg_seen = 0;
    loop_seen = 0;

    repeat (2) @(posedge clk);
    rst_n = 1'b1;

    for (int cycle = 0; cycle < 90; cycle++) begin
      @(posedge clk);
      #1;
      check_bus_contract();

      if (debug_reg_we && debug_reg_waddr == 4'd2 && debug_reg_wdata == 32'd12) begin
        add_reg_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd3 && debug_reg_wdata == 32'd9) begin
        sub_imm_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd4 && debug_reg_wdata == 32'd16) begin
        add_imm_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd5 && debug_reg_wdata == 32'd9) begin
        sub_reg_seen++;
      end

      if (retired && debug_pc == 32'h0000_0028 && debug_cpsr[5]) begin
        loop_seen++;
      end
    end

    if (add_reg_seen != 1 || sub_imm_seen != 1 || add_imm_seen != 1 || sub_reg_seen != 1) begin
      $fatal(1, "expected one write per Thumb ADD/SUB op, saw add_reg=%0d sub_imm=%0d add_imm=%0d sub_reg=%0d",
             add_reg_seen, sub_imm_seen, add_imm_seen, sub_reg_seen);
    end

    if (loop_seen < 2) begin
      $fatal(1, "expected Thumb add/sub loop to retire, saw %0d", loop_seen);
    end

    $display("tb_arm7tdmi_core_thumb_addsub passed");
    $finish;
  end
endmodule
