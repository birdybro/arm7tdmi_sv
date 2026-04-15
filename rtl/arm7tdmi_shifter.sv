`timescale 1ns/1ps

module arm7tdmi_shifter
  import arm7tdmi_pkg::*;
(
  input  logic [31:0] value_i,
  input  arm_shift_t  shift_i,
  input  logic [7:0]  amount_i,
  input  logic        register_shift_i,
  input  logic        carry_i,
  output logic [31:0] result_o,
  output logic        carry_o
);
  always_comb begin
    result_o = value_i;
    carry_o  = carry_i;

    unique case (shift_i)
      SHIFT_LSL: begin
        if (amount_i == 8'd0) begin
          result_o = value_i;
          carry_o  = carry_i;
        end else if (amount_i < 8'd32) begin
          result_o = value_i << amount_i[4:0];
          carry_o  = value_i[32 - amount_i[4:0]];
        end else if (amount_i == 8'd32) begin
          result_o = 32'h0000_0000;
          carry_o  = value_i[0];
        end else begin
          result_o = 32'h0000_0000;
          carry_o  = 1'b0;
        end
      end
      SHIFT_LSR: begin
        if (amount_i == 8'd0 && register_shift_i) begin
          result_o = value_i;
          carry_o  = carry_i;
        end else if (amount_i == 8'd0 || amount_i == 8'd32) begin
          result_o = 32'h0000_0000;
          carry_o  = value_i[31];
        end else if (amount_i < 8'd32) begin
          result_o = value_i >> amount_i[4:0];
          carry_o  = value_i[amount_i[4:0] - 5'd1];
        end else begin
          result_o = 32'h0000_0000;
          carry_o  = 1'b0;
        end
      end
      SHIFT_ASR: begin
        if (amount_i == 8'd0 && register_shift_i) begin
          result_o = value_i;
          carry_o  = carry_i;
        end else if (amount_i == 8'd0 || amount_i >= 8'd32) begin
          result_o = value_i[31] ? 32'hFFFF_FFFF : 32'h0000_0000;
          carry_o  = value_i[31];
        end else begin
          result_o = $signed(value_i) >>> amount_i[4:0];
          carry_o  = value_i[amount_i[4:0] - 5'd1];
        end
      end
      SHIFT_ROR: begin
        if (amount_i == 8'd0 && register_shift_i) begin
          result_o = value_i;
          carry_o  = carry_i;
        end else if (amount_i == 8'd0) begin
          result_o = {carry_i, value_i[31:1]};
          carry_o  = value_i[0];
        end else if (amount_i[4:0] == 5'd0) begin
          result_o = value_i;
          carry_o  = value_i[31];
        end else begin
          result_o = (value_i >> amount_i[4:0]) | (value_i << (6'd32 - {1'b0, amount_i[4:0]}));
          carry_o  = result_o[31];
        end
      end
      default: begin
        result_o = value_i;
        carry_o  = carry_i;
      end
    endcase
  end
endmodule
