`timescale 1ns/1ps

module arm7tdmi_core
  import arm7tdmi_pkg::*;
(
  input  logic           clk_i,
  input  logic           rst_ni,

  output logic [31:0]    bus_addr_o,
  output logic           bus_valid_o,
  output logic           bus_write_o,
  output arm_bus_size_t  bus_size_o,
  output arm_bus_cycle_t bus_cycle_o,
  output logic [31:0]    bus_wdata_o,
  input  logic [31:0]    bus_rdata_i,
  input  logic           bus_ready_i,
  input  logic           bus_abort_i = 1'b0,

  input  logic           irq_i,
  input  logic           fiq_i,

  output logic [31:0]    debug_pc_o,
  output logic [31:0]    debug_cpsr_o,
  output logic           debug_reg_we_o,
  output logic [3:0]     debug_reg_waddr_o,
  output logic [31:0]    debug_reg_wdata_o,
  output logic           retired_o,
  output logic           unsupported_o
);
  typedef enum logic [3:0] {
    ST_RESET,
    ST_FETCH,
    ST_EXECUTE,
    ST_MEM,
    ST_MEM_WB,
    ST_MUL64_HI,
    ST_SWAP_WRITE,
    ST_SWAP_WB,
    ST_BLOCK_MEM,
    ST_BLOCK_WB,
    ST_BLOCK_PC_WB,
    ST_EXCEPTION_SAVE
  } state_t;

  state_t state_q;
  logic [31:0] pc_q;
  logic [31:0] instr_q;
  logic        next_fetch_seq_q;
  logic [31:0] mem_addr_q;
  logic        mem_write_q;
  logic        mem_load_q;
  logic        mem_byte_q;
  logic        mem_half_q;
  logic        mem_signed_q;
  logic        mem_swap_q;
  logic        mem_thumb_q;
  logic        mem_wb_q;
  logic [3:0]  mem_rn_q;
  logic [3:0]  mem_rd_q;
  logic [31:0] mem_wdata_q;
  logic [31:0] mem_wbdata_q;
  logic [15:0] block_reglist_q;
  logic [3:0]  block_reg_q;
  logic        block_load_q;
  logic        block_wb_q;
  logic        block_restore_cpsr_q;
  logic        block_user_bank_q;
  logic        block_thumb_q;
  logic [3:0]  block_rn_q;
  logic [31:0] block_wbdata_q;
  logic [31:0] block_pc_wdata_q;
  logic [31:0] exception_lr_q;
  logic [31:0] exception_spsr_q;
  logic [3:0]  mul64_hi_waddr_q;
  logic [31:0] mul64_hi_wdata_q;

  logic [3:0] rn;
  logic [3:0] rd;
  logic [3:0] rm;
  logic [3:0] thumb_raddr_a;
  logic [3:0] thumb_raddr_b;
  logic [3:0] thumb_waddr;
  logic [3:0] raddr_c;
  logic [3:0] raddr_d;
  arm_decoded_t decoded;
  thumb_decoded_t thumb_decoded;
  logic [31:0] rn_data;
  logic [31:0] rm_data;
  logic [31:0] rs_data;
  logic [31:0] rd_data;
  logic [31:0] cpsr;
  logic [31:0] spsr;
  arm_flags_t flags;
  arm_mode_t  mode;

  logic       reg_we;
  logic [3:0] reg_waddr;
  logic [31:0] reg_wdata;
  logic       reg_write_user;
  logic       reg_raddr_c_user;
  logic       cpsr_we;
  logic [31:0] cpsr_wdata;
  logic       spsr_we;
  logic [31:0] spsr_wdata;

  logic       cond_pass;
  logic       thumb_cond_pass;
  logic       execute_cond_pass;
  arm_alu_op_t alu_op;
  logic [31:0] alu_b;
  logic [31:0] shift_value;
  logic        shifter_carry;
  logic [31:0] shifted_rm;
  logic        shifted_rm_carry;
  logic [7:0]  shift_amount;
  logic        shift_register;
  logic [7:0]  rs_shift_amount;
  logic        unused_rs_upper;
  logic        unused_ls_modes;
  logic        unused_hword_modes;
  logic        unused_psr_modes;
  arm_shift_t  shift_type;
  logic [31:0] alu_result;
  arm_flags_t  alu_flags;
  logic        alu_write_result;
  logic        alu_arithmetic;
  logic [31:0] mul_result;
  logic [63:0] mul64_product;
  logic [63:0] mul64_accumulator;
  logic [63:0] mul64_result;
  arm_flags_t  mul_flags;

  logic        supported_execute;
  logic        thumb_state;
  logic [31:0] next_pc;
  logic [31:0] bx_cpsr;
  logic [31:0] thumb_imm32;
  logic [31:0] thumb_op2;
  logic [31:0] thumb_alu_result;
  logic [31:0] thumb_pc_load_addr;
  logic [31:0] thumb_ls_imm_offset;
  logic [31:0] thumb_ls_addr;
  logic [31:0] thumb_ls_reg_addr;
  logic [31:0] thumb_ls_sp_addr;
  logic [31:0] thumb_add_addr_result;
  logic [31:0] thumb_sp_adjust_offset;
  logic [31:0] thumb_sp_adjust_result;
  logic [32:0] thumb_add_wide;
  logic [32:0] thumb_sub_wide;
  logic [32:0] thumb_adc_wide;
  logic [32:0] thumb_sbc_wide;
  logic [32:0] thumb_neg_wide;
  logic [31:0] thumb_mul_result;
  logic        thumb_alu_reg_write;
  arm_flags_t  thumb_flags;
  logic [31:0] thumb_next_pc;
  logic [31:0] thumb_bx_cpsr;
  logic [31:0] psr_write_value;
  logic [31:0] ls_offset;
  logic [31:0] ls_addr;
  logic [31:0] ls_transfer_addr;
  logic [31:0] hword_offset;
  logic [31:0] hword_addr;
  logic [31:0] hword_transfer_addr;
  logic [15:0] block_next_reglist;
  logic [3:0]  block_next_reg;
  logic        block_last_reg;
  logic [15:0] block_effective_reglist;
  logic [4:0]  block_reg_count;
  logic [31:0] block_byte_count;
  logic [31:0] block_down_offset;
  logic [31:0] block_start_addr;
  logic [31:0] block_store_data;
  logic [15:0] thumb_block_reglist;
  logic [4:0]  thumb_block_reg_count;
  logic [31:0] thumb_block_byte_count;
  logic [15:0] thumb_stack_reglist;
  logic [4:0]  thumb_stack_reg_count;
  logic [31:0] thumb_stack_byte_count;
  logic [31:0] block_pc_load_addr;

  function automatic logic [3:0] first_reg_in_list(input logic [15:0] reglist);
    first_reg_in_list = 4'd0;
    for (int idx = 15; idx >= 0; idx--) begin
      if (reglist[idx]) begin
        first_reg_in_list = idx[3:0];
      end
    end
  endfunction

  function automatic logic [4:0] reglist_count(input logic [15:0] reglist);
    reglist_count = 5'd0;
    for (int idx = 0; idx < 16; idx++) begin
      reglist_count = reglist_count + {4'b0000, reglist[idx]};
    end
  endfunction

  function automatic logic [31:0] rotate_word_load(input logic [31:0] data,
                                                   input logic [1:0] byte_offset);
    unique case (byte_offset)
      2'b00: rotate_word_load = data;
      2'b01: rotate_word_load = {data[7:0], data[31:8]};
      2'b10: rotate_word_load = {data[15:0], data[31:16]};
      2'b11: rotate_word_load = {data[23:0], data[31:24]};
      default: rotate_word_load = data;
    endcase
  endfunction

  assign thumb_state = cpsr[5];
  assign rn = thumb_state ? thumb_raddr_a : decoded.rn;
  assign rd = thumb_state ? thumb_waddr : decoded.rd;
  assign rm = thumb_state ? thumb_raddr_b : decoded.rm;

  assign flags = cpsr_flags(cpsr);
  assign mode  = arm_mode_t'(cpsr[4:0]);
  assign rs_shift_amount = rs_data[7:0];
  assign unused_rs_upper = ^rs_data[31:8];
  assign unused_ls_modes = decoded.ls_pre_index ^ decoded.ls_byte ^ decoded.ls_writeback;
  assign unused_hword_modes = ^decoded.hword_transfer_type;
  assign unused_psr_modes = ^decoded.psr_field_mask;
  assign block_next_reglist = block_reglist_q & ~(16'h0001 << block_reg_q);
  assign block_next_reg = first_reg_in_list(block_next_reglist);
  assign block_last_reg = block_next_reglist == 16'h0000;
  assign block_effective_reglist = (decoded.block_reglist == 16'h0000) ? 16'h8000 :
                                                                         decoded.block_reglist;
  assign block_reg_count = (decoded.block_reglist == 16'h0000) ? 5'd16 :
                                                              reglist_count(decoded.block_reglist);
  assign block_byte_count = {25'h0, block_reg_count, 2'b00};
  assign block_down_offset = {25'h0, block_reg_count - 5'd1, 2'b00};
  assign block_start_addr = (decoded.block_reglist == 16'h0000) ?
                            (decoded.ls_up ? (rn_data + (decoded.ls_pre_index ? 32'd4 : 32'd0)) :
                                             (rn_data - (decoded.ls_pre_index ? 32'd64 : 32'd60))) :
                            (decoded.ls_up ? (rn_data + (decoded.ls_pre_index ? 32'd4 : 32'd0)) :
                                             (rn_data - (decoded.ls_pre_index ? block_byte_count :
                                                                           block_down_offset)));
  assign block_store_data = (block_reg_q == 4'd15) ? (pc_q + 32'd12) : rs_data;
  assign thumb_block_reglist = {8'h00, thumb_decoded.imm8};
  assign thumb_block_reg_count = reglist_count(thumb_block_reglist);
  assign thumb_block_byte_count = {25'h0, thumb_block_reg_count, 2'b00};
  assign thumb_stack_reglist = thumb_decoded.ls_load ?
                               {thumb_decoded.stack_extra, 7'h00, thumb_decoded.imm8} :
                               {1'b0, thumb_decoded.stack_extra, 6'h00, thumb_decoded.imm8};
  assign thumb_stack_reg_count = reglist_count(thumb_stack_reglist);
  assign thumb_stack_byte_count = {25'h0, thumb_stack_reg_count, 2'b00};
  assign block_pc_load_addr = block_thumb_q ? (bus_rdata_i & 32'hFFFF_FFFE) :
                                              (bus_rdata_i & 32'hFFFF_FFFC);
  assign raddr_c = (state_q == ST_BLOCK_MEM) ? block_reg_q :
                   ((decoded.register_shift || (decoded.op_class == ARM_OP_MULTIPLY) ||
                     (decoded.op_class == ARM_OP_LONG_MULTIPLY)) ? decoded.rs : rd);
  assign raddr_d = rd;
  assign reg_raddr_c_user = (state_q == ST_BLOCK_MEM) && block_user_bank_q;

  arm7tdmi_regfile u_regfile (
    .clk_i,
    .rst_ni,
    .mode_i(mode),
    .thumb_i(thumb_state),
    .pc_exec_i(pc_q),
    .raddr_a_i(rn),
    .raddr_b_i(rm),
    .raddr_c_i(raddr_c),
    .raddr_c_user_i(reg_raddr_c_user),
    .raddr_d_i(raddr_d),
    .rdata_a_o(rn_data),
    .rdata_b_o(rm_data),
    .rdata_c_o(rs_data),
    .rdata_d_o(rd_data),
    .we_i(reg_we),
    .waddr_i(reg_waddr),
    .wdata_i(reg_wdata),
    .wuser_i(reg_write_user),
    .cpsr_we_i(cpsr_we),
    .cpsr_wdata_i(cpsr_wdata),
    .cpsr_o(cpsr),
    .spsr_we_i(spsr_we),
    .spsr_wdata_i(spsr_wdata),
    .spsr_o(spsr)
  );

  arm7tdmi_arm_decode u_arm_decode (
    .instr_i(instr_q),
    .decoded_o(decoded)
  );

  arm7tdmi_thumb_decode u_thumb_decode (
    .instr_i(instr_q[15:0]),
    .decoded_o(thumb_decoded)
  );

  arm7tdmi_cond u_cond (
    .cond_i(decoded.cond),
    .flags_i(flags),
    .pass_o(cond_pass)
  );

  arm7tdmi_cond u_thumb_cond (
    .cond_i(thumb_decoded.cond),
    .flags_i(flags),
    .pass_o(thumb_cond_pass)
  );

  arm7tdmi_shifter u_shifter (
    .value_i(shift_value),
    .shift_i(shift_type),
    .amount_i(shift_amount),
    .register_shift_i(shift_register),
    .carry_i(flags.c),
    .result_o(shifted_rm),
    .carry_o(shifted_rm_carry)
  );

  arm7tdmi_alu u_alu (
    .op_i(alu_op),
    .a_i(rn_data),
    .b_i(alu_b),
    .flags_i(flags),
    .shifter_carry_i(shifter_carry),
    .result_o(alu_result),
    .flags_o(alu_flags),
    .write_result_o(alu_write_result),
    .arithmetic_o(alu_arithmetic)
  );

  always_comb begin
    alu_op                = decoded.alu_op;
    shift_value           = rm_data;
    shift_register        = decoded.register_shift;
    shift_type            = (thumb_state && (thumb_decoded.op_class == THUMB_OP_SHIFT_IMM)) ?
                            thumb_decoded.shift_type : decoded.shift_type;
    shift_amount          = (thumb_state && (thumb_decoded.op_class == THUMB_OP_SHIFT_IMM)) ?
                            {3'b000, thumb_decoded.shift_imm} :
                            (decoded.register_shift ? rs_shift_amount : {3'b000, decoded.shift_imm});
    alu_b                 = shifted_rm;
    shifter_carry         = shifted_rm_carry;
    execute_cond_pass     = thumb_state ? 1'b1 : cond_pass;
    supported_execute     = thumb_state ? thumb_decoded.supported : decoded.supported;
    next_pc               = pc_q + 32'd4;
    bx_cpsr               = cpsr;
    thumb_raddr_a         = thumb_decoded.rd4;
    thumb_raddr_b         = thumb_decoded.rm;
    thumb_waddr           = {1'b0, thumb_decoded.rd};
    thumb_imm32           = {24'h0, thumb_decoded.imm8};
    thumb_op2             = thumb_imm32;
    thumb_add_wide        = {1'b0, rn_data} + {1'b0, thumb_op2};
    thumb_sub_wide        = {1'b0, rn_data} - {1'b0, thumb_op2};
    thumb_adc_wide        = 33'h0;
    thumb_sbc_wide        = 33'h0;
    thumb_neg_wide        = 33'h0;
    thumb_mul_result      = 32'h0000_0000;
    thumb_alu_result      = 32'h0000_0000;
    thumb_pc_load_addr    = ((pc_q + 32'd4) & 32'hFFFF_FFFC) +
                            {22'h0, thumb_decoded.imm8, 2'b00};
    thumb_ls_imm_offset   = thumb_decoded.ls_byte ? {27'h0, thumb_decoded.shift_imm} :
                            (thumb_decoded.ls_half ? {26'h0, thumb_decoded.shift_imm, 1'b0} :
                                                     {25'h0, thumb_decoded.shift_imm, 2'b00});
    thumb_ls_addr         = rn_data + thumb_ls_imm_offset;
    thumb_ls_reg_addr     = rn_data + rm_data;
    thumb_ls_sp_addr      = rn_data + {22'h0, thumb_decoded.imm8, 2'b00};
    thumb_add_addr_result = (thumb_decoded.sp_base ? rn_data : ((pc_q + 32'd4) & 32'hFFFF_FFFC)) +
                            {22'h0, thumb_decoded.imm8, 2'b00};
    thumb_sp_adjust_offset = {23'h0, thumb_decoded.imm8[6:0], 2'b00};
    thumb_sp_adjust_result = thumb_decoded.sp_subtract ? (rn_data - thumb_sp_adjust_offset) :
                                                       (rn_data + thumb_sp_adjust_offset);
    thumb_alu_reg_write   = 1'b0;
    thumb_flags           = flags;
    thumb_next_pc         = pc_q + 32'd2;
    thumb_bx_cpsr         = cpsr;
    ls_offset             = decoded.immediate_operand ? shifted_rm : {20'h0, decoded.ls_offset12};
    ls_addr               = decoded.ls_up ? rn_data + ls_offset : rn_data - ls_offset;
    ls_transfer_addr      = decoded.ls_pre_index ? ls_addr : rn_data;
    hword_offset          = decoded.hword_immediate_offset ? {24'h0, decoded.hword_offset8} : rm_data;
    hword_addr            = decoded.ls_up ? rn_data + hword_offset : rn_data - hword_offset;
    hword_transfer_addr   = decoded.ls_pre_index ? hword_addr : rn_data;
    mul_result            = (rm_data * rs_data) + (decoded.mul_accumulate ? rn_data : 32'h0000_0000);
    mul64_product         = decoded.mul_long_signed ? 64'(signed'(rm_data) * signed'(rs_data)) :
                                                       64'(rm_data) * 64'(rs_data);
    mul64_accumulator     = decoded.mul_accumulate ? {rn_data, rd_data} : 64'h0000_0000_0000_0000;
    mul64_result          = mul64_product + mul64_accumulator;
    mul_flags             = flags;
    mul_flags.n           = (decoded.op_class == ARM_OP_LONG_MULTIPLY) ? mul64_result[63] : mul_result[31];
    mul_flags.z           = (decoded.op_class == ARM_OP_LONG_MULTIPLY) ? (mul64_result == 64'h0) :
                                                                      (mul_result == 32'h0000_0000);

    if (decoded.immediate_operand) begin
      alu_b = (32'({24'h0, decoded.imm8}) >> {decoded.rotate_imm, 1'b0}) |
              (32'({24'h0, decoded.imm8}) << (6'd32 - {1'b0, decoded.rotate_imm, 1'b0}));
      shifter_carry = (decoded.rotate_imm == 4'h0) ? flags.c : alu_b[31];
    end

    psr_write_value = decoded.immediate_operand ? alu_b : rm_data;

    unique case (thumb_decoded.op_class)
      THUMB_OP_ADD_REG, THUMB_OP_SUB_REG: begin
        thumb_raddr_a  = {1'b0, thumb_decoded.rs};
        thumb_raddr_b  = {1'b0, thumb_decoded.rn};
        thumb_op2      = rm_data;
        thumb_add_wide = {1'b0, rn_data} + {1'b0, thumb_op2};
        thumb_sub_wide = {1'b0, rn_data} - {1'b0, thumb_op2};
      end

      THUMB_OP_ADD_IMM3, THUMB_OP_SUB_IMM3: begin
        thumb_raddr_a  = {1'b0, thumb_decoded.rs};
        thumb_op2      = {29'h0, thumb_decoded.imm3};
        thumb_add_wide = {1'b0, rn_data} + {1'b0, thumb_op2};
        thumb_sub_wide = {1'b0, rn_data} - {1'b0, thumb_op2};
      end

      THUMB_OP_HI_ADD, THUMB_OP_HI_CMP, THUMB_OP_HI_MOV: begin
        thumb_raddr_a  = thumb_decoded.rd4;
        thumb_raddr_b  = thumb_decoded.rm;
        thumb_waddr    = thumb_decoded.rd4;
        thumb_op2      = rm_data;
        thumb_add_wide = {1'b0, rn_data} + {1'b0, thumb_op2};
        thumb_sub_wide = {1'b0, rn_data} - {1'b0, thumb_op2};
      end

      THUMB_OP_ALU_REG: begin
        thumb_raddr_a  = {1'b0, thumb_decoded.rd};
        thumb_raddr_b  = {1'b0, thumb_decoded.rs};
        thumb_op2      = rm_data;
        thumb_add_wide = {1'b0, rn_data} + {1'b0, thumb_op2};
        thumb_sub_wide = {1'b0, rn_data} - {1'b0, thumb_op2};
        thumb_adc_wide = {1'b0, rn_data} + {1'b0, thumb_op2} + {32'h0, flags.c};
        thumb_sbc_wide = {1'b0, rn_data} - {1'b0, thumb_op2} - {32'h0, !flags.c};
        thumb_neg_wide = {1'b0, 32'h0000_0000} - {1'b0, thumb_op2};
        thumb_mul_result = rn_data * thumb_op2;
        unique case (thumb_decoded.alu_op)
          THUMB_ALU_LSL: begin
            shift_value    = rn_data;
            shift_type     = SHIFT_LSL;
            shift_amount   = rm_data[7:0];
            shift_register = 1'b1;
          end
          THUMB_ALU_LSR: begin
            shift_value    = rn_data;
            shift_type     = SHIFT_LSR;
            shift_amount   = rm_data[7:0];
            shift_register = 1'b1;
          end
          THUMB_ALU_ASR: begin
            shift_value    = rn_data;
            shift_type     = SHIFT_ASR;
            shift_amount   = rm_data[7:0];
            shift_register = 1'b1;
          end
          THUMB_ALU_ROR: begin
            shift_value    = rn_data;
            shift_type     = SHIFT_ROR;
            shift_amount   = rm_data[7:0];
            shift_register = 1'b1;
          end
          default: begin
          end
        endcase
      end

      THUMB_OP_LS_IMM: begin
        thumb_raddr_a = {1'b0, thumb_decoded.rb};
      end

      THUMB_OP_LS_REG: begin
        thumb_raddr_a = {1'b0, thumb_decoded.rb};
        thumb_raddr_b = thumb_decoded.rm;
      end

      THUMB_OP_LS_SP: begin
        thumb_raddr_a = 4'd13;
      end

      THUMB_OP_ADD_ADDR: begin
        thumb_raddr_a = 4'd13;
      end

      THUMB_OP_SP_ADJUST: begin
        thumb_raddr_a = 4'd13;
      end

      THUMB_OP_STACK: begin
        thumb_raddr_a = 4'd13;
      end

      THUMB_OP_BLOCK_TRANSFER: begin
        thumb_raddr_a = {1'b0, thumb_decoded.rb};
      end

      THUMB_OP_LONG_BRANCH_LINK: begin
        thumb_raddr_a = 4'd14;
      end

      default: begin
      end
    endcase

    unique case (thumb_decoded.op_class)
      THUMB_OP_MOV_IMM: begin
        thumb_alu_result = thumb_imm32;
        thumb_flags.n    = thumb_imm32[31];
        thumb_flags.z    = thumb_imm32 == 32'h0000_0000;
      end

      THUMB_OP_SHIFT_IMM: begin
        thumb_alu_result = shifted_rm;
        thumb_flags.n    = shifted_rm[31];
        thumb_flags.z    = shifted_rm == 32'h0000_0000;
        thumb_flags.c    = shifted_rm_carry;
      end

      THUMB_OP_CMP_IMM, THUMB_OP_SUB_IMM,
      THUMB_OP_SUB_REG, THUMB_OP_SUB_IMM3, THUMB_OP_HI_CMP: begin
        thumb_alu_result = thumb_sub_wide[31:0];
        thumb_flags.n    = thumb_sub_wide[31];
        thumb_flags.z    = thumb_sub_wide[31:0] == 32'h0000_0000;
        thumb_flags.c    = !thumb_sub_wide[32];
        thumb_flags.v    = (rn_data[31] != thumb_op2[31]) &&
                           (thumb_sub_wide[31] != rn_data[31]);
      end

      THUMB_OP_ADD_IMM, THUMB_OP_ADD_REG, THUMB_OP_ADD_IMM3, THUMB_OP_HI_ADD: begin
        thumb_alu_result = thumb_add_wide[31:0];
        thumb_flags.n    = thumb_add_wide[31];
        thumb_flags.z    = thumb_add_wide[31:0] == 32'h0000_0000;
        thumb_flags.c    = thumb_add_wide[32];
        thumb_flags.v    = (rn_data[31] == thumb_op2[31]) &&
                           (thumb_add_wide[31] != rn_data[31]);
      end

      THUMB_OP_HI_MOV: begin
        thumb_alu_result = rm_data;
      end

      THUMB_OP_ADD_ADDR: begin
        thumb_alu_result = thumb_add_addr_result;
      end

      THUMB_OP_SP_ADJUST: begin
        thumb_alu_result = thumb_sp_adjust_result;
      end

      THUMB_OP_ALU_REG: begin
        thumb_alu_reg_write = !((thumb_decoded.alu_op == THUMB_ALU_TST) ||
                                (thumb_decoded.alu_op == THUMB_ALU_CMP) ||
                                (thumb_decoded.alu_op == THUMB_ALU_CMN));

        unique case (thumb_decoded.alu_op)
          THUMB_ALU_AND, THUMB_ALU_TST: begin
            thumb_alu_result = rn_data & thumb_op2;
          end
          THUMB_ALU_EOR: begin
            thumb_alu_result = rn_data ^ thumb_op2;
          end
          THUMB_ALU_LSL, THUMB_ALU_LSR, THUMB_ALU_ASR, THUMB_ALU_ROR: begin
            thumb_alu_result = shifted_rm;
            thumb_flags.c    = shifted_rm_carry;
          end
          THUMB_ALU_ADC: begin
            thumb_alu_result = thumb_adc_wide[31:0];
            thumb_flags.c    = thumb_adc_wide[32];
            thumb_flags.v    = (rn_data[31] == thumb_op2[31]) &&
                               (thumb_adc_wide[31] != rn_data[31]);
          end
          THUMB_ALU_SBC: begin
            thumb_alu_result = thumb_sbc_wide[31:0];
            thumb_flags.c    = !thumb_sbc_wide[32];
            thumb_flags.v    = (rn_data[31] != thumb_op2[31]) &&
                               (thumb_sbc_wide[31] != rn_data[31]);
          end
          THUMB_ALU_NEG: begin
            thumb_alu_result = thumb_neg_wide[31:0];
            thumb_flags.c    = !thumb_neg_wide[32];
            thumb_flags.v    = thumb_op2[31] && thumb_neg_wide[31];
          end
          THUMB_ALU_CMP: begin
            thumb_alu_result = thumb_sub_wide[31:0];
            thumb_flags.c    = !thumb_sub_wide[32];
            thumb_flags.v    = (rn_data[31] != thumb_op2[31]) &&
                               (thumb_sub_wide[31] != rn_data[31]);
          end
          THUMB_ALU_CMN: begin
            thumb_alu_result = thumb_add_wide[31:0];
            thumb_flags.c    = thumb_add_wide[32];
            thumb_flags.v    = (rn_data[31] == thumb_op2[31]) &&
                               (thumb_add_wide[31] != rn_data[31]);
          end
          THUMB_ALU_ORR: begin
            thumb_alu_result = rn_data | thumb_op2;
          end
          THUMB_ALU_MUL: begin
            thumb_alu_result = thumb_mul_result;
          end
          THUMB_ALU_BIC: begin
            thumb_alu_result = rn_data & ~thumb_op2;
          end
          THUMB_ALU_MVN: begin
            thumb_alu_result = ~thumb_op2;
          end
          default: begin
            thumb_alu_result = 32'h0000_0000;
          end
        endcase

        thumb_flags.n = thumb_alu_result[31];
        thumb_flags.z = thumb_alu_result == 32'h0000_0000;
      end

      THUMB_OP_BRANCH: begin
        thumb_next_pc = pc_q + 32'd4 + {{20{thumb_decoded.branch_imm11[10]}},
                                        thumb_decoded.branch_imm11, 1'b0};
      end

      THUMB_OP_COND_BRANCH: begin
        thumb_next_pc = thumb_cond_pass ?
                        (pc_q + 32'd4 + {{23{thumb_decoded.branch_imm8[7]}},
                                          thumb_decoded.branch_imm8, 1'b0}) :
                        (pc_q + 32'd2);
      end

      THUMB_OP_BRANCH_EXCHANGE: begin
        thumb_next_pc    = rm_data[0] ? {rm_data[31:1], 1'b0} : {rm_data[31:2], 2'b00};
        thumb_bx_cpsr[5] = rm_data[0];
      end

      default: begin
      end
    endcase

    if (decoded.op_class == ARM_OP_BRANCH) begin
      next_pc = pc_q + 32'd8 + {{6{decoded.branch_imm24[23]}}, decoded.branch_imm24, 2'b00};
    end

    if (decoded.op_class == ARM_OP_BRANCH_EXCHANGE) begin
      next_pc    = rm_data[0] ? {rm_data[31:1], 1'b0} : {rm_data[31:2], 2'b00};
      bx_cpsr[5] = rm_data[0];
    end
  end

  assign bus_addr_o  = ((state_q == ST_MEM) || (state_q == ST_SWAP_WRITE) ||
                        (state_q == ST_BLOCK_MEM)) ? mem_addr_q : pc_q;
  assign bus_valid_o = (state_q == ST_FETCH) || (state_q == ST_MEM) || (state_q == ST_SWAP_WRITE) ||
                       (state_q == ST_BLOCK_MEM);
  assign bus_write_o = ((state_q == ST_MEM) && mem_write_q) || (state_q == ST_SWAP_WRITE) ||
                       ((state_q == ST_BLOCK_MEM) && !block_load_q);
  assign bus_size_o  = (((state_q == ST_MEM) || (state_q == ST_SWAP_WRITE)) && mem_byte_q) ? BUS_SIZE_BYTE :
                       ((((state_q == ST_MEM) || (state_q == ST_SWAP_WRITE)) && mem_half_q) ? BUS_SIZE_HALF :
                        (((state_q == ST_FETCH) && thumb_state) ? BUS_SIZE_HALF : BUS_SIZE_WORD));
  assign bus_cycle_o = ((state_q == ST_MEM) || (state_q == ST_SWAP_WRITE) ||
                        (state_q == ST_BLOCK_MEM)) ? BUS_CYCLE_NONSEQ :
                                                    (next_fetch_seq_q ? BUS_CYCLE_SEQ : BUS_CYCLE_NONSEQ);
  assign bus_wdata_o = (state_q == ST_BLOCK_MEM) ? block_store_data :
                       (((state_q == ST_MEM) || (state_q == ST_SWAP_WRITE)) ? mem_wdata_q : 32'h0000_0000);

  assign debug_pc_o   = pc_q;
  assign debug_cpsr_o = cpsr;
  assign debug_reg_we_o    = reg_we;
  assign debug_reg_waddr_o = reg_waddr;
  assign debug_reg_wdata_o = reg_wdata;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      state_q          <= ST_RESET;
      pc_q             <= 32'h0000_0000;
      instr_q          <= 32'h0000_0000;
      next_fetch_seq_q <= 1'b0;
      mem_addr_q       <= 32'h0000_0000;
      mem_write_q      <= 1'b0;
      mem_load_q       <= 1'b0;
      mem_byte_q       <= 1'b0;
      mem_half_q       <= 1'b0;
      mem_signed_q     <= 1'b0;
      mem_swap_q       <= 1'b0;
      mem_thumb_q      <= 1'b0;
      mem_wb_q         <= 1'b0;
      mem_rn_q         <= 4'h0;
      mem_rd_q         <= 4'h0;
      mem_wdata_q      <= 32'h0000_0000;
      mem_wbdata_q     <= 32'h0000_0000;
      block_reglist_q  <= 16'h0000;
      block_reg_q      <= 4'h0;
      block_load_q     <= 1'b0;
      block_wb_q       <= 1'b0;
      block_restore_cpsr_q <= 1'b0;
      block_user_bank_q <= 1'b0;
      block_thumb_q    <= 1'b0;
      block_rn_q       <= 4'h0;
      block_wbdata_q   <= 32'h0000_0000;
      block_pc_wdata_q <= 32'h0000_0000;
      exception_lr_q   <= 32'h0000_0000;
      exception_spsr_q <= 32'h0000_0000;
      mul64_hi_waddr_q <= 4'h0;
      mul64_hi_wdata_q <= 32'h0000_0000;
      reg_we           <= 1'b0;
      reg_waddr        <= 4'h0;
      reg_wdata        <= 32'h0000_0000;
      reg_write_user   <= 1'b0;
      cpsr_we          <= 1'b0;
      cpsr_wdata       <= 32'h0000_00D3;
      spsr_we          <= 1'b0;
      spsr_wdata       <= 32'h0000_0000;
      retired_o        <= 1'b0;
      unsupported_o    <= 1'b0;
    end else begin
      reg_we        <= 1'b0;
      reg_write_user <= 1'b0;
      cpsr_we       <= 1'b0;
      spsr_we       <= 1'b0;
      retired_o     <= 1'b0;
      unsupported_o <= 1'b0;

      unique case (state_q)
        ST_RESET: begin
          pc_q             <= 32'h0000_0000;
          next_fetch_seq_q <= 1'b0;
          state_q          <= ST_FETCH;
        end

        ST_FETCH: begin
          if (fiq_i && !cpsr[6]) begin
            exception_lr_q   <= pc_q + 32'd4;
            exception_spsr_q <= cpsr;
            cpsr_we          <= 1'b1;
            cpsr_wdata       <= {cpsr[31:8], 1'b1, 1'b1, 1'b0, MODE_FIQ};
            pc_q             <= 32'h0000_001C;
            next_fetch_seq_q <= 1'b0;
            state_q          <= ST_EXCEPTION_SAVE;
          end else if (irq_i && !cpsr[7]) begin
            exception_lr_q   <= pc_q + 32'd4;
            exception_spsr_q <= cpsr;
            cpsr_we          <= 1'b1;
            cpsr_wdata       <= {cpsr[31:8], 1'b1, cpsr[6], 1'b0, MODE_IRQ};
            pc_q             <= 32'h0000_0018;
            next_fetch_seq_q <= 1'b0;
            state_q          <= ST_EXCEPTION_SAVE;
          end else if (bus_ready_i) begin
            if (bus_abort_i) begin
              exception_lr_q   <= pc_q + 32'd4;
              exception_spsr_q <= cpsr;
              cpsr_we          <= 1'b1;
              cpsr_wdata       <= {cpsr[31:8], 1'b1, cpsr[6], 1'b0, MODE_ABT};
              pc_q             <= 32'h0000_000C;
              next_fetch_seq_q <= 1'b0;
              state_q          <= ST_EXCEPTION_SAVE;
            end else begin
              instr_q <= thumb_state ? {16'h0000, bus_rdata_i[15:0]} : bus_rdata_i;
              state_q <= ST_EXECUTE;
            end
          end
        end

        ST_EXECUTE: begin
          retired_o <= execute_cond_pass && supported_execute && !thumb_state &&
                       (decoded.op_class != ARM_OP_SINGLE_DATA_TRANSFER) &&
                       (decoded.op_class != ARM_OP_HALFWORD_TRANSFER) &&
                       (decoded.op_class != ARM_OP_BLOCK_DATA_TRANSFER) &&
                       (decoded.op_class != ARM_OP_SWAP) &&
                       (decoded.op_class != ARM_OP_SWI);
          state_q <= ST_FETCH;

          if (thumb_state) begin
            retired_o <= thumb_decoded.supported;

            if (!thumb_decoded.supported) begin
              retired_o        <= 1'b0;
              exception_lr_q   <= pc_q + 32'd2;
              exception_spsr_q <= cpsr;
              cpsr_we          <= 1'b1;
              cpsr_wdata       <= {cpsr[31:8], cpsr[7:6], 1'b0, MODE_UND};
              pc_q             <= 32'h0000_0004;
              next_fetch_seq_q <= 1'b0;
              state_q          <= ST_EXCEPTION_SAVE;
            end else begin
              unique case (thumb_decoded.op_class)
              THUMB_OP_SHIFT_IMM, THUMB_OP_MOV_IMM, THUMB_OP_ADD_IMM, THUMB_OP_SUB_IMM,
              THUMB_OP_ADD_REG, THUMB_OP_SUB_REG, THUMB_OP_ADD_IMM3, THUMB_OP_SUB_IMM3: begin
                reg_we    <= 1'b1;
                reg_waddr <= rd;
                reg_wdata <= thumb_alu_result;
                cpsr_we   <= 1'b1;
                cpsr_wdata <= cpsr_with_flags(cpsr, thumb_flags);
                pc_q      <= pc_q + 32'd2;
                next_fetch_seq_q <= 1'b1;
              end

              THUMB_OP_HI_ADD, THUMB_OP_HI_MOV: begin
                if (rd == 4'd15) begin
                  pc_q <= thumb_alu_result & 32'hFFFF_FFFE;
                  next_fetch_seq_q <= 1'b0;
                end else begin
                  reg_we    <= 1'b1;
                  reg_waddr <= rd;
                  reg_wdata <= thumb_alu_result;
                  pc_q      <= pc_q + 32'd2;
                  next_fetch_seq_q <= 1'b1;
                end
              end

              THUMB_OP_CMP_IMM: begin
                cpsr_we    <= 1'b1;
                cpsr_wdata <= cpsr_with_flags(cpsr, thumb_flags);
                pc_q       <= pc_q + 32'd2;
                next_fetch_seq_q <= 1'b1;
              end

              THUMB_OP_HI_CMP: begin
                cpsr_we    <= 1'b1;
                cpsr_wdata <= cpsr_with_flags(cpsr, thumb_flags);
                pc_q       <= pc_q + 32'd2;
                next_fetch_seq_q <= 1'b1;
              end

              THUMB_OP_ADD_ADDR: begin
                reg_we    <= 1'b1;
                reg_waddr <= rd;
                reg_wdata <= thumb_alu_result;
                pc_q      <= pc_q + 32'd2;
                next_fetch_seq_q <= 1'b1;
              end

              THUMB_OP_SP_ADJUST: begin
                reg_we    <= 1'b1;
                reg_waddr <= 4'd13;
                reg_wdata <= thumb_alu_result;
                pc_q      <= pc_q + 32'd2;
                next_fetch_seq_q <= 1'b1;
              end

              THUMB_OP_BLOCK_TRANSFER: begin
                retired_o <= 1'b0;
                mem_addr_q <= rn_data;
                block_reglist_q <= thumb_block_reglist;
                block_reg_q <= first_reg_in_list(thumb_block_reglist);
                block_load_q <= thumb_decoded.ls_load;
                block_wb_q <= !thumb_decoded.ls_load || !thumb_block_reglist[{1'b0, thumb_decoded.rb}];
                block_restore_cpsr_q <= 1'b0;
                block_user_bank_q <= 1'b0;
                block_thumb_q <= 1'b1;
                block_rn_q <= {1'b0, thumb_decoded.rb};
                block_wbdata_q <= rn_data + thumb_block_byte_count;
                state_q <= ST_BLOCK_MEM;
              end

              THUMB_OP_STACK: begin
                retired_o <= 1'b0;
                mem_addr_q <= thumb_decoded.ls_load ? rn_data : (rn_data - thumb_stack_byte_count);
                block_reglist_q <= thumb_stack_reglist;
                block_reg_q <= first_reg_in_list(thumb_stack_reglist);
                block_load_q <= thumb_decoded.ls_load;
                block_wb_q <= 1'b1;
                block_restore_cpsr_q <= 1'b0;
                block_user_bank_q <= 1'b0;
                block_thumb_q <= 1'b1;
                block_rn_q <= 4'd13;
                block_wbdata_q <= thumb_decoded.ls_load ? (rn_data + thumb_stack_byte_count) :
                                                           (rn_data - thumb_stack_byte_count);
                state_q <= ST_BLOCK_MEM;
              end

              THUMB_OP_ALU_REG: begin
                if (thumb_alu_reg_write) begin
                  reg_we    <= 1'b1;
                  reg_waddr <= rd;
                  reg_wdata <= thumb_alu_result;
                end
                cpsr_we    <= 1'b1;
                cpsr_wdata <= cpsr_with_flags(cpsr, thumb_flags);
                pc_q       <= pc_q + 32'd2;
                next_fetch_seq_q <= 1'b1;
              end

              THUMB_OP_LDR_PC: begin
                retired_o    <= 1'b0;
                mem_addr_q   <= thumb_pc_load_addr;
                mem_write_q  <= 1'b0;
                mem_load_q   <= 1'b1;
                mem_byte_q   <= 1'b0;
                mem_half_q   <= 1'b0;
                mem_signed_q <= 1'b0;
                mem_swap_q   <= 1'b0;
                mem_thumb_q  <= 1'b1;
                mem_wb_q     <= 1'b0;
                mem_rn_q     <= 4'h0;
                mem_rd_q     <= rd;
                mem_wdata_q  <= 32'h0000_0000;
                mem_wbdata_q <= 32'h0000_0000;
                state_q      <= ST_MEM;
              end

              THUMB_OP_LS_IMM: begin
                retired_o    <= 1'b0;
                mem_addr_q   <= thumb_ls_addr;
                mem_write_q  <= !thumb_decoded.ls_load;
                mem_load_q   <= thumb_decoded.ls_load;
                mem_byte_q   <= thumb_decoded.ls_byte;
                mem_half_q   <= thumb_decoded.ls_half;
                mem_signed_q <= 1'b0;
                mem_swap_q   <= 1'b0;
                mem_thumb_q  <= 1'b1;
                mem_wb_q     <= 1'b0;
                mem_rn_q     <= 4'h0;
                mem_rd_q     <= rd;
                mem_wdata_q  <= thumb_decoded.ls_byte ? {24'h0, rd_data[7:0]} :
                                (thumb_decoded.ls_half ? {16'h0, rd_data[15:0]} : rd_data);
                mem_wbdata_q <= 32'h0000_0000;
                state_q      <= ST_MEM;
              end

              THUMB_OP_LS_REG: begin
                retired_o    <= 1'b0;
                mem_addr_q   <= thumb_ls_reg_addr;
                mem_write_q  <= !thumb_decoded.ls_load;
                mem_load_q   <= thumb_decoded.ls_load;
                mem_byte_q   <= thumb_decoded.ls_byte;
                mem_half_q   <= thumb_decoded.ls_half;
                mem_signed_q <= thumb_decoded.ls_signed;
                mem_swap_q   <= 1'b0;
                mem_thumb_q  <= 1'b1;
                mem_wb_q     <= 1'b0;
                mem_rn_q     <= 4'h0;
                mem_rd_q     <= rd;
                mem_wdata_q  <= thumb_decoded.ls_byte ? {24'h0, rd_data[7:0]} :
                                (thumb_decoded.ls_half ? {16'h0, rd_data[15:0]} : rd_data);
                mem_wbdata_q <= 32'h0000_0000;
                state_q      <= ST_MEM;
              end

              THUMB_OP_LS_SP: begin
                retired_o    <= 1'b0;
                mem_addr_q   <= thumb_ls_sp_addr;
                mem_write_q  <= !thumb_decoded.ls_load;
                mem_load_q   <= thumb_decoded.ls_load;
                mem_byte_q   <= 1'b0;
                mem_half_q   <= 1'b0;
                mem_signed_q <= 1'b0;
                mem_swap_q   <= 1'b0;
                mem_thumb_q  <= 1'b1;
                mem_wb_q     <= 1'b0;
                mem_rn_q     <= 4'h0;
                mem_rd_q     <= rd;
                mem_wdata_q  <= rd_data;
                mem_wbdata_q <= 32'h0000_0000;
                state_q      <= ST_MEM;
              end

              THUMB_OP_BRANCH: begin
                pc_q <= thumb_next_pc;
                next_fetch_seq_q <= 1'b0;
              end

              THUMB_OP_LONG_BRANCH_LINK: begin
                reg_we    <= 1'b1;
                reg_waddr <= 4'd14;
                if (thumb_decoded.branch_link) begin
                  reg_wdata <= (pc_q + 32'd2) | 32'h0000_0001;
                  pc_q      <= (rn_data + {20'h00000, thumb_decoded.branch_imm11, 1'b0}) &
                               32'hFFFF_FFFE;
                  next_fetch_seq_q <= 1'b0;
                end else begin
                  reg_wdata <= pc_q + 32'd4 +
                               {{9{thumb_decoded.branch_imm11[10]}},
                                thumb_decoded.branch_imm11, 12'h000};
                  pc_q      <= pc_q + 32'd2;
                  next_fetch_seq_q <= 1'b1;
                end
              end

              THUMB_OP_COND_BRANCH: begin
                pc_q <= thumb_next_pc;
                next_fetch_seq_q <= !thumb_cond_pass;
              end

              THUMB_OP_BRANCH_EXCHANGE: begin
                cpsr_we    <= 1'b1;
                cpsr_wdata <= thumb_bx_cpsr;
                pc_q       <= thumb_next_pc;
                next_fetch_seq_q <= 1'b0;
              end

              THUMB_OP_SWI: begin
                retired_o        <= 1'b0;
                exception_lr_q   <= pc_q + 32'd2;
                exception_spsr_q <= cpsr;
                cpsr_we          <= 1'b1;
                cpsr_wdata       <= {cpsr[31:8], 1'b1, cpsr[6], 1'b0, MODE_SVC};
                pc_q             <= 32'h0000_0008;
                next_fetch_seq_q <= 1'b0;
                state_q          <= ST_EXCEPTION_SAVE;
              end

              THUMB_OP_UNDEFINED: begin
                retired_o        <= 1'b0;
                exception_lr_q   <= pc_q + 32'd2;
                exception_spsr_q <= cpsr;
                cpsr_we          <= 1'b1;
                cpsr_wdata       <= {cpsr[31:8], cpsr[7:6], 1'b0, MODE_UND};
                pc_q             <= 32'h0000_0004;
                next_fetch_seq_q <= 1'b0;
                state_q          <= ST_EXCEPTION_SAVE;
              end

              default: begin
                unsupported_o <= 1'b1;
                pc_q <= pc_q + 32'd2;
                next_fetch_seq_q <= 1'b1;
              end
            endcase
            end
          end else if (!cond_pass) begin
            pc_q <= pc_q + 32'd4;
            next_fetch_seq_q <= 1'b1;
          end else if (decoded.op_class == ARM_OP_DATA_PROCESSING) begin
            if (alu_write_result) begin
              if (rd == 4'd15) begin
                pc_q <= alu_result & 32'hFFFF_FFFC;
                next_fetch_seq_q <= 1'b0;
                if (decoded.set_flags) begin
                  cpsr_we    <= 1'b1;
                  cpsr_wdata <= spsr;
                end
              end else begin
                reg_we    <= 1'b1;
                reg_waddr <= rd;
                reg_wdata <= alu_result;
                pc_q      <= pc_q + 32'd4;
                next_fetch_seq_q <= 1'b1;
              end
            end else begin
              pc_q <= pc_q + 32'd4;
              next_fetch_seq_q <= 1'b1;
            end

            if (decoded.set_flags && !(alu_write_result && rd == 4'd15)) begin
              cpsr_we    <= 1'b1;
              cpsr_wdata <= cpsr_with_flags(cpsr, alu_flags);
            end
          end else if (decoded.op_class == ARM_OP_BRANCH) begin
            if (decoded.branch_link) begin
              reg_we    <= 1'b1;
              reg_waddr <= 4'd14;
              reg_wdata <= pc_q + 32'd4;
            end
            pc_q <= next_pc;
            next_fetch_seq_q <= 1'b0;
          end else if (decoded.op_class == ARM_OP_BRANCH_EXCHANGE) begin
            cpsr_we    <= 1'b1;
            cpsr_wdata <= bx_cpsr;
            pc_q       <= next_pc;
            next_fetch_seq_q <= 1'b0;
          end else if (decoded.op_class == ARM_OP_MULTIPLY) begin
            reg_we    <= 1'b1;
            reg_waddr <= rd;
            reg_wdata <= mul_result;

            if (decoded.set_flags) begin
              cpsr_we    <= 1'b1;
              cpsr_wdata <= cpsr_with_flags(cpsr, mul_flags);
            end

            pc_q <= pc_q + 32'd4;
            next_fetch_seq_q <= 1'b1;
          end else if (decoded.op_class == ARM_OP_LONG_MULTIPLY) begin
            reg_we    <= 1'b1;
            reg_waddr <= rd;
            reg_wdata <= mul64_result[31:0];
            mul64_hi_waddr_q <= rn;
            mul64_hi_wdata_q <= mul64_result[63:32];

            if (decoded.set_flags) begin
              cpsr_we    <= 1'b1;
              cpsr_wdata <= cpsr_with_flags(cpsr, mul_flags);
            end

            state_q <= ST_MUL64_HI;
          end else if (decoded.op_class == ARM_OP_PSR_TRANSFER) begin
            if (decoded.psr_write) begin
              if (decoded.psr_use_spsr) begin
                spsr_we    <= 1'b1;
                spsr_wdata <= psr_with_field_mask(spsr, psr_write_value, decoded.psr_field_mask);
              end else begin
                cpsr_we    <= 1'b1;
                cpsr_wdata <= psr_with_field_mask(cpsr, psr_write_value, decoded.psr_field_mask);
              end
            end else begin
              reg_we    <= 1'b1;
              reg_waddr <= rd;
              reg_wdata <= decoded.psr_use_spsr ? spsr : cpsr;
            end

            pc_q <= pc_q + 32'd4;
            next_fetch_seq_q <= 1'b1;
          end else if (decoded.op_class == ARM_OP_SINGLE_DATA_TRANSFER) begin
            mem_addr_q  <= ls_transfer_addr;
            mem_write_q <= !decoded.ls_load;
            mem_load_q  <= decoded.ls_load;
            mem_byte_q  <= decoded.ls_byte;
            mem_half_q  <= 1'b0;
            mem_signed_q <= 1'b0;
            mem_swap_q  <= 1'b0;
            mem_thumb_q <= 1'b0;
            mem_wb_q    <= decoded.ls_writeback || !decoded.ls_pre_index;
            mem_rn_q    <= rn;
            mem_rd_q    <= rd;
            mem_wdata_q <= decoded.ls_byte ? {24'h0, rs_data[7:0]} : rs_data;
            mem_wbdata_q <= ls_addr;
            state_q     <= ST_MEM;
          end else if (decoded.op_class == ARM_OP_HALFWORD_TRANSFER) begin
            mem_addr_q  <= hword_transfer_addr;
            mem_write_q <= !decoded.ls_load;
            mem_load_q  <= decoded.ls_load;
            mem_byte_q  <= decoded.hword_transfer_type == 2'b10;
            mem_half_q  <= decoded.hword_transfer_type != 2'b10;
            mem_signed_q <= decoded.hword_transfer_type != 2'b01;
            mem_swap_q  <= 1'b0;
            mem_thumb_q <= 1'b0;
            mem_wb_q    <= decoded.ls_writeback || !decoded.ls_pre_index;
            mem_rn_q    <= rn;
            mem_rd_q    <= rd;
            mem_wdata_q <= {16'h0, rs_data[15:0]};
            mem_wbdata_q <= hword_addr;
            state_q     <= ST_MEM;
          end else if (decoded.op_class == ARM_OP_SWAP) begin
            mem_addr_q  <= rn_data;
            mem_write_q <= 1'b0;
            mem_load_q  <= 1'b1;
            mem_byte_q  <= decoded.ls_byte;
            mem_half_q  <= 1'b0;
            mem_signed_q <= 1'b0;
            mem_swap_q  <= 1'b1;
            mem_thumb_q <= 1'b0;
            mem_wb_q    <= 1'b0;
            mem_rn_q    <= rn;
            mem_rd_q    <= rd;
            mem_wdata_q <= decoded.ls_byte ? {24'h0, rm_data[7:0]} : rm_data;
            mem_wbdata_q <= 32'h0000_0000;
            state_q     <= ST_MEM;
          end else if (decoded.op_class == ARM_OP_BLOCK_DATA_TRANSFER) begin
            mem_addr_q <= block_start_addr;
            block_reglist_q <= block_effective_reglist;
            block_reg_q <= first_reg_in_list(block_effective_reglist);
            block_load_q <= decoded.ls_load;
            block_wb_q <= decoded.ls_writeback;
            block_restore_cpsr_q <= decoded.psr_use_spsr && decoded.ls_load && decoded.block_reglist[15];
            block_user_bank_q <= decoded.psr_use_spsr && !decoded.block_reglist[15];
            block_thumb_q <= 1'b0;
            block_rn_q <= rn;
            block_wbdata_q <= decoded.ls_up ? (rn_data + block_byte_count) :
                                                (rn_data - block_byte_count);
            state_q <= ST_BLOCK_MEM;
          end else if (decoded.op_class == ARM_OP_SWI) begin
            exception_lr_q   <= pc_q + 32'd4;
            exception_spsr_q <= cpsr;
            cpsr_we          <= 1'b1;
            cpsr_wdata       <= {cpsr[31:8], 1'b1, cpsr[6], 1'b0, MODE_SVC};
            pc_q             <= 32'h0000_0008;
            next_fetch_seq_q <= 1'b0;
            state_q          <= ST_EXCEPTION_SAVE;
          end else if ((decoded.op_class == ARM_OP_UNDEFINED) ||
                       (decoded.op_class == ARM_OP_COPROCESSOR)) begin
            exception_lr_q   <= pc_q + 32'd4;
            exception_spsr_q <= cpsr;
            cpsr_we          <= 1'b1;
            cpsr_wdata       <= {cpsr[31:8], cpsr[7:6], 1'b0, MODE_UND};
            pc_q             <= 32'h0000_0004;
            next_fetch_seq_q <= 1'b0;
            state_q          <= ST_EXCEPTION_SAVE;
          end else begin
            unsupported_o <= 1'b1;
            pc_q <= pc_q + 32'd4;
            next_fetch_seq_q <= 1'b1;
          end
        end

        ST_MEM: begin
          if (bus_ready_i) begin
            if (bus_abort_i) begin
              if (mem_wb_q && !mem_swap_q) begin
                reg_we    <= 1'b1;
                reg_waddr <= mem_rn_q;
                reg_wdata <= mem_wbdata_q;
              end

              exception_lr_q   <= pc_q + (mem_thumb_q ? 32'd4 : 32'd8);
              exception_spsr_q <= cpsr;
              cpsr_we          <= 1'b1;
              cpsr_wdata       <= {cpsr[31:8], 1'b1, cpsr[6], 1'b0, MODE_ABT};
              pc_q             <= 32'h0000_0010;
              next_fetch_seq_q <= 1'b0;
              state_q          <= ST_EXCEPTION_SAVE;
            end else if (mem_swap_q) begin
              mem_wbdata_q <= mem_byte_q ? {24'h0, bus_rdata_i[7:0]} : bus_rdata_i;
              mem_write_q  <= 1'b1;
              mem_load_q   <= 1'b0;
              state_q      <= ST_SWAP_WRITE;
            end else if (mem_load_q) begin
              if (mem_rd_q == 4'd15) begin
                pc_q <= rotate_word_load(bus_rdata_i, mem_addr_q[1:0]) & 32'hFFFF_FFFC;
                next_fetch_seq_q <= 1'b0;
              end else begin
                reg_we    <= 1'b1;
                reg_waddr <= mem_rd_q;
                reg_wdata <= mem_byte_q ? (mem_signed_q ? {{24{bus_rdata_i[7]}}, bus_rdata_i[7:0]} :
                                                           {24'h0, bus_rdata_i[7:0]}) :
                                        (mem_half_q ? (mem_signed_q ? {{16{bus_rdata_i[15]}}, bus_rdata_i[15:0]} :
                                                                      {16'h0, bus_rdata_i[15:0]}) :
                                                      rotate_word_load(bus_rdata_i, mem_addr_q[1:0]));
              end

              if (mem_wb_q) begin
                state_q <= ST_MEM_WB;
              end else begin
                retired_o <= 1'b1;
                if (mem_rd_q != 4'd15) begin
                  pc_q <= pc_q + (mem_thumb_q ? 32'd2 : 32'd4);
                  next_fetch_seq_q <= 1'b0;
                end
                state_q <= ST_FETCH;
              end
            end else if (mem_wb_q) begin
              reg_we    <= 1'b1;
              reg_waddr <= mem_rn_q;
              reg_wdata <= mem_wbdata_q;
              retired_o <= 1'b1;
              pc_q <= pc_q + (mem_thumb_q ? 32'd2 : 32'd4);
              next_fetch_seq_q <= 1'b0;
              state_q <= ST_FETCH;
            end else begin
              retired_o <= 1'b1;
              pc_q <= pc_q + (mem_thumb_q ? 32'd2 : 32'd4);
              next_fetch_seq_q <= 1'b0;
              state_q <= ST_FETCH;
            end
          end
        end

        ST_SWAP_WRITE: begin
          if (bus_ready_i) begin
            if (bus_abort_i) begin
              exception_lr_q   <= pc_q + 32'd8;
              exception_spsr_q <= cpsr;
              cpsr_we          <= 1'b1;
              cpsr_wdata       <= {cpsr[31:8], 1'b1, cpsr[6], 1'b0, MODE_ABT};
              pc_q             <= 32'h0000_0010;
              next_fetch_seq_q <= 1'b0;
              state_q          <= ST_EXCEPTION_SAVE;
            end else begin
              state_q <= ST_SWAP_WB;
            end
          end
        end

        ST_SWAP_WB: begin
          reg_we    <= 1'b1;
          reg_waddr <= mem_rd_q;
          reg_wdata <= mem_wbdata_q;

          retired_o <= 1'b1;
          pc_q <= pc_q + 32'd4;
          next_fetch_seq_q <= 1'b0;
          state_q <= ST_FETCH;
        end

        ST_BLOCK_MEM: begin
          if (bus_ready_i) begin
            if (bus_abort_i) begin
              exception_lr_q   <= pc_q + (block_thumb_q ? 32'd4 : 32'd8);
              exception_spsr_q <= cpsr;
              cpsr_we          <= 1'b1;
              cpsr_wdata       <= {cpsr[31:8], 1'b1, cpsr[6], 1'b0, MODE_ABT};
              pc_q             <= 32'h0000_0010;
              next_fetch_seq_q <= 1'b0;
              state_q          <= ST_EXCEPTION_SAVE;
            end else if (block_load_q) begin
              if (block_reg_q == 4'd15) begin
                block_pc_wdata_q <= block_pc_load_addr;
                if (block_restore_cpsr_q) begin
                  cpsr_we    <= 1'b1;
                  cpsr_wdata <= spsr;
                end
              end else begin
                reg_we    <= 1'b1;
                reg_waddr <= block_reg_q;
                reg_wdata <= bus_rdata_i;
                reg_write_user <= block_user_bank_q;
              end
            end

            if (block_last_reg) begin
              if (block_load_q && block_reg_q == 4'd15) begin
                if (block_wb_q) begin
                  state_q <= ST_BLOCK_PC_WB;
                end else begin
                  retired_o <= 1'b1;
                  pc_q <= block_pc_load_addr;
                  next_fetch_seq_q <= 1'b0;
                  state_q <= ST_FETCH;
                end
              end else if (block_wb_q) begin
                state_q <= ST_BLOCK_WB;
              end else begin
                retired_o <= 1'b1;
                pc_q <= pc_q + (block_thumb_q ? 32'd2 : 32'd4);
                next_fetch_seq_q <= 1'b0;
                state_q <= ST_FETCH;
              end
            end else begin
              mem_addr_q <= mem_addr_q + 32'd4;
              block_reglist_q <= block_next_reglist;
              block_reg_q <= block_next_reg;
            end
          end
        end

        ST_BLOCK_WB: begin
          reg_we    <= 1'b1;
          reg_waddr <= block_rn_q;
          reg_wdata <= block_wbdata_q;

          retired_o <= 1'b1;
          pc_q <= pc_q + (block_thumb_q ? 32'd2 : 32'd4);
          next_fetch_seq_q <= 1'b0;
          state_q <= ST_FETCH;
        end

        ST_BLOCK_PC_WB: begin
          reg_we    <= 1'b1;
          reg_waddr <= block_rn_q;
          reg_wdata <= block_wbdata_q;

          retired_o <= 1'b1;
          pc_q <= block_pc_wdata_q;
          next_fetch_seq_q <= 1'b0;
          state_q <= ST_FETCH;
        end

        ST_EXCEPTION_SAVE: begin
          reg_we    <= 1'b1;
          reg_waddr <= 4'd14;
          reg_wdata <= exception_lr_q;
          spsr_we   <= 1'b1;
          spsr_wdata <= exception_spsr_q;

          retired_o <= 1'b1;
          next_fetch_seq_q <= 1'b0;
          state_q <= ST_FETCH;
        end

        ST_MEM_WB: begin
          reg_we    <= 1'b1;
          reg_waddr <= mem_rn_q;
          reg_wdata <= mem_wbdata_q;

          retired_o <= 1'b1;
          pc_q <= pc_q + 32'd4;
          next_fetch_seq_q <= 1'b0;
          state_q <= ST_FETCH;
        end

        ST_MUL64_HI: begin
          reg_we    <= 1'b1;
          reg_waddr <= mul64_hi_waddr_q;
          reg_wdata <= mul64_hi_wdata_q;

          retired_o <= 1'b1;
          pc_q <= pc_q + 32'd4;
          next_fetch_seq_q <= 1'b1;
          state_q <= ST_FETCH;
        end

        default: begin
          state_q <= ST_RESET;
        end
      endcase
    end
  end

  logic unused_internal_terms;
  assign unused_internal_terms = alu_arithmetic ^ unused_rs_upper ^ unused_ls_modes ^
                                 unused_hword_modes ^ unused_psr_modes;
endmodule
