`timescale 1ns/1ps

module arm7tdmi_cond
  import arm7tdmi_pkg::*;
(
  input  arm_cond_t  cond_i,
  input  arm_flags_t flags_i,
  output logic       pass_o
);
  always_comb begin
    unique case (cond_i)
      COND_EQ: pass_o = flags_i.z;
      COND_NE: pass_o = !flags_i.z;
      COND_CS: pass_o = flags_i.c;
      COND_CC: pass_o = !flags_i.c;
      COND_MI: pass_o = flags_i.n;
      COND_PL: pass_o = !flags_i.n;
      COND_VS: pass_o = flags_i.v;
      COND_VC: pass_o = !flags_i.v;
      COND_HI: pass_o = flags_i.c && !flags_i.z;
      COND_LS: pass_o = !flags_i.c || flags_i.z;
      COND_GE: pass_o = flags_i.n == flags_i.v;
      COND_LT: pass_o = flags_i.n != flags_i.v;
      COND_GT: pass_o = !flags_i.z && (flags_i.n == flags_i.v);
      COND_LE: pass_o = flags_i.z || (flags_i.n != flags_i.v);
      COND_AL: pass_o = 1'b1;
      default: pass_o = 1'b0;
    endcase
  end
endmodule
