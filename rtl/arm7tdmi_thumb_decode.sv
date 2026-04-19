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
      rd:            instr_i[10:8],
      rm:            {instr_i[6], instr_i[5:3]},
      imm8:          instr_i[7:0],
      branch_imm11:  instr_i[10:0],
      supported:     1'b0
    };

    unique casez (instr_i)
      16'b00100???????????: begin
        decoded_o.op_class  = THUMB_OP_MOV_IMM;
        decoded_o.supported = 1'b1;
      end

      16'b00101???????????: begin
        decoded_o.op_class  = THUMB_OP_CMP_IMM;
        decoded_o.supported = 1'b1;
      end

      16'b00110???????????: begin
        decoded_o.op_class  = THUMB_OP_ADD_IMM;
        decoded_o.supported = 1'b1;
      end

      16'b00111???????????: begin
        decoded_o.op_class  = THUMB_OP_SUB_IMM;
        decoded_o.supported = 1'b1;
      end

      16'b01000111????????: begin
        decoded_o.op_class  = THUMB_OP_BRANCH_EXCHANGE;
        decoded_o.supported = 1'b1;
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
