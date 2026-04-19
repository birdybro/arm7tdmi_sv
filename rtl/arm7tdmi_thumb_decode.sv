`timescale 1ns/1ps

module arm7tdmi_thumb_decode
  import arm7tdmi_pkg::*;
(
  input  logic [15:0]     instr_i,
  output thumb_decoded_t  decoded_o
);
  always_comb begin
    decoded_o = '{
      op_class:      THUMB_OP_UNDEFINED,
      cond:          arm_cond_t'(instr_i[11:8]),
      rd:            instr_i[2:0],
      rd4:           {1'b0, instr_i[2:0]},
      rn:            instr_i[8:6],
      rs:            instr_i[5:3],
      rm:            {instr_i[6], instr_i[5:3]},
      shift_type:    arm_shift_t'(instr_i[12:11]),
      shift_imm:     instr_i[10:6],
      imm3:          instr_i[8:6],
      imm8:          instr_i[7:0],
      branch_imm8:   instr_i[7:0],
      branch_imm11:  instr_i[10:0],
      supported:     1'b0
    };

    unique casez (instr_i)
      16'b000110??????????: begin
        decoded_o.op_class  = instr_i[9] ? THUMB_OP_SUB_REG : THUMB_OP_ADD_REG;
        decoded_o.rm        = {1'b0, instr_i[8:6]};
        decoded_o.supported = 1'b1;
      end

      16'b000111??????????: begin
        decoded_o.op_class  = instr_i[9] ? THUMB_OP_SUB_IMM3 : THUMB_OP_ADD_IMM3;
        decoded_o.rm        = {1'b0, instr_i[8:6]};
        decoded_o.supported = 1'b1;
      end

      16'b00000???????????: begin
        decoded_o.op_class  = THUMB_OP_SHIFT_IMM;
        decoded_o.rm        = {1'b0, instr_i[5:3]};
        decoded_o.supported = 1'b1;
      end

      16'b00001???????????: begin
        decoded_o.op_class  = THUMB_OP_SHIFT_IMM;
        decoded_o.rm        = {1'b0, instr_i[5:3]};
        decoded_o.supported = 1'b1;
      end

      16'b00010???????????: begin
        decoded_o.op_class  = THUMB_OP_SHIFT_IMM;
        decoded_o.rm        = {1'b0, instr_i[5:3]};
        decoded_o.supported = 1'b1;
      end

      16'b00100???????????: begin
        decoded_o.op_class  = THUMB_OP_MOV_IMM;
        decoded_o.rd        = instr_i[10:8];
        decoded_o.rd4       = {1'b0, instr_i[10:8]};
        decoded_o.supported = 1'b1;
      end

      16'b00101???????????: begin
        decoded_o.op_class  = THUMB_OP_CMP_IMM;
        decoded_o.rd        = instr_i[10:8];
        decoded_o.rd4       = {1'b0, instr_i[10:8]};
        decoded_o.supported = 1'b1;
      end

      16'b00110???????????: begin
        decoded_o.op_class  = THUMB_OP_ADD_IMM;
        decoded_o.rd        = instr_i[10:8];
        decoded_o.rd4       = {1'b0, instr_i[10:8]};
        decoded_o.supported = 1'b1;
      end

      16'b00111???????????: begin
        decoded_o.op_class  = THUMB_OP_SUB_IMM;
        decoded_o.rd        = instr_i[10:8];
        decoded_o.rd4       = {1'b0, instr_i[10:8]};
        decoded_o.supported = 1'b1;
      end

      16'b01000100????????: begin
        decoded_o.op_class  = THUMB_OP_HI_ADD;
        decoded_o.rd4       = {instr_i[7], instr_i[2:0]};
        decoded_o.supported = 1'b1;
      end

      16'b01000101????????: begin
        decoded_o.op_class  = THUMB_OP_HI_CMP;
        decoded_o.rd4       = {instr_i[7], instr_i[2:0]};
        decoded_o.supported = 1'b1;
      end

      16'b01000110????????: begin
        decoded_o.op_class  = THUMB_OP_HI_MOV;
        decoded_o.rd4       = {instr_i[7], instr_i[2:0]};
        decoded_o.supported = 1'b1;
      end

      16'b01000111????????: begin
        decoded_o.op_class  = THUMB_OP_BRANCH_EXCHANGE;
        decoded_o.rd4       = {instr_i[7], instr_i[2:0]};
        decoded_o.supported = 1'b1;
      end

      16'b1101????????????: begin
        decoded_o.op_class  = (instr_i[11:8] < 4'hE) ? THUMB_OP_COND_BRANCH :
                                                         THUMB_OP_UNDEFINED;
        decoded_o.supported = instr_i[11:8] < 4'hE;
      end

      16'b11100???????????: begin
        decoded_o.op_class  = THUMB_OP_BRANCH;
        decoded_o.supported = 1'b1;
      end

      default: begin
        decoded_o.op_class  = THUMB_OP_UNDEFINED;
        decoded_o.supported = 1'b0;
      end
    endcase
  end
endmodule
