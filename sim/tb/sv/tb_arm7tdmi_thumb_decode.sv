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

    decode(16'hE7FE); // B .
    expect_op(THUMB_OP_BRANCH);
    if (decoded.branch_imm11 !== 11'h7FE) begin
      $fatal(1, "B immediate decode mismatch");
    end

    decode(16'h0000);
    if (decoded.supported) begin
      $fatal(1, "unsupported Thumb opcode decoded as supported");
    end

    $display("tb_arm7tdmi_thumb_decode passed");
    $finish;
  end
endmodule
