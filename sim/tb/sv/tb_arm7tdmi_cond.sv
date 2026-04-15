`timescale 1ns/1ps

module tb_arm7tdmi_cond
  import arm7tdmi_pkg::*;
;
  arm_cond_t  cond;
  arm_flags_t flags;
  logic       pass;

  arm7tdmi_cond dut (
    .cond_i(cond),
    .flags_i(flags),
    .pass_o(pass)
  );

  function automatic logic expected(input logic [3:0] cond_value, input arm_flags_t f);
    unique case (cond_value)
      4'h0: expected = f.z;
      4'h1: expected = !f.z;
      4'h2: expected = f.c;
      4'h3: expected = !f.c;
      4'h4: expected = f.n;
      4'h5: expected = !f.n;
      4'h6: expected = f.v;
      4'h7: expected = !f.v;
      4'h8: expected = f.c && !f.z;
      4'h9: expected = !f.c || f.z;
      4'hA: expected = f.n == f.v;
      4'hB: expected = f.n != f.v;
      4'hC: expected = !f.z && (f.n == f.v);
      4'hD: expected = f.z || (f.n != f.v);
      4'hE: expected = 1'b1;
      default: expected = 1'b0;
    endcase
  endfunction

  initial begin
    for (int c = 0; c < 16; c++) begin
      for (int f = 0; f < 16; f++) begin
        cond = arm_cond_t'(c[3:0]);
        flags = '{n: logic'(f[3]), z: logic'(f[2]), c: logic'(f[1]), v: logic'(f[0])};
        #1;
        if (pass !== expected(c[3:0], flags)) begin
          $fatal(1, "cond %0h flags %04b expected %0b got %0b", c, f[3:0], expected(c[3:0], flags), pass);
        end
      end
    end

    $display("tb_arm7tdmi_cond passed");
    $finish;
  end
endmodule
