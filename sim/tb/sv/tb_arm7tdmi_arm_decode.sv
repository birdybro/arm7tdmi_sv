`timescale 1ns/1ps

module tb_arm7tdmi_arm_decode
  import arm7tdmi_pkg::*;
;
  logic [31:0] instr;
  arm_decoded_t decoded;

  arm7tdmi_arm_decode dut (
    .instr_i(instr),
    .decoded_o(decoded)
  );

  task automatic decode(input logic [31:0] instr_t);
    instr = instr_t;
    #1;
  endtask

  task automatic expect_class(input arm_op_class_t expected_class, input logic expected_supported);
    if (decoded.op_class !== expected_class || decoded.supported !== expected_supported) begin
      $fatal(1, "instr=%08x expected class=%0d supported=%0b got class=%0d supported=%0b",
             instr, expected_class, expected_supported, decoded.op_class, decoded.supported);
    end
  endtask

  initial begin
    decode(32'hE3A0_0001); // MOV r0, #1
    expect_class(ARM_OP_DATA_PROCESSING, 1'b1);
    if (decoded.cond !== COND_AL || decoded.alu_op !== ALU_MOV ||
        !decoded.immediate_operand || decoded.rd !== 4'd0 ||
        decoded.imm8 !== 8'h01 || decoded.rotate_imm !== 4'h0 ||
        decoded.set_flags) begin
      $fatal(1, "MOV immediate decode mismatch");
    end

    decode(32'hE350_0000); // CMP r0, #0
    expect_class(ARM_OP_DATA_PROCESSING, 1'b1);
    if (decoded.alu_op !== ALU_CMP || !decoded.set_flags ||
        decoded.rn !== 4'd0 || decoded.imm8 !== 8'h00) begin
      $fatal(1, "CMP immediate decode mismatch");
    end

    decode(32'hE280_1002); // ADD r1, r0, #2
    expect_class(ARM_OP_DATA_PROCESSING, 1'b1);
    if (decoded.alu_op !== ALU_ADD || decoded.rn !== 4'd0 || decoded.rd !== 4'd1 ||
        decoded.imm8 !== 8'h02) begin
      $fatal(1, "ADD immediate decode mismatch");
    end

    decode(32'hE080_1102); // ADD r1, r0, r2, LSL #2
    expect_class(ARM_OP_DATA_PROCESSING, 1'b1);
    if (decoded.register_shift || decoded.rm !== 4'd2 || decoded.shift_type !== SHIFT_LSL ||
        decoded.shift_imm !== 5'd2) begin
      $fatal(1, "ADD register immediate-shift decode mismatch");
    end

    decode(32'hE080_1312); // ADD r1, r0, r2, LSL r3
    expect_class(ARM_OP_DATA_PROCESSING, 1'b1);
    if (!decoded.register_shift || decoded.rs !== 4'd3) begin
      $fatal(1, "register-specified shift decode mismatch");
    end

    decode(32'hEAFF_FFFE); // B .
    expect_class(ARM_OP_BRANCH, 1'b1);
    if (decoded.branch_link || decoded.branch_imm24 !== 24'hFFFFFE) begin
      $fatal(1, "B decode mismatch");
    end

    decode(32'hEB00_0001); // BL +1
    expect_class(ARM_OP_BRANCH, 1'b1);
    if (!decoded.branch_link || decoded.branch_imm24 !== 24'h000001) begin
      $fatal(1, "BL decode mismatch");
    end

    decode(32'hE12F_FF10); // BX r0
    expect_class(ARM_OP_BRANCH_EXCHANGE, 1'b1);
    if (decoded.rm !== 4'd0) begin
      $fatal(1, "BX decode mismatch");
    end

    decode(32'hE590_1000); // LDR r1, [r0]
    expect_class(ARM_OP_SINGLE_DATA_TRANSFER, 1'b1);
    if (!decoded.ls_pre_index || !decoded.ls_up || decoded.ls_byte ||
        decoded.ls_writeback || !decoded.ls_load || decoded.ls_offset12 !== 12'h000) begin
      $fatal(1, "LDR immediate word decode mismatch");
    end

    decode(32'hE580_1004); // STR r1, [r0, #4]
    expect_class(ARM_OP_SINGLE_DATA_TRANSFER, 1'b1);
    if (!decoded.ls_pre_index || !decoded.ls_up || decoded.ls_byte ||
        decoded.ls_writeback || decoded.ls_load || decoded.ls_offset12 !== 12'h004) begin
      $fatal(1, "STR immediate word decode mismatch");
    end

    decode(32'hE5A0_1004); // STR r1, [r0, #4]!
    expect_class(ARM_OP_SINGLE_DATA_TRANSFER, 1'b1);
    if (!decoded.ls_writeback || decoded.ls_load) begin
      $fatal(1, "STR immediate writeback decode mismatch");
    end

    decode(32'hE5B0_1004); // LDR r1, [r0, #4]!
    expect_class(ARM_OP_SINGLE_DATA_TRANSFER, 1'b0);

    decode(32'hE5D0_1000); // LDRB r1, [r0]
    expect_class(ARM_OP_SINGLE_DATA_TRANSFER, 1'b1);
    if (!decoded.ls_byte || !decoded.ls_load) begin
      $fatal(1, "LDRB immediate decode mismatch");
    end

    decode(32'hE000_0091); // MUL r0, r1, r0
    expect_class(ARM_OP_MULTIPLY, 1'b0);

    decode(32'hEF00_0011); // SWI
    expect_class(ARM_OP_SWI, 1'b0);

    $display("tb_arm7tdmi_arm_decode passed");
    $finish;
  end
endmodule
