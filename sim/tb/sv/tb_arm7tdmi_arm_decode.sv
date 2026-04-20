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

    decode(32'hE3A0_0090); // MOV r0, #0x90
    expect_class(ARM_OP_DATA_PROCESSING, 1'b1);
    if (decoded.alu_op !== ALU_MOV || !decoded.immediate_operand ||
        decoded.rd !== 4'd0 || decoded.imm8 !== 8'h90) begin
      $fatal(1, "MOV immediate 0x90 decode mismatch");
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

    decode(32'hE59F_F010); // LDR pc, [pc, #0x10]
    expect_class(ARM_OP_SINGLE_DATA_TRANSFER, 1'b1);
    if (decoded.rn !== 4'd15 || decoded.rd !== 4'd15 || !decoded.ls_load ||
        decoded.ls_byte || decoded.ls_writeback || decoded.ls_offset12 !== 12'h010) begin
      $fatal(1, "LDR pc literal decode mismatch");
    end

    decode(32'hE58F_1034); // STR r1, [pc, #0x34]
    expect_class(ARM_OP_SINGLE_DATA_TRANSFER, 1'b1);
    if (decoded.rn !== 4'd15 || decoded.rd !== 4'd1 || decoded.ls_load ||
        decoded.ls_writeback || !decoded.ls_pre_index || decoded.ls_offset12 !== 12'h034) begin
      $fatal(1, "STR pc-relative decode mismatch");
    end

    decode(32'hE5DF_F010); // LDRB pc, [pc, #0x10]
    expect_class(ARM_OP_SINGLE_DATA_TRANSFER, 1'b0);

    decode(32'hE5BF_F010); // LDR pc, [pc, #0x10]!
    expect_class(ARM_OP_SINGLE_DATA_TRANSFER, 1'b0);

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
    expect_class(ARM_OP_SINGLE_DATA_TRANSFER, 1'b1);

    decode(32'hE5B0_0004); // LDR r0, [r0, #4]!
    expect_class(ARM_OP_SINGLE_DATA_TRANSFER, 1'b0);

    decode(32'hE480_1004); // STR r1, [r0], #4
    expect_class(ARM_OP_SINGLE_DATA_TRANSFER, 1'b1);
    if (decoded.ls_pre_index || !decoded.ls_up || decoded.ls_writeback || decoded.ls_load) begin
      $fatal(1, "STR post-index immediate decode mismatch");
    end

    decode(32'hE410_1004); // LDR r1, [r0], #-4
    expect_class(ARM_OP_SINGLE_DATA_TRANSFER, 1'b1);
    if (decoded.ls_pre_index || decoded.ls_up || decoded.ls_writeback || !decoded.ls_load) begin
      $fatal(1, "LDR post-index immediate decode mismatch");
    end

    decode(32'hE4A0_1004); // STRT r1, [r0], #4
    expect_class(ARM_OP_SINGLE_DATA_TRANSFER, 1'b1);
    if (decoded.ls_pre_index || !decoded.ls_up || !decoded.ls_writeback ||
        decoded.ls_load || decoded.rn !== 4'd0 || decoded.rd !== 4'd1 ||
        decoded.ls_offset12 !== 12'h004) begin
      $fatal(1, "STRT post-index immediate decode mismatch");
    end

    decode(32'hE4B0_2004); // LDRT r2, [r0], #4
    expect_class(ARM_OP_SINGLE_DATA_TRANSFER, 1'b1);
    if (decoded.ls_pre_index || !decoded.ls_up || !decoded.ls_writeback ||
        !decoded.ls_load || decoded.rn !== 4'd0 || decoded.rd !== 4'd2 ||
        decoded.ls_offset12 !== 12'h004) begin
      $fatal(1, "LDRT post-index immediate decode mismatch");
    end

    decode(32'hE880_000E); // STMIA r0, {r1-r3}
    expect_class(ARM_OP_BLOCK_DATA_TRANSFER, 1'b1);
    if (decoded.rn !== 4'd0 || decoded.ls_load || decoded.block_reglist !== 16'h000E) begin
      $fatal(1, "STMIA decode mismatch");
    end

    decode(32'hE890_0070); // LDMIA r0, {r4-r6}
    expect_class(ARM_OP_BLOCK_DATA_TRANSFER, 1'b1);
    if (decoded.rn !== 4'd0 || !decoded.ls_load || decoded.block_reglist !== 16'h0070) begin
      $fatal(1, "LDMIA decode mismatch");
    end

    decode(32'hE880_0000); // STMIA r0, {}
    expect_class(ARM_OP_BLOCK_DATA_TRANSFER, 1'b1);
    if (decoded.rn !== 4'd0 || decoded.ls_load || decoded.block_reglist !== 16'h0000) begin
      $fatal(1, "STMIA empty-list decode mismatch");
    end

    decode(32'hE890_0000); // LDMIA r0, {}
    expect_class(ARM_OP_BLOCK_DATA_TRANSFER, 1'b1);
    if (decoded.rn !== 4'd0 || !decoded.ls_load || decoded.block_reglist !== 16'h0000) begin
      $fatal(1, "LDMIA empty-list decode mismatch");
    end

    decode(32'hE890_8000); // LDMIA r0, {pc}
    expect_class(ARM_OP_BLOCK_DATA_TRANSFER, 1'b1);
    if (decoded.rn !== 4'd0 || !decoded.ls_load || decoded.ls_writeback ||
        decoded.psr_use_spsr || decoded.block_reglist !== 16'h8000) begin
      $fatal(1, "LDMIA pc decode mismatch");
    end

    decode(32'hE8D0_8000); // LDMIA r0, {pc}^
    expect_class(ARM_OP_BLOCK_DATA_TRANSFER, 1'b1);
    if (decoded.rn !== 4'd0 || !decoded.ls_load || !decoded.psr_use_spsr ||
        decoded.block_reglist !== 16'h8000) begin
      $fatal(1, "LDMIA pc restore decode mismatch");
    end

    decode(32'hE8B0_8000); // LDMIA r0!, {pc}
    expect_class(ARM_OP_BLOCK_DATA_TRANSFER, 1'b0);

    decode(32'hE8C0_6000); // STMIA r0, {r13-r14}^
    expect_class(ARM_OP_BLOCK_DATA_TRANSFER, 1'b1);
    if (decoded.rn !== 4'd0 || decoded.ls_load || !decoded.psr_use_spsr ||
        decoded.block_reglist !== 16'h6000) begin
      $fatal(1, "STMIA user-bank decode mismatch");
    end

    decode(32'hE8D0_6000); // LDMIA r0, {r13-r14}^
    expect_class(ARM_OP_BLOCK_DATA_TRANSFER, 1'b1);
    if (decoded.rn !== 4'd0 || !decoded.ls_load || !decoded.psr_use_spsr ||
        decoded.block_reglist !== 16'h6000) begin
      $fatal(1, "LDMIA user-bank decode mismatch");
    end

    decode(32'hE8A0_000E); // STMIA r0!, {r1-r3}
    expect_class(ARM_OP_BLOCK_DATA_TRANSFER, 1'b1);
    if (decoded.rn !== 4'd0 || !decoded.ls_writeback || decoded.block_reglist !== 16'h000E) begin
      $fatal(1, "STMIA writeback decode mismatch");
    end

    decode(32'hE988_0006); // STMIB r8, {r1-r2}
    expect_class(ARM_OP_BLOCK_DATA_TRANSFER, 1'b1);
    if (decoded.rn !== 4'd8 || !decoded.ls_pre_index || decoded.ls_load ||
        decoded.block_reglist !== 16'h0006) begin
      $fatal(1, "STMIB decode mismatch");
    end

    decode(32'hE80C_0006); // STMDA r12, {r1-r2}
    expect_class(ARM_OP_BLOCK_DATA_TRANSFER, 1'b1);
    if (decoded.rn !== 4'd12 || decoded.ls_pre_index || decoded.ls_up ||
        decoded.ls_load || decoded.block_reglist !== 16'h0006) begin
      $fatal(1, "STMDA decode mismatch");
    end

    decode(32'hE90C_0006); // STMDB r12, {r1-r2}
    expect_class(ARM_OP_BLOCK_DATA_TRANSFER, 1'b1);
    if (decoded.rn !== 4'd12 || !decoded.ls_pre_index || decoded.ls_up ||
        decoded.ls_load || decoded.block_reglist !== 16'h0006) begin
      $fatal(1, "STMDB decode mismatch");
    end

    decode(32'hE790_9001); // LDR r9, [r0, r1]
    expect_class(ARM_OP_SINGLE_DATA_TRANSFER, 1'b1);
    if (!decoded.immediate_operand || decoded.rm !== 4'd1 || decoded.rd !== 4'd9 ||
        decoded.shift_imm !== 5'd0 || decoded.shift_type !== SHIFT_LSL) begin
      $fatal(1, "LDR register-offset decode mismatch");
    end

    decode(32'hE780_1104); // STR r1, [r0, r4, LSL #2]
    expect_class(ARM_OP_SINGLE_DATA_TRANSFER, 1'b1);
    if (!decoded.immediate_operand || decoded.rm !== 4'd4 ||
        decoded.shift_imm !== 5'd2 || decoded.shift_type !== SHIFT_LSL) begin
      $fatal(1, "STR scaled register-offset decode mismatch");
    end

    decode(32'hE5D0_1000); // LDRB r1, [r0]
    expect_class(ARM_OP_SINGLE_DATA_TRANSFER, 1'b1);
    if (!decoded.ls_byte || !decoded.ls_load) begin
      $fatal(1, "LDRB immediate decode mismatch");
    end

    decode(32'hE000_0091); // MUL r0, r1, r0
    expect_class(ARM_OP_MULTIPLY, 1'b1);
    if (decoded.rd !== 4'd0 || decoded.rm !== 4'd1 || decoded.rs !== 4'd0 ||
        decoded.mul_accumulate || decoded.set_flags) begin
      $fatal(1, "MUL decode mismatch");
    end

    decode(32'hE023_2190); // MLA r3, r0, r1, r2
    expect_class(ARM_OP_MULTIPLY, 1'b1);
    if (decoded.rd !== 4'd3 || decoded.rn !== 4'd2 || decoded.rm !== 4'd0 ||
        decoded.rs !== 4'd1 || !decoded.mul_accumulate) begin
      $fatal(1, "MLA decode mismatch");
    end

    decode(32'hE087_6190); // UMULL r6, r7, r0, r1
    expect_class(ARM_OP_LONG_MULTIPLY, 1'b1);
    if (decoded.rd !== 4'd6 || decoded.rn !== 4'd7 || decoded.rm !== 4'd0 ||
        decoded.rs !== 4'd1 || decoded.mul_long_signed || decoded.mul_accumulate) begin
      $fatal(1, "UMULL decode mismatch");
    end

    decode(32'hE0A7_6190); // UMLAL r6, r7, r0, r1
    expect_class(ARM_OP_LONG_MULTIPLY, 1'b1);
    if (decoded.rd !== 4'd6 || decoded.rn !== 4'd7 || decoded.rm !== 4'd0 ||
        decoded.rs !== 4'd1 || decoded.mul_long_signed || !decoded.mul_accumulate) begin
      $fatal(1, "UMLAL decode mismatch");
    end

    decode(32'hE0CB_A998); // SMULL r10, r11, r8, r9
    expect_class(ARM_OP_LONG_MULTIPLY, 1'b1);
    if (decoded.rd !== 4'd10 || decoded.rn !== 4'd11 || decoded.rm !== 4'd8 ||
        decoded.rs !== 4'd9 || !decoded.mul_long_signed || decoded.mul_accumulate) begin
      $fatal(1, "SMULL decode mismatch");
    end

    decode(32'hE0EB_A998); // SMLAL r10, r11, r8, r9
    expect_class(ARM_OP_LONG_MULTIPLY, 1'b1);
    if (decoded.rd !== 4'd10 || decoded.rn !== 4'd11 || decoded.rm !== 4'd8 ||
        decoded.rs !== 4'd9 || !decoded.mul_long_signed || !decoded.mul_accumulate) begin
      $fatal(1, "SMLAL decode mismatch");
    end

    decode(32'hE100_2091); // SWP r2, r1, [r0]
    expect_class(ARM_OP_SWAP, 1'b1);
    if (decoded.rn !== 4'd0 || decoded.rd !== 4'd2 || decoded.rm !== 4'd1 ||
        decoded.ls_byte) begin
      $fatal(1, "SWP decode mismatch");
    end

    decode(32'hE140_4093); // SWPB r4, r3, [r0]
    expect_class(ARM_OP_SWAP, 1'b1);
    if (decoded.rn !== 4'd0 || decoded.rd !== 4'd4 || decoded.rm !== 4'd3 ||
        !decoded.ls_byte) begin
      $fatal(1, "SWPB decode mismatch");
    end

    decode(32'hE1C0_10B2); // STRH r1, [r0, #2]
    expect_class(ARM_OP_HALFWORD_TRANSFER, 1'b1);
    if (!decoded.ls_pre_index || !decoded.ls_up || decoded.ls_load ||
        !decoded.hword_immediate_offset || decoded.hword_transfer_type !== 2'b01 ||
        decoded.hword_offset8 !== 8'h02) begin
      $fatal(1, "STRH immediate decode mismatch");
    end

    decode(32'hE1D0_20B2); // LDRH r2, [r0, #2]
    expect_class(ARM_OP_HALFWORD_TRANSFER, 1'b1);
    if (!decoded.ls_pre_index || !decoded.ls_up || !decoded.ls_load ||
        !decoded.hword_immediate_offset || decoded.hword_transfer_type !== 2'b01 ||
        decoded.hword_offset8 !== 8'h02) begin
      $fatal(1, "LDRH immediate decode mismatch");
    end

    decode(32'hE180_10B5); // STRH r1, [r0, r5]
    expect_class(ARM_OP_HALFWORD_TRANSFER, 1'b1);
    if (!decoded.ls_pre_index || !decoded.ls_up || decoded.ls_load ||
        decoded.hword_immediate_offset || decoded.rm !== 4'd5 ||
        decoded.hword_transfer_type !== 2'b01) begin
      $fatal(1, "STRH register-offset decode mismatch");
    end

    decode(32'hE1B0_20B5); // LDRH r2, [r0, r5]!
    expect_class(ARM_OP_HALFWORD_TRANSFER, 1'b1);
    if (!decoded.ls_pre_index || !decoded.ls_writeback || !decoded.ls_load ||
        decoded.hword_immediate_offset || decoded.rm !== 4'd5 ||
        decoded.hword_transfer_type !== 2'b01) begin
      $fatal(1, "LDRH register-offset writeback decode mismatch");
    end

    decode(32'hE010_30B5); // LDRH r3, [r0], -r5
    expect_class(ARM_OP_HALFWORD_TRANSFER, 1'b1);
    if (decoded.ls_pre_index || decoded.ls_up || !decoded.ls_load ||
        decoded.hword_immediate_offset || decoded.rm !== 4'd5 ||
        decoded.hword_transfer_type !== 2'b01) begin
      $fatal(1, "LDRH register-offset post-index decode mismatch");
    end

    decode(32'hE1D0_30D4); // LDRSB r3, [r0, #4]
    expect_class(ARM_OP_HALFWORD_TRANSFER, 1'b1);
    if (!decoded.ls_load || decoded.hword_transfer_type !== 2'b10 ||
        !decoded.hword_immediate_offset || decoded.hword_offset8 !== 8'h04) begin
      $fatal(1, "LDRSB immediate decode mismatch");
    end

    decode(32'hE1D0_40F6); // LDRSH r4, [r0, #6]
    expect_class(ARM_OP_HALFWORD_TRANSFER, 1'b1);
    if (!decoded.ls_load || decoded.hword_transfer_type !== 2'b11 ||
        !decoded.hword_immediate_offset || decoded.hword_offset8 !== 8'h06) begin
      $fatal(1, "LDRSH immediate decode mismatch");
    end

    decode(32'hE10F_0000); // MRS r0, CPSR
    expect_class(ARM_OP_PSR_TRANSFER, 1'b1);
    if (decoded.rd !== 4'd0 || decoded.psr_write || decoded.psr_use_spsr) begin
      $fatal(1, "MRS CPSR decode mismatch");
    end

    decode(32'hE128_F001); // MSR CPSR_f, r1
    expect_class(ARM_OP_PSR_TRANSFER, 1'b1);
    if (decoded.rm !== 4'd1 || !decoded.psr_write || decoded.psr_use_spsr ||
        decoded.psr_field_mask !== 4'b1000) begin
      $fatal(1, "MSR CPSR_f register decode mismatch");
    end

    decode(32'hE328_F102); // MSR CPSR_f, #0x80000000
    expect_class(ARM_OP_PSR_TRANSFER, 1'b1);
    if (!decoded.immediate_operand || !decoded.psr_write || decoded.psr_use_spsr ||
        decoded.psr_field_mask !== 4'b1000 || decoded.rotate_imm !== 4'h1 ||
        decoded.imm8 !== 8'h02) begin
      $fatal(1, "MSR CPSR_f immediate decode mismatch");
    end

    decode(32'hE321_F013); // MSR CPSR_c, #0x13
    expect_class(ARM_OP_PSR_TRANSFER, 1'b1);
    if (!decoded.immediate_operand || !decoded.psr_write || decoded.psr_use_spsr ||
        decoded.psr_field_mask !== 4'b0001 || decoded.rotate_imm !== 4'h0 ||
        decoded.imm8 !== 8'h13) begin
      $fatal(1, "MSR CPSR_c immediate decode mismatch");
    end

    decode(32'hEF00_0011); // SWI
    expect_class(ARM_OP_SWI, 1'b1);

    $display("tb_arm7tdmi_arm_decode passed");
    $finish;
  end
endmodule
