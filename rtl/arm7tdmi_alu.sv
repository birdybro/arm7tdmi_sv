`timescale 1ns/1ps

module arm7tdmi_alu
  import arm7tdmi_pkg::*;
(
  input  arm_alu_op_t op_i,
  input  logic [31:0] a_i,
  input  logic [31:0] b_i,
  input  arm_flags_t  flags_i,
  input  logic        shifter_carry_i,
  output logic [31:0] result_o,
  output arm_flags_t  flags_o,
  output logic        write_result_o,
  output logic        arithmetic_o
);
  logic [32:0] add_result;
  logic [32:0] sub_result;
  logic        overflow;

  always_comb begin
    result_o       = 32'h0000_0000;
    flags_o        = flags_i;
    write_result_o = 1'b1;
    arithmetic_o   = 1'b0;
    add_result     = 33'h0;
    sub_result     = 33'h0;
    overflow       = 1'b0;

    unique case (op_i)
      ALU_AND, ALU_TST: begin
        result_o       = a_i & b_i;
        flags_o.c      = shifter_carry_i;
        write_result_o = (op_i == ALU_AND);
      end
      ALU_EOR, ALU_TEQ: begin
        result_o       = a_i ^ b_i;
        flags_o.c      = shifter_carry_i;
        write_result_o = (op_i == ALU_EOR);
      end
      ALU_SUB, ALU_CMP: begin
        sub_result     = {1'b0, a_i} - {1'b0, b_i};
        result_o       = sub_result[31:0];
        flags_o.c      = !sub_result[32];
        overflow       = (a_i[31] != b_i[31]) && (result_o[31] != a_i[31]);
        flags_o.v      = overflow;
        write_result_o = (op_i == ALU_SUB);
        arithmetic_o   = 1'b1;
      end
      ALU_RSB: begin
        sub_result   = {1'b0, b_i} - {1'b0, a_i};
        result_o     = sub_result[31:0];
        flags_o.c    = !sub_result[32];
        flags_o.v    = (b_i[31] != a_i[31]) && (result_o[31] != b_i[31]);
        arithmetic_o = 1'b1;
      end
      ALU_ADD, ALU_CMN: begin
        add_result     = {1'b0, a_i} + {1'b0, b_i};
        result_o       = add_result[31:0];
        flags_o.c      = add_result[32];
        flags_o.v      = (a_i[31] == b_i[31]) && (result_o[31] != a_i[31]);
        write_result_o = (op_i == ALU_ADD);
        arithmetic_o   = 1'b1;
      end
      ALU_ADC: begin
        add_result   = {1'b0, a_i} + {1'b0, b_i} + {32'h0, flags_i.c};
        result_o     = add_result[31:0];
        flags_o.c    = add_result[32];
        flags_o.v    = (a_i[31] == b_i[31]) && (result_o[31] != a_i[31]);
        arithmetic_o = 1'b1;
      end
      ALU_SBC: begin
        sub_result   = {1'b0, a_i} - {1'b0, b_i} - {32'h0, !flags_i.c};
        result_o     = sub_result[31:0];
        flags_o.c    = !sub_result[32];
        flags_o.v    = (a_i[31] != b_i[31]) && (result_o[31] != a_i[31]);
        arithmetic_o = 1'b1;
      end
      ALU_RSC: begin
        sub_result   = {1'b0, b_i} - {1'b0, a_i} - {32'h0, !flags_i.c};
        result_o     = sub_result[31:0];
        flags_o.c    = !sub_result[32];
        flags_o.v    = (b_i[31] != a_i[31]) && (result_o[31] != b_i[31]);
        arithmetic_o = 1'b1;
      end
      ALU_ORR: begin
        result_o  = a_i | b_i;
        flags_o.c = shifter_carry_i;
      end
      ALU_MOV: begin
        result_o  = b_i;
        flags_o.c = shifter_carry_i;
      end
      ALU_BIC: begin
        result_o  = a_i & ~b_i;
        flags_o.c = shifter_carry_i;
      end
      ALU_MVN: begin
        result_o  = ~b_i;
        flags_o.c = shifter_carry_i;
      end
      default: begin
        result_o       = 32'h0000_0000;
        write_result_o = 1'b0;
      end
    endcase

    flags_o.n = result_o[31];
    flags_o.z = (result_o == 32'h0000_0000);
  end
endmodule
