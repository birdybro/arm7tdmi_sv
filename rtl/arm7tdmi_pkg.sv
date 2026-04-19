`timescale 1ns/1ps

package arm7tdmi_pkg;
  typedef enum logic [4:0] {
    MODE_USR = 5'b10000,
    MODE_FIQ = 5'b10001,
    MODE_IRQ = 5'b10010,
    MODE_SVC = 5'b10011,
    MODE_ABT = 5'b10111,
    MODE_UND = 5'b11011,
    MODE_SYS = 5'b11111
  } arm_mode_t;

  typedef struct packed {
    logic n;
    logic z;
    logic c;
    logic v;
  } arm_flags_t;

  typedef struct packed {
    logic [31:0] raw;
  } arm_cpsr_t;

  typedef enum logic [3:0] {
    COND_EQ = 4'h0,
    COND_NE = 4'h1,
    COND_CS = 4'h2,
    COND_CC = 4'h3,
    COND_MI = 4'h4,
    COND_PL = 4'h5,
    COND_VS = 4'h6,
    COND_VC = 4'h7,
    COND_HI = 4'h8,
    COND_LS = 4'h9,
    COND_GE = 4'hA,
    COND_LT = 4'hB,
    COND_GT = 4'hC,
    COND_LE = 4'hD,
    COND_AL = 4'hE,
    COND_NV = 4'hF
  } arm_cond_t;

  typedef enum logic [3:0] {
    ALU_AND = 4'h0,
    ALU_EOR = 4'h1,
    ALU_SUB = 4'h2,
    ALU_RSB = 4'h3,
    ALU_ADD = 4'h4,
    ALU_ADC = 4'h5,
    ALU_SBC = 4'h6,
    ALU_RSC = 4'h7,
    ALU_TST = 4'h8,
    ALU_TEQ = 4'h9,
    ALU_CMP = 4'hA,
    ALU_CMN = 4'hB,
    ALU_ORR = 4'hC,
    ALU_MOV = 4'hD,
    ALU_BIC = 4'hE,
    ALU_MVN = 4'hF
  } arm_alu_op_t;

  typedef enum logic [1:0] {
    SHIFT_LSL = 2'b00,
    SHIFT_LSR = 2'b01,
    SHIFT_ASR = 2'b10,
    SHIFT_ROR = 2'b11
  } arm_shift_t;

  typedef enum logic [1:0] {
    BUS_SIZE_BYTE = 2'b00,
    BUS_SIZE_HALF = 2'b01,
    BUS_SIZE_WORD = 2'b10
  } arm_bus_size_t;

  typedef enum logic [1:0] {
    BUS_CYCLE_NONSEQ = 2'b00,
    BUS_CYCLE_SEQ    = 2'b01,
    BUS_CYCLE_INT    = 2'b10,
    BUS_CYCLE_COPROC = 2'b11
  } arm_bus_cycle_t;

  typedef enum logic [3:0] {
    ARM_OP_UNDEFINED,
    ARM_OP_DATA_PROCESSING,
    ARM_OP_BRANCH,
    ARM_OP_BRANCH_EXCHANGE,
    ARM_OP_SINGLE_DATA_TRANSFER,
    ARM_OP_HALFWORD_TRANSFER,
    ARM_OP_BLOCK_DATA_TRANSFER,
    ARM_OP_MULTIPLY,
    ARM_OP_LONG_MULTIPLY,
    ARM_OP_SWAP,
    ARM_OP_PSR_TRANSFER,
    ARM_OP_SWI,
    ARM_OP_COPROCESSOR
  } arm_op_class_t;

  typedef enum logic [2:0] {
    THUMB_OP_UNDEFINED,
    THUMB_OP_MOV_IMM,
    THUMB_OP_CMP_IMM,
    THUMB_OP_ADD_IMM,
    THUMB_OP_SUB_IMM,
    THUMB_OP_BRANCH,
    THUMB_OP_BRANCH_EXCHANGE
  } thumb_op_class_t;

  typedef struct packed {
    arm_cond_t     cond;
    arm_op_class_t op_class;
    arm_alu_op_t   alu_op;
    logic [3:0]    rn;
    logic [3:0]    rd;
    logic [3:0]    rm;
    logic [3:0]    rs;
    logic          set_flags;
    logic          immediate_operand;
    logic          register_shift;
    arm_shift_t    shift_type;
    logic [4:0]    shift_imm;
    logic [7:0]    imm8;
    logic [3:0]    rotate_imm;
    logic          branch_link;
    logic [23:0]   branch_imm24;
    logic          ls_pre_index;
    logic          ls_up;
    logic          ls_byte;
    logic          ls_writeback;
    logic          ls_load;
    logic [11:0]   ls_offset12;
    logic [15:0]   block_reglist;
    logic          mul_accumulate;
    logic          mul_long_signed;
    logic [1:0]    hword_transfer_type;
    logic          hword_immediate_offset;
    logic [7:0]    hword_offset8;
    logic          psr_write;
    logic          psr_use_spsr;
    logic [3:0]    psr_field_mask;
    logic          supported;
  } arm_decoded_t;

  typedef struct packed {
    thumb_op_class_t op_class;
    logic [2:0]      rd;
    logic [3:0]      rm;
    logic [7:0]      imm8;
    logic [10:0]     branch_imm11;
    logic            supported;
  } thumb_decoded_t;

  function automatic arm_flags_t cpsr_flags(input logic [31:0] cpsr);
    logic unused;
    unused = ^cpsr[27:0];
    cpsr_flags.n = cpsr[31] ^ (unused & 1'b0);
    cpsr_flags.z = cpsr[30];
    cpsr_flags.c = cpsr[29];
    cpsr_flags.v = cpsr[28];
  endfunction

  function automatic logic [31:0] cpsr_with_flags(
      input logic [31:0] cpsr,
      input arm_flags_t flags
  );
    logic unused;
    unused = ^cpsr[31:28];
    cpsr_with_flags = {flags.n ^ (unused & 1'b0), flags.z, flags.c, flags.v, cpsr[27:0]};
  endfunction

  function automatic logic [31:0] psr_with_field_mask(
      input logic [31:0] psr,
      input logic [31:0] value,
      input logic [3:0] field_mask
  );
    psr_with_field_mask = psr;

    if (field_mask[0]) begin
      psr_with_field_mask[7:0] = value[7:0];
    end

    if (field_mask[1]) begin
      psr_with_field_mask[15:8] = value[15:8];
    end

    if (field_mask[2]) begin
      psr_with_field_mask[23:16] = value[23:16];
    end

    if (field_mask[3]) begin
      psr_with_field_mask[31:24] = value[31:24];
    end
  endfunction
endpackage
