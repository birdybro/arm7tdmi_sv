`timescale 1ns/1ps

module arm7tdmi_arm_decode
  import arm7tdmi_pkg::*;
(
  input  logic [31:0]  instr_i,
  output arm_decoded_t decoded_o
);
  logic is_bx;
  logic is_multiply;
  logic is_long_multiply;
  logic is_swap;
  logic is_halfword_transfer;
  logic is_psr_transfer;

  always_comb begin
    is_bx = instr_i[27:4] == 24'h012FFF1;
    is_multiply = (instr_i[27:22] == 6'b000000) && (instr_i[7:4] == 4'b1001);
    is_long_multiply = (instr_i[27:23] == 5'b00001) && (instr_i[7:4] == 4'b1001);
    is_swap = (instr_i[27:23] == 5'b00010) && (instr_i[21:20] == 2'b00) && (instr_i[11:4] == 8'b00001001);
    is_halfword_transfer = (instr_i[27:25] == 3'b000) && instr_i[7] && instr_i[4] &&
                           (instr_i[6:5] != 2'b00);
    is_psr_transfer = ((instr_i[27:23] == 5'b00010) && (instr_i[21:20] inside {2'b00, 2'b10}) &&
                       (instr_i[7:4] == 4'b0000)) ||
                      ((instr_i[27:23] == 5'b00110) && (instr_i[21:20] == 2'b10));

    decoded_o = '{
      cond:              arm_cond_t'(instr_i[31:28]),
      op_class:          ARM_OP_UNDEFINED,
      alu_op:            arm_alu_op_t'(instr_i[24:21]),
      rn:                instr_i[19:16],
      rd:                instr_i[15:12],
      rm:                instr_i[3:0],
      rs:                instr_i[11:8],
      set_flags:         instr_i[20],
      immediate_operand: instr_i[25],
      register_shift:    !instr_i[25] && instr_i[4],
      shift_type:        arm_shift_t'(instr_i[6:5]),
      shift_imm:         instr_i[11:7],
      imm8:              instr_i[7:0],
      rotate_imm:        instr_i[11:8],
      branch_link:       instr_i[24],
      branch_imm24:      instr_i[23:0],
      ls_pre_index:      instr_i[24],
      ls_up:             instr_i[23],
      ls_byte:           instr_i[22],
      ls_writeback:      instr_i[21],
      ls_load:           instr_i[20],
      ls_offset12:       instr_i[11:0],
      block_reglist:     instr_i[15:0],
      mul_accumulate:    instr_i[21],
      mul_long_signed:   instr_i[22],
      hword_transfer_type: instr_i[6:5],
      hword_offset8:     {instr_i[11:8], instr_i[3:0]},
      psr_write:         instr_i[21],
      psr_use_spsr:      instr_i[22],
      psr_field_mask:    instr_i[19:16],
      supported:         1'b0
    };

    unique casez (instr_i[27:25])
      3'b000, 3'b001: begin
        if (is_bx) begin
          decoded_o.op_class = ARM_OP_BRANCH_EXCHANGE;
          decoded_o.supported = 1'b1;
        end else if (is_long_multiply) begin
          decoded_o.op_class = ARM_OP_LONG_MULTIPLY;
          decoded_o.rd = instr_i[15:12];
          decoded_o.rn = instr_i[19:16];
          decoded_o.supported = !instr_i[21] && (instr_i[19:16] != instr_i[15:12]) &&
                                (instr_i[19:16] != 4'd15) && (instr_i[15:12] != 4'd15);
        end else if (is_multiply) begin
          decoded_o.op_class = ARM_OP_MULTIPLY;
          decoded_o.rd = instr_i[19:16];
          decoded_o.rn = instr_i[15:12];
          decoded_o.supported = 1'b1;
        end else if (is_swap) begin
          decoded_o.op_class = ARM_OP_SWAP;
          decoded_o.supported = (instr_i[19:16] != 4'd15) && (instr_i[15:12] != 4'd15) &&
                                (instr_i[3:0] != 4'd15);
        end else if (is_halfword_transfer) begin
          decoded_o.op_class = ARM_OP_HALFWORD_TRANSFER;
          decoded_o.register_shift = 1'b0;
          decoded_o.supported = instr_i[22] && instr_i[24] && !instr_i[21] &&
                                ((instr_i[6:5] == 2'b01) || instr_i[20]) &&
                                (instr_i[19:16] != 4'd15) && (instr_i[15:12] != 4'd15);
        end else if (is_psr_transfer) begin
          decoded_o.op_class = ARM_OP_PSR_TRANSFER;
          if (instr_i[21]) begin
            decoded_o.supported = !instr_i[22] && (instr_i[19:16] == 4'b1000) &&
                                  (instr_i[15:12] == 4'hF) &&
                                  (instr_i[25] || ((instr_i[11:4] == 8'h00) &&
                                                   (instr_i[3:0] != 4'd15)));
          end else begin
            decoded_o.supported = (instr_i[19:16] == 4'hF) &&
                                  (instr_i[11:0] == 12'h000) && (instr_i[15:12] != 4'd15);
          end
        end else if (!(instr_i[7:4] == 4'b1001)) begin
          decoded_o.op_class = ARM_OP_DATA_PROCESSING;
          decoded_o.supported = 1'b1;
        end
      end

      3'b010, 3'b011: begin
        decoded_o.op_class = ARM_OP_SINGLE_DATA_TRANSFER;
        decoded_o.supported = (!instr_i[25] || !instr_i[4]) && (instr_i[24] || !instr_i[21]) &&
                              (!instr_i[20] || (instr_i[19:16] != instr_i[15:12])) &&
                              (instr_i[19:16] != 4'd15) && (instr_i[15:12] != 4'd15);
      end

      3'b100: begin
        decoded_o.op_class = ARM_OP_BLOCK_DATA_TRANSFER;
        decoded_o.supported = !instr_i[22] && (instr_i[19:16] != 4'd15) &&
                              (instr_i[15:0] != 16'h0000) &&
                              !instr_i[15] && (!instr_i[21] || !instr_i[{1'b0, instr_i[19:16]}]);
      end

      3'b101: begin
        decoded_o.op_class = ARM_OP_BRANCH;
        decoded_o.supported = 1'b1;
      end

      3'b110: begin
        decoded_o.op_class = ARM_OP_COPROCESSOR;
      end

      3'b111: begin
        decoded_o.op_class = instr_i[24] ? ARM_OP_SWI : ARM_OP_COPROCESSOR;
      end

      default: begin
        decoded_o.op_class = ARM_OP_UNDEFINED;
      end
    endcase
  end
endmodule
