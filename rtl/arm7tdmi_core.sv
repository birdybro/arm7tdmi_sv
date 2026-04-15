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
  typedef enum logic [2:0] {
    ST_RESET,
    ST_FETCH,
    ST_EXECUTE,
    ST_MEM,
    ST_MEM_WB
  } state_t;

  state_t state_q;
  logic [31:0] pc_q;
  logic [31:0] instr_q;
  logic        next_fetch_seq_q;
  logic [31:0] mem_addr_q;
  logic        mem_write_q;
  logic        mem_load_q;
  logic        mem_byte_q;
  logic        mem_wb_q;
  logic [3:0]  mem_rn_q;
  logic [3:0]  mem_rd_q;
  logic [31:0] mem_wdata_q;
  logic [31:0] mem_wbdata_q;

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
  logic        unused_ls_modes;
  arm_shift_t  shift_type;
  logic [31:0] alu_result;
  arm_flags_t  alu_flags;
  logic        alu_write_result;
  logic        alu_arithmetic;
  logic [31:0] mul_result;
  arm_flags_t  mul_flags;

  logic        supported_execute;
  logic [31:0] next_pc;
  logic [31:0] bx_cpsr;
  logic [31:0] ls_offset;
  logic [31:0] ls_addr;
  logic [31:0] ls_transfer_addr;

  assign rn = decoded.rn;
  assign rd = decoded.rd;
  assign rm = decoded.rm;

  assign flags = cpsr_flags(cpsr);
  assign mode  = arm_mode_t'(cpsr[4:0]);
  assign rs_shift_amount = rs_data[7:0];
  assign unused_rs_upper = ^rs_data[31:8];
  assign unused_ls_modes = decoded.ls_pre_index ^ decoded.ls_byte ^ decoded.ls_writeback;

  arm7tdmi_regfile u_regfile (
    .clk_i,
    .rst_ni,
    .mode_i(mode),
    .pc_exec_i(pc_q),
    .raddr_a_i(rn),
    .raddr_b_i(rm),
    .raddr_c_i((decoded.register_shift || decoded.op_class == ARM_OP_MULTIPLY) ? decoded.rs : rd),
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
    bx_cpsr               = cpsr;
    ls_offset             = decoded.immediate_operand ? shifted_rm : {20'h0, decoded.ls_offset12};
    ls_addr               = decoded.ls_up ? rn_data + ls_offset : rn_data - ls_offset;
    ls_transfer_addr      = decoded.ls_pre_index ? ls_addr : rn_data;
    mul_result            = (rm_data * rs_data) + (decoded.mul_accumulate ? rn_data : 32'h0000_0000);
    mul_flags             = flags;
    mul_flags.n           = mul_result[31];
    mul_flags.z           = mul_result == 32'h0000_0000;

    if (decoded.immediate_operand) begin
      alu_b = (32'({24'h0, decoded.imm8}) >> {decoded.rotate_imm, 1'b0}) |
              (32'({24'h0, decoded.imm8}) << (6'd32 - {1'b0, decoded.rotate_imm, 1'b0}));
      shifter_carry = (decoded.rotate_imm == 4'h0) ? flags.c : alu_b[31];
    end

    if (decoded.op_class == ARM_OP_BRANCH) begin
      next_pc = pc_q + 32'd8 + {{6{decoded.branch_imm24[23]}}, decoded.branch_imm24, 2'b00};
    end

    if (decoded.op_class == ARM_OP_BRANCH_EXCHANGE) begin
      next_pc    = rm_data[0] ? {rm_data[31:1], 1'b0} : {rm_data[31:2], 2'b00};
      bx_cpsr[5] = rm_data[0];
    end
  end

  assign bus_addr_o  = (state_q == ST_MEM) ? mem_addr_q : pc_q;
  assign bus_valid_o = (state_q == ST_FETCH) || (state_q == ST_MEM);
  assign bus_write_o = (state_q == ST_MEM) && mem_write_q;
  assign bus_size_o  = ((state_q == ST_MEM) && mem_byte_q) ? BUS_SIZE_BYTE : BUS_SIZE_WORD;
  assign bus_cycle_o = (state_q == ST_MEM) ? BUS_CYCLE_NONSEQ :
                                             (next_fetch_seq_q ? BUS_CYCLE_SEQ : BUS_CYCLE_NONSEQ);
  assign bus_wdata_o = (state_q == ST_MEM) ? mem_wdata_q : 32'h0000_0000;

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
      mem_wb_q         <= 1'b0;
      mem_rn_q         <= 4'h0;
      mem_rd_q         <= 4'h0;
      mem_wdata_q      <= 32'h0000_0000;
      mem_wbdata_q     <= 32'h0000_0000;
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
          retired_o <= cond_pass && supported_execute &&
                       (decoded.op_class != ARM_OP_SINGLE_DATA_TRANSFER);
          state_q <= ST_FETCH;

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
          end else if (decoded.op_class == ARM_OP_SINGLE_DATA_TRANSFER) begin
            mem_addr_q  <= ls_transfer_addr;
            mem_write_q <= !decoded.ls_load;
            mem_load_q  <= decoded.ls_load;
            mem_byte_q  <= decoded.ls_byte;
            mem_wb_q    <= decoded.ls_writeback || !decoded.ls_pre_index;
            mem_rn_q    <= rn;
            mem_rd_q    <= rd;
            mem_wdata_q <= decoded.ls_byte ? {24'h0, rs_data[7:0]} : rs_data;
            mem_wbdata_q <= ls_addr;
            state_q     <= ST_MEM;
          end else begin
            unsupported_o <= 1'b1;
            pc_q <= pc_q + 32'd4;
            next_fetch_seq_q <= 1'b1;
          end
        end

        ST_MEM: begin
          if (bus_ready_i) begin
            if (mem_load_q) begin
              reg_we    <= 1'b1;
              reg_waddr <= mem_rd_q;
              reg_wdata <= mem_byte_q ? {24'h0, bus_rdata_i[7:0]} : bus_rdata_i;

              if (mem_wb_q) begin
                state_q <= ST_MEM_WB;
              end else begin
                retired_o <= 1'b1;
                pc_q <= pc_q + 32'd4;
                next_fetch_seq_q <= 1'b0;
                state_q <= ST_FETCH;
              end
            end else if (mem_wb_q) begin
              reg_we    <= 1'b1;
              reg_waddr <= mem_rn_q;
              reg_wdata <= mem_wbdata_q;
              retired_o <= 1'b1;
              pc_q <= pc_q + 32'd4;
              next_fetch_seq_q <= 1'b0;
              state_q <= ST_FETCH;
            end else begin
              retired_o <= 1'b1;
              pc_q <= pc_q + 32'd4;
              next_fetch_seq_q <= 1'b0;
              state_q <= ST_FETCH;
            end
          end
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

        default: begin
          state_q <= ST_RESET;
        end
      endcase
    end
  end

  // Interrupt inputs are intentionally part of the public interface from day one.
  // Exception entry is not implemented until the basic ARM/Thumb datapath is stable.
  logic unused_interrupts;
  assign unused_interrupts = irq_i ^ fiq_i ^ alu_arithmetic ^ ^spsr ^ unused_rs_upper ^ unused_ls_modes;
endmodule
