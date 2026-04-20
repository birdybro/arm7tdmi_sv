`timescale 1ns/1ps

module tb_arm7tdmi_core_data_abort
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
  logic bus_abort;
  logic [31:0] debug_pc;
  logic [31:0] debug_cpsr;
  logic debug_reg_we;
  logic [3:0] debug_reg_waddr;
  logic [31:0] debug_reg_wdata;
  logic retired;
  logic unsupported;

  int base_setup_seen;
  int base_wb_seen;
  int aborted_load_seen;
  int lr_seen;
  int cpsr_seen;
  int spsr_seen;
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
    .bus_abort_i(bus_abort),
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
      32'h0000_0000: bus_rdata = 32'hE321_F013; // MSR CPSR_c, #0x13
      32'h0000_0004: bus_rdata = 32'hE1A0_0000; // MOV r0, r0
      32'h0000_0008: bus_rdata = 32'hE3A0_0040; // MOV r0, #0x40
      32'h0000_000C: bus_rdata = 32'hE5B0_2004; // LDR r2, [r0, #4]!
      32'h0000_0010: bus_rdata = 32'hE10F_0000; // MRS r0, CPSR
      32'h0000_0014: bus_rdata = 32'hE14F_1000; // MRS r1, SPSR
      32'h0000_0018: bus_rdata = 32'hEAFF_FFFE; // B .
      32'h0000_0044: bus_rdata = 32'hCAFE_F00D;
      default:       bus_rdata = 32'hE1A0_0000; // MOV r0, r0
    endcase
  end

  assign bus_abort = bus_valid && !bus_write && (bus_addr == 32'h0000_0044);

  initial begin
    rst_n = 1'b0;
    bus_ready = 1'b1;
    base_setup_seen = 0;
    base_wb_seen = 0;
    aborted_load_seen = 0;
    lr_seen = 0;
    cpsr_seen = 0;
    spsr_seen = 0;
    loop_seen = 0;

    repeat (2) @(posedge clk);
    rst_n = 1'b1;

    for (int cycle = 0; cycle < 70; cycle++) begin
      @(posedge clk);
      #1;

      if (bus_write || bus_wdata !== 32'h0000_0000) begin
        $fatal(1, "data-abort smoke should not write memory");
      end

      if (bus_valid && !(bus_size inside {BUS_SIZE_WORD, BUS_SIZE_HALF, BUS_SIZE_BYTE})) begin
        $fatal(1, "data-abort smoke saw invalid bus size");
      end

      if (bus_valid && bus_cycle !== BUS_CYCLE_NONSEQ && bus_cycle !== BUS_CYCLE_SEQ) begin
        $fatal(1, "data-abort smoke saw invalid bus cycle");
      end

      if (unsupported) begin
        $fatal(1, "unexpected unsupported instruction at pc=%08x", debug_pc);
      end

      if (debug_reg_we && debug_reg_waddr == 4'd0 && debug_reg_wdata == 32'h0000_0040) begin
        base_setup_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd0 && debug_reg_wdata == 32'h0000_0044) begin
        base_wb_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd2 && debug_reg_wdata == 32'hCAFE_F00D) begin
        aborted_load_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd14 && debug_reg_wdata == 32'h0000_0014) begin
        lr_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd0 && debug_reg_wdata == 32'h0000_0097) begin
        cpsr_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd1 && debug_reg_wdata == 32'h0000_0013) begin
        spsr_seen++;
      end

      if (retired && debug_pc == 32'h0000_0018) begin
        loop_seen++;
      end
    end

    if (base_setup_seen != 1) begin
      $fatal(1, "expected one base setup write, saw %0d", base_setup_seen);
    end

    if (base_wb_seen != 1) begin
      $fatal(1, "expected aborted single-transfer base writeback, saw %0d", base_wb_seen);
    end

    if (aborted_load_seen != 0) begin
      $fatal(1, "data-aborted load wrote destination %0d times", aborted_load_seen);
    end

    if (lr_seen != 1) begin
      $fatal(1, "expected one data-abort LR write of 0x14, saw %0d", lr_seen);
    end

    if (cpsr_seen != 1) begin
      $fatal(1, "expected one data-abort CPSR read of 0x97, saw %0d", cpsr_seen);
    end

    if (spsr_seen != 1) begin
      $fatal(1, "expected one data-abort SPSR read of 0x13, saw %0d", spsr_seen);
    end

    if (debug_cpsr !== 32'h0000_0097) begin
      $fatal(1, "expected data abort to enter ABT with I set, got %08x", debug_cpsr);
    end

    if (loop_seen < 2) begin
      $fatal(1, "expected data-abort vector loop to retire, saw %0d", loop_seen);
    end

    $display("tb_arm7tdmi_core_data_abort passed");
    $finish;
  end
endmodule
