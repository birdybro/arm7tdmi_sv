`timescale 1ns/1ps

module tb_arm7tdmi_core_block_abort_wait
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

  logic stall_active;
  logic [31:0] stall_addr_q;
  int first_load_seen;
  int aborted_load_seen;
  int later_load_seen;
  int base_setup_seen;
  int base_wb_seen;
  int lr_seen;
  int spsr_seen;
  int loop_seen;
  int wait_cycles;

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
      32'h0000_0004: bus_rdata = 32'hE3A0_0080; // MOV r0, #0x80
      32'h0000_0008: bus_rdata = 32'hE8B0_000E; // LDMIA r0!, {r1-r3}
      32'h0000_000C: bus_rdata = 32'hE10F_4000; // MRS r4, CPSR
      32'h0000_0010: bus_rdata = 32'hE14F_5000; // MRS r5, SPSR
      32'h0000_0014: bus_rdata = 32'hEAFF_FFFE; // B .
      32'h0000_0080: bus_rdata = 32'hAAAA_AAAA;
      32'h0000_0084: bus_rdata = 32'hBBBB_BBBB;
      32'h0000_0088: bus_rdata = 32'hCCCC_CCCC;
      default:       bus_rdata = 32'hE1A0_0000;
    endcase
  end

  always_comb begin
    bus_ready = 1'b1;
    if (bus_valid && !bus_write && bus_addr == 32'h0000_0084 && wait_cycles < 2) begin
      bus_ready = 1'b0;
    end
  end

  assign bus_abort = bus_valid && bus_ready && !bus_write && (bus_addr == 32'h0000_0084);

  always_ff @(posedge clk) begin
    if (bus_valid && !bus_ready) begin
      if (stall_active && bus_addr !== stall_addr_q) begin
        $fatal(1, "block abort wait changed address while stalled %08x/%08x", bus_addr, stall_addr_q);
      end
      stall_active <= 1'b1;
      stall_addr_q <= bus_addr;
      wait_cycles <= wait_cycles + 1;
    end else begin
      stall_active <= 1'b0;
    end
  end

  initial begin
    rst_n = 1'b0;
    base_setup_seen = 0;
    first_load_seen = 0;
    aborted_load_seen = 0;
    later_load_seen = 0;
    base_wb_seen = 0;
    lr_seen = 0;
    spsr_seen = 0;
    loop_seen = 0;
    wait_cycles = 0;
    stall_active = 1'b0;
    stall_addr_q = 32'h0;

    repeat (2) @(posedge clk);
    rst_n = 1'b1;

    for (int cycle = 0; cycle < 100; cycle++) begin
      @(posedge clk);
      #1;

      if (bus_write || bus_wdata !== 32'h0000_0000) begin
        $fatal(1, "block-abort-wait smoke should not write memory");
      end
      if (bus_valid && bus_size !== BUS_SIZE_WORD) begin
        $fatal(1, "block-abort-wait smoke expected word transfers");
      end
      if (bus_valid && !(bus_cycle inside {BUS_CYCLE_NONSEQ, BUS_CYCLE_SEQ})) begin
        $fatal(1, "block-abort-wait smoke saw invalid cycle class");
      end
      if (unsupported) begin
        $fatal(1, "unexpected unsupported instruction at pc=%08x", debug_pc);
      end
      if (!bus_ready && retired) begin
        $fatal(1, "block abort path should not retire while stalled");
      end
      if (!bus_ready && debug_reg_we && (debug_reg_waddr inside {4'd2, 4'd3, 4'd14, 4'd5})) begin
        $fatal(1, "block abort path wrote aborted/later context too early while stalled");
      end

      if (debug_reg_we && debug_reg_waddr == 4'd0 && debug_reg_wdata == 32'h0000_0080) base_setup_seen++;
      if (debug_reg_we && debug_reg_waddr == 4'd1 && debug_reg_wdata == 32'hAAAA_AAAA) first_load_seen++;
      if (debug_reg_we && debug_reg_waddr == 4'd2 && debug_reg_wdata == 32'hBBBB_BBBB) aborted_load_seen++;
      if (debug_reg_we && debug_reg_waddr == 4'd3 && debug_reg_wdata == 32'hCCCC_CCCC) later_load_seen++;
      if (debug_reg_we && debug_reg_waddr == 4'd0 && debug_reg_wdata == 32'h0000_008C) base_wb_seen++;
      if (debug_reg_we && debug_reg_waddr == 4'd14 && debug_reg_wdata == 32'h0000_0010) lr_seen++;
      if (debug_reg_we && debug_reg_waddr == 4'd5 && debug_reg_wdata == 32'h0000_0013) spsr_seen++;
      if (retired && debug_pc == 32'h0000_0014) loop_seen++;
    end

    if (wait_cycles != 2) begin
      $fatal(1, "expected two wait cycles before block abort, saw %0d", wait_cycles);
    end
    if (base_setup_seen != 1 || first_load_seen != 1) begin
      $fatal(1, "expected base setup and first block load once, saw base=%0d r1=%0d", base_setup_seen, first_load_seen);
    end
    if (aborted_load_seen != 0 || later_load_seen != 0) begin
      $fatal(1, "block abort after wait wrote aborted/later registers, saw r2=%0d r3=%0d",
             aborted_load_seen, later_load_seen);
    end
    if (base_wb_seen != 0) begin
      $fatal(1, "block abort after wait wrote final base writeback %0d times", base_wb_seen);
    end
    if (lr_seen != 1 || spsr_seen != 1) begin
      $fatal(1, "expected one abort LR write and SPSR read, saw lr=%0d spsr=%0d",
             lr_seen, spsr_seen);
    end
    if (debug_cpsr !== 32'h0000_0097) begin
      $fatal(1, "expected block abort after wait to enter ABT with I set, got %08x", debug_cpsr);
    end
    if (loop_seen < 2) begin
      $fatal(1, "expected block-abort-wait vector loop to retire, saw %0d", loop_seen);
    end

    $display("tb_arm7tdmi_core_block_abort_wait passed");
    $finish;
  end
endmodule
