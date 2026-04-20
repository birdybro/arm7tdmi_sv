`timescale 1ns/1ps

module arm7tdmi_regfile
  import arm7tdmi_pkg::*;
(
  input  logic       clk_i,
  input  logic       rst_ni,

  input  arm_mode_t  mode_i,
  input  logic       thumb_i,
  input  logic [31:0] pc_exec_i,

  input  logic [3:0] raddr_a_i,
  input  logic [3:0] raddr_b_i,
  input  logic [3:0] raddr_c_i,
  input  logic       raddr_c_user_i,
  input  logic [3:0] raddr_d_i,
  output logic [31:0] rdata_a_o,
  output logic [31:0] rdata_b_o,
  output logic [31:0] rdata_c_o,
  output logic [31:0] rdata_d_o,

  input  logic       we_i,
  input  logic [3:0] waddr_i,
  input  logic [31:0] wdata_i,
  input  logic       wuser_i,

  input  logic       cpsr_we_i,
  input  logic [31:0] cpsr_wdata_i,
  output logic [31:0] cpsr_o,

  input  logic       spsr_we_i,
  input  logic [31:0] spsr_wdata_i,
  output logic [31:0] spsr_o
);
  logic [31:0] r_usr [0:14];
  logic [31:0] r_fiq [8:14];
  logic [31:0] r_irq [13:14];
  logic [31:0] r_svc [13:14];
  logic [31:0] r_abt [13:14];
  logic [31:0] r_und [13:14];

  logic [31:0] cpsr_q;
  logic [31:0] spsr_fiq_q;
  logic [31:0] spsr_irq_q;
  logic [31:0] spsr_svc_q;
  logic [31:0] spsr_abt_q;
  logic [31:0] spsr_und_q;

  function automatic logic fiq_bank(input arm_mode_t mode, input logic [3:0] addr);
    fiq_bank = (mode == MODE_FIQ) && (addr >= 4'd8) && (addr <= 4'd14);
  endfunction

  function automatic logic mode_r13_r14_bank(input arm_mode_t mode, input logic [3:0] addr);
    mode_r13_r14_bank = (addr == 4'd13 || addr == 4'd14) &&
                        (mode inside {MODE_IRQ, MODE_SVC, MODE_ABT, MODE_UND});
  endfunction

  function automatic logic [31:0] read_reg(input arm_mode_t mode, input logic [3:0] addr);
    if (addr == 4'd15) begin
      read_reg = thumb_i ? (pc_exec_i + 32'd4) : (pc_exec_i + 32'd8);
    end else if (fiq_bank(mode, addr)) begin
      read_reg = r_fiq[addr];
    end else if (mode_r13_r14_bank(mode, addr)) begin
      unique case (mode)
        MODE_IRQ: read_reg = r_irq[addr];
        MODE_SVC: read_reg = r_svc[addr];
        MODE_ABT: read_reg = r_abt[addr];
        MODE_UND: read_reg = r_und[addr];
        default:  read_reg = r_usr[addr];
      endcase
    end else begin
      read_reg = r_usr[addr];
    end
  endfunction

  function automatic logic [31:0] read_spsr(input arm_mode_t mode);
    unique case (mode)
      MODE_FIQ: read_spsr = spsr_fiq_q;
      MODE_IRQ: read_spsr = spsr_irq_q;
      MODE_SVC: read_spsr = spsr_svc_q;
      MODE_ABT: read_spsr = spsr_abt_q;
      MODE_UND: read_spsr = spsr_und_q;
      default:  read_spsr = 32'h0000_0000;
    endcase
  endfunction

  assign rdata_a_o = read_reg(mode_i, raddr_a_i);
  assign rdata_b_o = read_reg(mode_i, raddr_b_i);
  assign rdata_c_o = read_reg(raddr_c_user_i ? MODE_USR : mode_i, raddr_c_i);
  assign rdata_d_o = read_reg(mode_i, raddr_d_i);
  assign cpsr_o    = cpsr_q;
  assign spsr_o    = read_spsr(mode_i);

  integer i;
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      for (i = 0; i <= 14; i++) begin
        r_usr[i] <= 32'h0000_0000;
      end
      for (i = 8; i <= 14; i++) begin
        r_fiq[i] <= 32'h0000_0000;
      end
      for (i = 13; i <= 14; i++) begin
        r_irq[i] <= 32'h0000_0000;
        r_svc[i] <= 32'h0000_0000;
        r_abt[i] <= 32'h0000_0000;
        r_und[i] <= 32'h0000_0000;
      end
      cpsr_q     <= {24'h0, 1'b1, 1'b1, 1'b0, MODE_SVC};
      spsr_fiq_q <= 32'h0000_0000;
      spsr_irq_q <= 32'h0000_0000;
      spsr_svc_q <= 32'h0000_0000;
      spsr_abt_q <= 32'h0000_0000;
      spsr_und_q <= 32'h0000_0000;
    end else begin
      if (we_i && waddr_i != 4'd15) begin
        if (fiq_bank(wuser_i ? MODE_USR : mode_i, waddr_i)) begin
          r_fiq[waddr_i] <= wdata_i;
        end else if (mode_r13_r14_bank(wuser_i ? MODE_USR : mode_i, waddr_i)) begin
          unique case (wuser_i ? MODE_USR : mode_i)
            MODE_IRQ: r_irq[waddr_i] <= wdata_i;
            MODE_SVC: r_svc[waddr_i] <= wdata_i;
            MODE_ABT: r_abt[waddr_i] <= wdata_i;
            MODE_UND: r_und[waddr_i] <= wdata_i;
            default:  r_usr[waddr_i] <= wdata_i;
          endcase
        end else begin
          r_usr[waddr_i] <= wdata_i;
        end
      end

      if (cpsr_we_i) begin
        cpsr_q <= cpsr_wdata_i;
      end

      if (spsr_we_i) begin
        unique case (mode_i)
          MODE_FIQ: spsr_fiq_q <= spsr_wdata_i;
          MODE_IRQ: spsr_irq_q <= spsr_wdata_i;
          MODE_SVC: spsr_svc_q <= spsr_wdata_i;
          MODE_ABT: spsr_abt_q <= spsr_wdata_i;
          MODE_UND: spsr_und_q <= spsr_wdata_i;
          default: begin end
        endcase
      end
    end
  end
endmodule
