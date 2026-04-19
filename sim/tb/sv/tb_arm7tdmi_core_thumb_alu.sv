`timescale 1ns/1ps

module tb_arm7tdmi_core_thumb_alu
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

  int and_seen;
  int mvn_seen;
  int eor_seen;
  int bic_seen;
  int orr_seen;
  int lsl_seen;
  int lsr_seen;
  int asr_seen;
  int ror_seen;
  int tst_seen;
  int neg_seen;
  int adc_seen;
  int sbc_seen;
  int mul_seen;
  int cmp_seen;
  int cmn_seen;
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
      32'h0000_0000: bus_rdata = 32'hE3A0_6021; // MOV r6, #0x21
      32'h0000_0004: bus_rdata = 32'hE12F_FF16; // BX r6
      32'h0000_0020: bus_rdata = 32'h0000_20F0; // Thumb MOV r0, #0xf0
      32'h0000_0022: bus_rdata = 32'h0000_210F; // Thumb MOV r1, #0x0f
      32'h0000_0024: bus_rdata = 32'h0000_2202; // Thumb MOV r2, #2
      32'h0000_0026: bus_rdata = 32'h0000_4008; // Thumb AND r0, r1
      32'h0000_0028: bus_rdata = 32'h0000_43C3; // Thumb MVN r3, r0
      32'h0000_002A: bus_rdata = 32'h0000_404B; // Thumb EOR r3, r1
      32'h0000_002C: bus_rdata = 32'h0000_438B; // Thumb BIC r3, r1
      32'h0000_002E: bus_rdata = 32'h0000_4308; // Thumb ORR r0, r1
      32'h0000_0030: bus_rdata = 32'h0000_4091; // Thumb LSL r1, r2
      32'h0000_0032: bus_rdata = 32'h0000_40D1; // Thumb LSR r1, r2
      32'h0000_0034: bus_rdata = 32'h0000_4113; // Thumb ASR r3, r2
      32'h0000_0036: bus_rdata = 32'h0000_41D1; // Thumb ROR r1, r2
      32'h0000_0038: bus_rdata = 32'h0000_4211; // Thumb TST r1, r2
      32'h0000_003A: bus_rdata = 32'h0000_4254; // Thumb NEG r4, r2
      32'h0000_003C: bus_rdata = 32'h0000_429C; // Thumb CMP r4, r3
      32'h0000_003E: bus_rdata = 32'h0000_42E2; // Thumb CMN r2, r4
      32'h0000_0040: bus_rdata = 32'h0000_2501; // Thumb MOV r5, #1
      32'h0000_0042: bus_rdata = 32'h0000_4155; // Thumb ADC r5, r2
      32'h0000_0044: bus_rdata = 32'h0000_4195; // Thumb SBC r5, r2
      32'h0000_0046: bus_rdata = 32'h0000_4355; // Thumb MUL r5, r2
      32'h0000_0048: bus_rdata = 32'h0000_E7FE; // Thumb B .
      default:       bus_rdata = 32'hE1A0_0000;
    endcase
  end

  task automatic check_bus_contract;
    if (bus_write || bus_wdata !== 32'h0000_0000) begin
      $fatal(1, "thumb ALU test should not write memory");
    end

    if (bus_valid && !(bus_size inside {BUS_SIZE_HALF, BUS_SIZE_WORD})) begin
      $fatal(1, "thumb ALU saw invalid bus size");
    end

    if (bus_valid && !(bus_cycle inside {BUS_CYCLE_NONSEQ, BUS_CYCLE_SEQ})) begin
      $fatal(1, "thumb ALU saw invalid cycle class");
    end

    if (unsupported) begin
      $fatal(1, "unexpected unsupported instruction at pc=%08x cpsr=%08x", debug_pc, debug_cpsr);
    end
  endtask

  initial begin
    rst_n = 1'b0;
    bus_ready = 1'b1;
    and_seen = 0;
    mvn_seen = 0;
    eor_seen = 0;
    bic_seen = 0;
    orr_seen = 0;
    lsl_seen = 0;
    lsr_seen = 0;
    asr_seen = 0;
    ror_seen = 0;
    tst_seen = 0;
    neg_seen = 0;
    adc_seen = 0;
    sbc_seen = 0;
    mul_seen = 0;
    cmp_seen = 0;
    cmn_seen = 0;
    loop_seen = 0;

    repeat (2) @(posedge clk);
    rst_n = 1'b1;

    for (int cycle = 0; cycle < 140; cycle++) begin
      @(posedge clk);
      #1;
      check_bus_contract();

      if (debug_reg_we && debug_pc == 32'h0000_0028 &&
          debug_reg_waddr == 4'd0 && debug_reg_wdata == 32'h0000_0000) begin
        and_seen++;
      end

      if (debug_reg_we && debug_pc == 32'h0000_002A &&
          debug_reg_waddr == 4'd3 && debug_reg_wdata == 32'hFFFF_FFFF) begin
        mvn_seen++;
      end

      if (debug_reg_we && debug_pc == 32'h0000_002C &&
          debug_reg_waddr == 4'd3 && debug_reg_wdata == 32'hFFFF_FFF0) begin
        eor_seen++;
      end

      if (debug_reg_we && debug_pc == 32'h0000_002E &&
          debug_reg_waddr == 4'd3 && debug_reg_wdata == 32'hFFFF_FFF0) begin
        bic_seen++;
      end

      if (debug_reg_we && debug_pc == 32'h0000_0030 &&
          debug_reg_waddr == 4'd0 && debug_reg_wdata == 32'h0000_000F) begin
        orr_seen++;
      end

      if (debug_reg_we && debug_pc == 32'h0000_0032 &&
          debug_reg_waddr == 4'd1 && debug_reg_wdata == 32'h0000_003C) begin
        lsl_seen++;
      end

      if (debug_reg_we && debug_pc == 32'h0000_0034 &&
          debug_reg_waddr == 4'd1 && debug_reg_wdata == 32'h0000_000F) begin
        lsr_seen++;
      end

      if (debug_reg_we && debug_pc == 32'h0000_0036 &&
          debug_reg_waddr == 4'd3 && debug_reg_wdata == 32'hFFFF_FFFC) begin
        asr_seen++;
      end

      if (debug_reg_we && debug_pc == 32'h0000_0038 &&
          debug_reg_waddr == 4'd1 && debug_reg_wdata == 32'hC000_0003) begin
        ror_seen++;
      end

      if (retired && debug_pc == 32'h0000_003A && !debug_reg_we &&
          !debug_cpsr[30]) begin
        tst_seen++;
      end

      if (debug_reg_we && debug_pc == 32'h0000_003C &&
          debug_reg_waddr == 4'd4 && debug_reg_wdata == 32'hFFFF_FFFE) begin
        neg_seen++;
      end

      if (retired && debug_pc == 32'h0000_003E && !debug_reg_we) begin
        cmp_seen++;
      end

      if (retired && debug_pc == 32'h0000_0040 && !debug_reg_we) begin
        cmn_seen++;
      end

      if (debug_reg_we && debug_pc == 32'h0000_0044 &&
          debug_reg_waddr == 4'd5 && debug_reg_wdata == 32'h0000_0004) begin
        adc_seen++;
      end

      if (debug_reg_we && debug_pc == 32'h0000_0046 &&
          debug_reg_waddr == 4'd5 && debug_reg_wdata == 32'h0000_0001) begin
        sbc_seen++;
      end

      if (debug_reg_we && debug_pc == 32'h0000_0048 &&
          debug_reg_waddr == 4'd5 && debug_reg_wdata == 32'h0000_0002) begin
        mul_seen++;
      end

      if (retired && debug_pc == 32'h0000_0048 && debug_cpsr[5]) begin
        loop_seen++;
      end
    end

    if (and_seen != 1 || mvn_seen != 1 || eor_seen != 1 || bic_seen != 1 ||
        orr_seen != 1 || lsl_seen != 1 || lsr_seen != 1 || asr_seen != 1 ||
        ror_seen != 1 || tst_seen != 1 || neg_seen != 1 || cmp_seen != 1 ||
        cmn_seen != 1 || adc_seen != 1 || sbc_seen != 1 || mul_seen != 1) begin
      $fatal(1, "missing Thumb ALU result: and=%0d mvn=%0d eor=%0d bic=%0d orr=%0d lsl=%0d lsr=%0d asr=%0d ror=%0d tst=%0d neg=%0d cmp=%0d cmn=%0d adc=%0d sbc=%0d mul=%0d",
             and_seen, mvn_seen, eor_seen, bic_seen, orr_seen, lsl_seen, lsr_seen,
             asr_seen, ror_seen, tst_seen, neg_seen, cmp_seen, cmn_seen, adc_seen,
             sbc_seen, mul_seen);
    end

    if (loop_seen < 2) begin
      $fatal(1, "expected Thumb ALU loop to retire, saw %0d", loop_seen);
    end

    $display("tb_arm7tdmi_core_thumb_alu passed");
    $finish;
  end
endmodule
