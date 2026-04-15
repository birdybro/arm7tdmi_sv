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
  typedef enum logic [1:0] {
    ST_RESET,
    ST_FETCH,
    ST_EXECUTE
  } state_t;

  state_t state_q;
  logic [31:0] pc_q;
  logic [31:0] instr_q;
  logic        next_fetch_seq_q;

  logic [3:0] rn;
  logic [3:0] rd;
  logic [3:0] rm;
  arm_decoded_t decoded;
  logic [31:0] rn_data;
  logic [31:0] rm_data;
  logic [31:0] rs_data;
  logic [31:0] cpsr;
  logic [31:0] spsr;
  arm_flags_t flags;
  arm_mode_t  mode;

  logic       reg_we;
  logic [3:0] reg_waddr;
  logic [31:0] reg_wdata;
  logic       cpsr_we;
  logic [31:0] cpsr_wdata;
  logic       spsr_we;
  logic [31:0] spsr_wdata;

  logic       cond_pass;
  arm_alu_op_t alu_op;
  logic [31:0] alu_b;
  logic        shifter_carry;
  logic [31:0] shifted_rm;
  logic        shifted_rm_carry;
  logic [7:0]  shift_amount;
  logic [7:0]  rs_shift_amount;
  logic        unused_rs_upper;
  arm_shift_t  shift_type;
  logic [31:0] alu_result;
  arm_flags_t  alu_flags;
  logic        alu_write_result;
  logic        alu_arithmetic;

  logic        supported_execute;
  logic [31:0] next_pc;

  assign rn = decoded.rn;
  assign rd = decoded.rd;
  assign rm = decoded.rm;

  assign flags = cpsr_flags(cpsr);
  assign mode  = arm_mode_t'(cpsr[4:0]);
  assign rs_shift_amount = rs_data[7:0];
  assign unused_rs_upper = ^rs_data[31:8];

  arm7tdmi_regfile u_regfile (
    .clk_i,
    .rst_ni,
    .mode_i(mode),
    .pc_exec_i(pc_q),
    .raddr_a_i(rn),
    .raddr_b_i(rm),
    .raddr_c_i(decoded.register_shift ? decoded.rs : rd),
    .rdata_a_o(rn_data),
    .rdata_b_o(rm_data),
    .rdata_c_o(rs_data),
    .we_i(reg_we),
    .waddr_i(reg_waddr),
    .wdata_i(reg_wdata),
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

  arm7tdmi_cond u_cond (
    .cond_i(decoded.cond),
    .flags_i(flags),
    .pass_o(cond_pass)
  );

  arm7tdmi_shifter u_shifter (
    .value_i(rm_data),
    .shift_i(shift_type),
    .amount_i(shift_amount),
    .register_shift_i(decoded.register_shift),
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
    shift_type            = decoded.shift_type;
    shift_amount          = decoded.register_shift ? rs_shift_amount : {3'b000, decoded.shift_imm};
    alu_b                 = shifted_rm;
    shifter_carry         = shifted_rm_carry;
    supported_execute     = decoded.supported;
    next_pc               = pc_q + 32'd4;

    if (decoded.immediate_operand) begin
      alu_b = (32'({24'h0, decoded.imm8}) >> {decoded.rotate_imm, 1'b0}) |
              (32'({24'h0, decoded.imm8}) << (6'd32 - {1'b0, decoded.rotate_imm, 1'b0}));
      shifter_carry = (decoded.rotate_imm == 4'h0) ? flags.c : alu_b[31];
    end

    if (decoded.op_class == ARM_OP_BRANCH) begin
      next_pc = pc_q + 32'd8 + {{6{decoded.branch_imm24[23]}}, decoded.branch_imm24, 2'b00};
    end
  end

  assign bus_addr_o  = pc_q;
  assign bus_valid_o = state_q == ST_FETCH;
  assign bus_write_o = 1'b0;
  assign bus_size_o  = BUS_SIZE_WORD;
  assign bus_cycle_o = next_fetch_seq_q ? BUS_CYCLE_SEQ : BUS_CYCLE_NONSEQ;
  assign bus_wdata_o = 32'h0000_0000;

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
      reg_we           <= 1'b0;
      reg_waddr        <= 4'h0;
      reg_wdata        <= 32'h0000_0000;
      cpsr_we          <= 1'b0;
      cpsr_wdata       <= 32'h0000_00D3;
      spsr_we          <= 1'b0;
      spsr_wdata       <= 32'h0000_0000;
      retired_o        <= 1'b0;
      unsupported_o    <= 1'b0;
    end else begin
      reg_we        <= 1'b0;
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
          if (bus_ready_i) begin
            instr_q <= bus_rdata_i;
            state_q <= ST_EXECUTE;
          end
        end

        ST_EXECUTE: begin
          retired_o <= cond_pass && supported_execute;

          if (!cond_pass) begin
            pc_q <= pc_q + 32'd4;
            next_fetch_seq_q <= 1'b1;
          end else if (decoded.op_class == ARM_OP_DATA_PROCESSING) begin
            if (alu_write_result) begin
              if (rd == 4'd15) begin
                pc_q <= alu_result & 32'hFFFF_FFFC;
                next_fetch_seq_q <= 1'b0;
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

            if (decoded.set_flags) begin
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
          end else begin
            unsupported_o <= 1'b1;
            pc_q <= pc_q + 32'd4;
            next_fetch_seq_q <= 1'b1;
          end

          state_q <= ST_FETCH;
        end

        default: begin
          state_q <= ST_RESET;
        end
      endcase
    end
  end

  // Interrupt inputs are intentionally part of the public interface from day one.
  // Exception entry is not implemented until the basic ARM/Thumb datapath is stable.
  logic unused_interrupts;
  assign unused_interrupts = irq_i ^ fiq_i ^ alu_arithmetic ^ ^spsr ^ unused_rs_upper;
endmodule
