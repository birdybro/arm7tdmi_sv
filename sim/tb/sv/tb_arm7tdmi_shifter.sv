`timescale 1ns/1ps

module tb_arm7tdmi_shifter
  import arm7tdmi_pkg::*;
;
  logic [31:0] value;
  arm_shift_t  shift;
  logic [7:0]  amount;
  logic        carry_in;
  logic [31:0] result;
  logic        carry_out;

  arm7tdmi_shifter dut (
    .value_i(value),
    .shift_i(shift),
    .amount_i(amount),
    .carry_i(carry_in),
    .result_o(result),
    .carry_o(carry_out)
  );

  task automatic check(
      input logic [31:0] value_t,
      input arm_shift_t  shift_t,
      input logic [7:0]  amount_t,
      input logic        carry_t,
      input logic [31:0] expected_result,
      input logic        expected_carry
  );
    value = value_t;
    shift = shift_t;
    amount = amount_t;
    carry_in = carry_t;
    #1;
    if (result !== expected_result || carry_out !== expected_carry) begin
      $fatal(1, "shift=%0d value=%08x amount=%0d carry=%0b expected %08x/%0b got %08x/%0b",
             shift_t, value_t, amount_t, carry_t, expected_result, expected_carry, result, carry_out);
    end
  endtask

  initial begin
    check(32'h8000_0001, SHIFT_LSL, 8'd0, 1'b1, 32'h8000_0001, 1'b1);
    check(32'h8000_0001, SHIFT_LSL, 8'd1, 1'b0, 32'h0000_0002, 1'b1);
    check(32'h8000_0001, SHIFT_LSL, 8'd31, 1'b0, 32'h8000_0000, 1'b0);
    check(32'h8000_0001, SHIFT_LSL, 8'd32, 1'b0, 32'h0000_0000, 1'b1);
    check(32'h8000_0001, SHIFT_LSL, 8'd33, 1'b1, 32'h0000_0000, 1'b0);

    check(32'h8000_0001, SHIFT_LSR, 8'd0, 1'b0, 32'h0000_0000, 1'b1);
    check(32'h8000_0001, SHIFT_LSR, 8'd1, 1'b0, 32'h4000_0000, 1'b1);
    check(32'h8000_0001, SHIFT_LSR, 8'd31, 1'b0, 32'h0000_0001, 1'b0);
    check(32'h8000_0001, SHIFT_LSR, 8'd32, 1'b0, 32'h0000_0000, 1'b1);
    check(32'h8000_0001, SHIFT_LSR, 8'd33, 1'b0, 32'h0000_0000, 1'b0);

    check(32'h8000_0001, SHIFT_ASR, 8'd0, 1'b0, 32'hFFFF_FFFF, 1'b1);
    check(32'h8000_0001, SHIFT_ASR, 8'd1, 1'b0, 32'hC000_0000, 1'b1);
    check(32'h8000_0001, SHIFT_ASR, 8'd31, 1'b0, 32'hFFFF_FFFF, 1'b0);
    check(32'h7FFF_FFFF, SHIFT_ASR, 8'd32, 1'b0, 32'h0000_0000, 1'b0);

    check(32'h8000_0001, SHIFT_ROR, 8'd0, 1'b0, 32'h4000_0000, 1'b1);
    check(32'h8000_0001, SHIFT_ROR, 8'd0, 1'b1, 32'hC000_0000, 1'b1);
    check(32'h8000_0001, SHIFT_ROR, 8'd1, 1'b0, 32'hC000_0000, 1'b1);
    check(32'h8000_0001, SHIFT_ROR, 8'd4, 1'b0, 32'h1800_0000, 1'b0);
    check(32'h8000_0001, SHIFT_ROR, 8'd32, 1'b0, 32'h8000_0001, 1'b1);

    $display("tb_arm7tdmi_shifter passed");
    $finish;
  end
endmodule
