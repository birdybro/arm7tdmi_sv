`timescale 1ns/1ps

module tb_arm7tdmi_alu
  import arm7tdmi_pkg::*;
;
  arm_alu_op_t op;
  logic [31:0] a;
  logic [31:0] b;
  arm_flags_t  flags_in;
  logic        shifter_carry;
  logic [31:0] result;
  arm_flags_t  flags_out;
  logic        write_result;
  logic        arithmetic;

  arm7tdmi_alu dut (
    .op_i(op),
    .a_i(a),
    .b_i(b),
    .flags_i(flags_in),
    .shifter_carry_i(shifter_carry),
    .result_o(result),
    .flags_o(flags_out),
    .write_result_o(write_result),
    .arithmetic_o(arithmetic)
  );

  task automatic check(
      input arm_alu_op_t op_t,
      input logic [31:0] a_t,
      input logic [31:0] b_t,
      input arm_flags_t  flags_t,
      input logic        shifter_carry_t,
      input logic [31:0] expected_result,
      input arm_flags_t  expected_flags,
      input logic        expected_write,
      input logic        expected_arithmetic
  );
    op = op_t;
    a = a_t;
    b = b_t;
    flags_in = flags_t;
    shifter_carry = shifter_carry_t;
    #1;
    if (result !== expected_result ||
        flags_out !== expected_flags ||
        write_result !== expected_write ||
        arithmetic !== expected_arithmetic) begin
      $fatal(1, "op=%0h a=%08x b=%08x expected result=%08x flags=%04b wr=%0b arith=%0b got result=%08x flags=%04b wr=%0b arith=%0b",
             op_t, a_t, b_t, expected_result, expected_flags, expected_write,
             expected_arithmetic, result, flags_out, write_result, arithmetic);
    end
  endtask

  initial begin
    static arm_flags_t f_clear = '{n: 1'b0, z: 1'b0, c: 1'b0, v: 1'b0};
    static arm_flags_t f_carry = '{n: 1'b0, z: 1'b0, c: 1'b1, v: 1'b0};

    check(ALU_AND, 32'hF0F0_0000, 32'h0FF0_0000, f_clear, 1'b1,
          32'h00F0_0000, '{n: 1'b0, z: 1'b0, c: 1'b1, v: 1'b0}, 1'b1, 1'b0);
    check(ALU_EOR, 32'hFFFF_0000, 32'h0F0F_0000, f_clear, 1'b0,
          32'hF0F0_0000, '{n: 1'b1, z: 1'b0, c: 1'b0, v: 1'b0}, 1'b1, 1'b0);
    check(ALU_TST, 32'h0000_0001, 32'h0000_0002, f_carry, 1'b0,
          32'h0000_0000, '{n: 1'b0, z: 1'b1, c: 1'b0, v: 1'b0}, 1'b0, 1'b0);
    check(ALU_MOV, 32'hDEAD_BEEF, 32'h8000_0000, f_clear, 1'b1,
          32'h8000_0000, '{n: 1'b1, z: 1'b0, c: 1'b1, v: 1'b0}, 1'b1, 1'b0);
    check(ALU_MVN, 32'h0000_0000, 32'hFFFF_FFFF, f_clear, 1'b0,
          32'h0000_0000, '{n: 1'b0, z: 1'b1, c: 1'b0, v: 1'b0}, 1'b1, 1'b0);

    check(ALU_ADD, 32'hFFFF_FFFF, 32'h0000_0001, f_clear, 1'b0,
          32'h0000_0000, '{n: 1'b0, z: 1'b1, c: 1'b1, v: 1'b0}, 1'b1, 1'b1);
    check(ALU_ADD, 32'h7FFF_FFFF, 32'h0000_0001, f_clear, 1'b0,
          32'h8000_0000, '{n: 1'b1, z: 1'b0, c: 1'b0, v: 1'b1}, 1'b1, 1'b1);
    check(ALU_ADC, 32'h0000_0001, 32'h0000_0001, f_carry, 1'b0,
          32'h0000_0003, '{n: 1'b0, z: 1'b0, c: 1'b0, v: 1'b0}, 1'b1, 1'b1);
    check(ALU_SUB, 32'h0000_0000, 32'h0000_0001, f_clear, 1'b0,
          32'hFFFF_FFFF, '{n: 1'b1, z: 1'b0, c: 1'b0, v: 1'b0}, 1'b1, 1'b1);
    check(ALU_SUB, 32'h0000_0005, 32'h0000_0003, f_clear, 1'b0,
          32'h0000_0002, '{n: 1'b0, z: 1'b0, c: 1'b1, v: 1'b0}, 1'b1, 1'b1);
    check(ALU_RSB, 32'h0000_0003, 32'h0000_0005, f_clear, 1'b0,
          32'h0000_0002, '{n: 1'b0, z: 1'b0, c: 1'b1, v: 1'b0}, 1'b1, 1'b1);
    check(ALU_SBC, 32'h0000_0005, 32'h0000_0003, f_carry, 1'b0,
          32'h0000_0002, '{n: 1'b0, z: 1'b0, c: 1'b1, v: 1'b0}, 1'b1, 1'b1);
    check(ALU_SBC, 32'h0000_0005, 32'h0000_0003, f_clear, 1'b0,
          32'h0000_0001, '{n: 1'b0, z: 1'b0, c: 1'b1, v: 1'b0}, 1'b1, 1'b1);
    check(ALU_CMP, 32'h8000_0000, 32'h0000_0001, f_clear, 1'b0,
          32'h7FFF_FFFF, '{n: 1'b0, z: 1'b0, c: 1'b1, v: 1'b1}, 1'b0, 1'b1);
    check(ALU_CMN, 32'hFFFF_FFFF, 32'h0000_0001, f_clear, 1'b0,
          32'h0000_0000, '{n: 1'b0, z: 1'b1, c: 1'b1, v: 1'b0}, 1'b0, 1'b1);

    $display("tb_arm7tdmi_alu passed");
    $finish;
  end
endmodule
