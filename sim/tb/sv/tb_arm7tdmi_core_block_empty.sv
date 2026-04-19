`timescale 1ns/1ps

module tb_arm7tdmi_core_block_empty
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

  int base_store_seen;
  int base_load_seen;
  int empty_store_seen;
  int empty_load_seen;
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
      32'h0000_0004: bus_rdata = 32'hE880_0000; // STMIA r0, {}
      32'h0000_0008: bus_rdata = 32'hE3A0_1040; // MOV r1, #0x40
      32'h0000_000C: bus_rdata = 32'hE891_0000; // LDMIA r1, {}
      32'h0000_0020: bus_rdata = 32'hEAFF_FFFE; // B .
      32'h0000_0040: bus_rdata = 32'h0000_0020;
      default:       bus_rdata = 32'hE1A0_0000; // MOV r0, r0
    endcase
  end

  always_ff @(posedge clk) begin
    if (bus_valid && bus_write) begin
      if (bus_addr !== 32'h0000_0080) begin
        $fatal(1, "empty STM expected address 0x80, got %08x", bus_addr);
      end

      if (bus_size !== BUS_SIZE_WORD || bus_cycle !== BUS_CYCLE_NONSEQ) begin
        $fatal(1, "empty STM expected word nonseq transfer");
      end

      if (bus_wdata !== 32'h0000_0010) begin
        $fatal(1, "empty STM should store PC+12=0x10, got %08x", bus_wdata);
      end

      empty_store_seen <= empty_store_seen + 1;
    end
  end

  initial begin
    rst_n = 1'b0;
    bus_ready = 1'b1;
    base_store_seen = 0;
    base_load_seen = 0;
    empty_store_seen = 0;
    empty_load_seen = 0;
    loop_seen = 0;

    repeat (2) @(posedge clk);
    rst_n = 1'b1;

    for (int cycle = 0; cycle < 70; cycle++) begin
      @(posedge clk);
      #1;

      if (unsupported) begin
        $fatal(1, "unexpected unsupported empty block instruction at pc=%08x", debug_pc);
      end

      if (bus_valid && bus_addr == 32'h0000_0040 && !bus_write &&
          bus_size == BUS_SIZE_WORD && bus_cycle == BUS_CYCLE_NONSEQ) begin
        empty_load_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd0 && debug_reg_wdata == 32'h0000_0080) begin
        base_store_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd1 && debug_reg_wdata == 32'h0000_0040) begin
        base_load_seen++;
      end

      if (retired && debug_pc == 32'h0000_0020) begin
        loop_seen++;
      end
    end

    if (base_store_seen != 1 || base_load_seen != 1) begin
      $fatal(1, "expected setup base writes once, saw r0=%0d r1=%0d",
             base_store_seen, base_load_seen);
    end

    if (empty_store_seen != 1 || empty_load_seen != 1) begin
      $fatal(1, "expected one empty STM and one empty LDM transfer, saw store=%0d load=%0d",
             empty_store_seen, empty_load_seen);
    end

    if (loop_seen < 2) begin
      $fatal(1, "expected empty LDM PC target loop to retire at least twice, saw %0d", loop_seen);
    end

    $display("tb_arm7tdmi_core_block_empty passed");
    $finish;
  end
endmodule
