`timescale 1ns/1ps

module tb_arm7tdmi_core_coprocessor_abort
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

  logic coproc_valid;
  arm_coproc_op_t coproc_op;
  /* verilator lint_off UNUSEDSIGNAL */
  logic [3:0] coproc_num;
  logic [3:0] coproc_opcode1;
  logic [2:0] coproc_opcode2;
  logic [3:0] coproc_crn;
  logic [3:0] coproc_crd;
  logic [3:0] coproc_crm;
  /* verilator lint_on UNUSEDSIGNAL */
  /* verilator lint_off UNUSEDSIGNAL */
  logic coproc_long;
  /* verilator lint_on UNUSEDSIGNAL */
  logic [31:0] coproc_wdata;
  logic coproc_accept;
  logic coproc_ready;
  logic [31:0] coproc_rdata;
  logic coproc_last;

  logic [31:0] cp_regs [0:15];

  int base_setup_seen;
  int aborted_ldc_wb_seen;
  int lr_seen;
  int cpsr_seen;
  int spsr_seen;
  int unexpected_gpr_seen;
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
    .coproc_valid_o(coproc_valid),
    .coproc_op_o(coproc_op),
    .coproc_num_o(coproc_num),
    .coproc_opcode1_o(coproc_opcode1),
    .coproc_opcode2_o(coproc_opcode2),
    .coproc_crn_o(coproc_crn),
    .coproc_crd_o(coproc_crd),
    .coproc_crm_o(coproc_crm),
    .coproc_long_o(coproc_long),
    .coproc_wdata_o(coproc_wdata),
    .coproc_accept_i(coproc_accept),
    .coproc_ready_i(coproc_ready),
    .coproc_rdata_i(coproc_rdata),
    .coproc_last_i(coproc_last),
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
      32'h0000_0004: bus_rdata = 32'hE3A0_0040; // MOV r0, #0x40
      32'h0000_0008: bus_rdata = 32'hECD0_4202; // LDC p2, c4, [r0], #8
      32'h0000_000C: bus_rdata = 32'hE3A0_30AA; // MOV r3, #0xaa
      32'h0000_0010: bus_rdata = 32'hE10F_1000; // MRS r1, CPSR
      32'h0000_0014: bus_rdata = 32'hE14F_2000; // MRS r2, SPSR
      32'h0000_0018: bus_rdata = 32'hEAFF_FFFE; // B .
      32'h0000_0040: bus_rdata = 32'hCAFE_F00D;
      32'h0000_0044: bus_rdata = 32'h1122_3344;
      default:       bus_rdata = 32'hE1A0_0000; // MOV r0, r0
    endcase
  end

  assign bus_abort = bus_valid && !bus_write && (bus_addr == 32'h0000_0040);

  always_comb begin
    coproc_accept = 1'b1;
    coproc_ready = coproc_valid;
    coproc_rdata = 32'h0000_0000;
    coproc_last = 1'b1;
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (int idx = 0; idx < 16; idx++) begin
        cp_regs[idx] <= 32'h0000_0000;
      end
    end else if (coproc_valid && coproc_accept && coproc_ready && coproc_op == COPROC_OP_LDC) begin
      cp_regs[coproc_crd] <= coproc_wdata;
    end
  end

  initial begin
    rst_n = 1'b0;
    bus_ready = 1'b1;
    base_setup_seen = 0;
    aborted_ldc_wb_seen = 0;
    lr_seen = 0;
    cpsr_seen = 0;
    spsr_seen = 0;
    unexpected_gpr_seen = 0;
    loop_seen = 0;

    repeat (2) @(posedge clk);
    rst_n = 1'b1;

    for (int cycle = 0; cycle < 80; cycle++) begin
      @(posedge clk);
      #1;

      if (unsupported) begin
        $fatal(1, "unexpected unsupported instruction at pc=%08x cpsr=%08x", debug_pc, debug_cpsr);
      end

      if (bus_write || bus_wdata !== 32'h0000_0000) begin
        $fatal(1, "coprocessor abort smoke should not perform memory writes");
      end

      if (bus_valid && !(bus_size inside {BUS_SIZE_WORD})) begin
        $fatal(1, "coprocessor abort smoke expected word bus accesses only");
      end

      if (bus_valid && !(bus_cycle inside {BUS_CYCLE_NONSEQ, BUS_CYCLE_SEQ, BUS_CYCLE_COPROC})) begin
        $fatal(1, "coprocessor abort smoke saw invalid bus cycle class %0d", bus_cycle);
      end

      if (debug_reg_we && debug_reg_waddr == 4'd0 && debug_reg_wdata == 32'h0000_0040) begin
        base_setup_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd0 && debug_reg_wdata == 32'h0000_0048) begin
        aborted_ldc_wb_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd14 && debug_reg_wdata == 32'h0000_0010) begin
        lr_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd1 && debug_reg_wdata == 32'h0000_0097) begin
        cpsr_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd2 && debug_reg_wdata == 32'h0000_0013) begin
        spsr_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd3 && debug_reg_wdata == 32'h0000_00AA) begin
        unexpected_gpr_seen++;
      end

      if (retired && debug_pc == 32'h0000_0018) begin
        loop_seen++;
      end
    end

    if (base_setup_seen != 1) begin
      $fatal(1, "expected one base setup write, saw %0d", base_setup_seen);
    end

    if (aborted_ldc_wb_seen != 1) begin
      $fatal(1, "expected aborted LDC writeback to 0x48, saw %0d", aborted_ldc_wb_seen);
    end

    if (lr_seen != 1) begin
      $fatal(1, "expected one data-abort LR write of 0x10, saw %0d", lr_seen);
    end

    if (cpsr_seen != 1 || spsr_seen != 1) begin
      $fatal(1, "expected one CPSR/SPSR abort readback, saw cpsr=%0d spsr=%0d",
             cpsr_seen, spsr_seen);
    end

    if (unexpected_gpr_seen != 0) begin
      $fatal(1, "instruction after aborted LDC unexpectedly executed %0d times", unexpected_gpr_seen);
    end

    if (cp_regs[4] !== 32'h0000_0000 || cp_regs[5] !== 32'h0000_0000) begin
      $fatal(1, "aborted LDC should not update coprocessor destination registers c4=%08x c5=%08x",
             cp_regs[4], cp_regs[5]);
    end

    if (debug_cpsr !== 32'h0000_0097) begin
      $fatal(1, "expected coprocessor abort to enter ABT with I set, got %08x", debug_cpsr);
    end

    if (loop_seen < 2) begin
      $fatal(1, "expected coprocessor abort vector loop to retire, saw %0d", loop_seen);
    end

    $display("tb_arm7tdmi_core_coprocessor_abort passed");
    $finish;
  end
endmodule
