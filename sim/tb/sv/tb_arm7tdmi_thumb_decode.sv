`timescale 1ns/1ps

module tb_arm7tdmi_thumb_decode
  import arm7tdmi_pkg::*;
;
  logic [15:0] instr;
  thumb_decoded_t decoded;

  arm7tdmi_thumb_decode dut (
    .instr_i(instr),
    .decoded_o(decoded)
  );

  task automatic decode(input logic [15:0] value);
    instr = value;
    #1;
  endtask

  task automatic expect_op(input thumb_op_class_t op);
    if (decoded.op_class !== op || !decoded.supported) begin
      $fatal(1, "expected op %0d for %04x, got op=%0d supported=%0b",
             op, instr, decoded.op_class, decoded.supported);
    end
  endtask

  initial begin
    decode(16'h0048); // LSL r0, r1, #1
    expect_op(THUMB_OP_SHIFT_IMM);
    if (decoded.rd !== 3'd0 || decoded.rm !== 4'd1 ||
        decoded.shift_type !== SHIFT_LSL || decoded.shift_imm !== 5'd1) begin
      $fatal(1, "LSL immediate decode mismatch");
    end

    decode(16'h0851); // LSR r1, r2, #1
    expect_op(THUMB_OP_SHIFT_IMM);
    if (decoded.rd !== 3'd1 || decoded.rm !== 4'd2 ||
        decoded.shift_type !== SHIFT_LSR || decoded.shift_imm !== 5'd1) begin
      $fatal(1, "LSR immediate decode mismatch");
    end

    decode(16'h105A); // ASR r2, r3, #1
    expect_op(THUMB_OP_SHIFT_IMM);
    if (decoded.rd !== 3'd2 || decoded.rm !== 4'd3 ||
        decoded.shift_type !== SHIFT_ASR || decoded.shift_imm !== 5'd1) begin
      $fatal(1, "ASR immediate decode mismatch");
    end

    decode(16'h1842); // ADD r2, r0, r1
    expect_op(THUMB_OP_ADD_REG);
    if (decoded.rd !== 3'd2 || decoded.rs !== 3'd0 ||
        decoded.rn !== 3'd1 || decoded.rm !== 4'd1) begin
      $fatal(1, "ADD register decode mismatch");
    end

    decode(16'h1A65); // SUB r5, r4, r1
    expect_op(THUMB_OP_SUB_REG);
    if (decoded.rd !== 3'd5 || decoded.rs !== 3'd4 ||
        decoded.rn !== 3'd1 || decoded.rm !== 4'd1) begin
      $fatal(1, "SUB register decode mismatch");
    end

    decode(16'h1DDC); // ADD r4, r3, #7
    expect_op(THUMB_OP_ADD_IMM3);
    if (decoded.rd !== 3'd4 || decoded.rs !== 3'd3 || decoded.imm3 !== 3'd7) begin
      $fatal(1, "ADD 3-bit immediate decode mismatch");
    end

    decode(16'h1ED3); // SUB r3, r2, #3
    expect_op(THUMB_OP_SUB_IMM3);
    if (decoded.rd !== 3'd3 || decoded.rs !== 3'd2 || decoded.imm3 !== 3'd3) begin
      $fatal(1, "SUB 3-bit immediate decode mismatch");
    end

    decode(16'h212A); // MOV r1, #0x2a
    expect_op(THUMB_OP_MOV_IMM);
    if (decoded.rd !== 3'd1 || decoded.imm8 !== 8'h2A) begin
      $fatal(1, "MOV immediate decode mismatch");
    end

    decode(16'h2901); // CMP r1, #1
    expect_op(THUMB_OP_CMP_IMM);
    if (decoded.rd !== 3'd1 || decoded.imm8 !== 8'h01) begin
      $fatal(1, "CMP immediate decode mismatch");
    end

    decode(16'h3101); // ADD r1, #1
    expect_op(THUMB_OP_ADD_IMM);
    if (decoded.rd !== 3'd1 || decoded.imm8 !== 8'h01) begin
      $fatal(1, "ADD immediate decode mismatch");
    end

    decode(16'h3902); // SUB r1, #2
    expect_op(THUMB_OP_SUB_IMM);
    if (decoded.rd !== 3'd1 || decoded.imm8 !== 8'h02) begin
      $fatal(1, "SUB immediate decode mismatch");
    end

    decode(16'h4008); // AND r0, r1
    expect_op(THUMB_OP_ALU_REG);
    if (decoded.alu_op !== THUMB_ALU_AND || decoded.rd !== 3'd0 ||
        decoded.rs !== 3'd1 || decoded.rm !== 4'd1) begin
      $fatal(1, "ALU register AND decode mismatch");
    end

    decode(16'h4091); // LSL r1, r2
    expect_op(THUMB_OP_ALU_REG);
    if (decoded.alu_op !== THUMB_ALU_LSL || decoded.rd !== 3'd1 ||
        decoded.rs !== 3'd2 || decoded.rm !== 4'd2) begin
      $fatal(1, "ALU register LSL decode mismatch");
    end

    decode(16'h4254); // NEG r4, r2
    expect_op(THUMB_OP_ALU_REG);
    if (decoded.alu_op !== THUMB_ALU_NEG || decoded.rd !== 3'd4 ||
        decoded.rs !== 3'd2 || decoded.rm !== 4'd2) begin
      $fatal(1, "ALU register NEG decode mismatch");
    end

    decode(16'h4355); // MUL r5, r2
    expect_op(THUMB_OP_ALU_REG);
    if (decoded.alu_op !== THUMB_ALU_MUL || decoded.rd !== 3'd5 ||
        decoded.rs !== 3'd2 || decoded.rm !== 4'd2) begin
      $fatal(1, "ALU register MUL decode mismatch");
    end

    decode(16'h4A01); // LDR r2, [PC, #4]
    expect_op(THUMB_OP_LDR_PC);
    if (decoded.rd !== 3'd2 || decoded.imm8 !== 8'h01) begin
      $fatal(1, "PC-relative LDR decode mismatch");
    end

    decode(16'h4700); // BX r0
    expect_op(THUMB_OP_BRANCH_EXCHANGE);
    if (decoded.rm !== 4'd0) begin
      $fatal(1, "BX low-register decode mismatch");
    end

    decode(16'h4740); // BX r8
    expect_op(THUMB_OP_BRANCH_EXCHANGE);
    if (decoded.rm !== 4'd8) begin
      $fatal(1, "BX high-register decode mismatch");
    end

    decode(16'h4488); // ADD r8, r1
    expect_op(THUMB_OP_HI_ADD);
    if (decoded.rd4 !== 4'd8 || decoded.rm !== 4'd1) begin
      $fatal(1, "high-register ADD decode mismatch");
    end

    decode(16'h4590); // CMP r8, r2
    expect_op(THUMB_OP_HI_CMP);
    if (decoded.rd4 !== 4'd8 || decoded.rm !== 4'd2) begin
      $fatal(1, "high-register CMP decode mismatch");
    end

    decode(16'h4643); // MOV r3, r8
    expect_op(THUMB_OP_HI_MOV);
    if (decoded.rd4 !== 4'd3 || decoded.rm !== 4'd8) begin
      $fatal(1, "high-register MOV decode mismatch");
    end

    decode(16'hD001); // BEQ +2
    expect_op(THUMB_OP_COND_BRANCH);
    if (decoded.cond !== COND_EQ || decoded.branch_imm8 !== 8'h01) begin
      $fatal(1, "conditional branch decode mismatch");
    end

    decode(16'hDE00);
    if (decoded.supported) begin
      $fatal(1, "undefined Thumb conditional branch decoded as supported");
    end

    decode(16'hE7FE); // B .
    expect_op(THUMB_OP_BRANCH);
    if (decoded.branch_imm11 !== 11'h7FE) begin
      $fatal(1, "B immediate decode mismatch");
    end

    decode(16'hDE00);
    if (decoded.supported) begin
      $fatal(1, "unsupported Thumb opcode decoded as supported");
    end

    $display("tb_arm7tdmi_thumb_decode passed");
    $finish;
  end
endmodule
