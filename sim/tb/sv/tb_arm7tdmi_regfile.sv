`timescale 1ns/1ps

module tb_arm7tdmi_regfile
  import arm7tdmi_pkg::*;
;
  logic clk;
  logic rst_n;
  arm_mode_t mode;
  logic [31:0] pc_exec;
  logic [3:0] raddr_a;
  logic [3:0] raddr_b;
  logic [3:0] raddr_c;
  logic raddr_c_user;
  logic [31:0] rdata_a;
  logic [31:0] rdata_b;
  logic [31:0] rdata_c;
  logic we;
  logic [3:0] waddr;
  logic [31:0] wdata;
  logic wuser;
  logic cpsr_we;
  logic [31:0] cpsr_wdata;
  logic [31:0] cpsr;
  logic spsr_we;
  logic [31:0] spsr_wdata;
  logic [31:0] spsr;

  arm7tdmi_regfile dut (
    .clk_i(clk),
    .rst_ni(rst_n),
    .mode_i(mode),
    .pc_exec_i(pc_exec),
    .raddr_a_i(raddr_a),
    .raddr_b_i(raddr_b),
    .raddr_c_i(raddr_c),
    .raddr_c_user_i(raddr_c_user),
    .rdata_a_o(rdata_a),
    .rdata_b_o(rdata_b),
    .rdata_c_o(rdata_c),
    .we_i(we),
    .waddr_i(waddr),
    .wdata_i(wdata),
    .wuser_i(wuser),
    .cpsr_we_i(cpsr_we),
    .cpsr_wdata_i(cpsr_wdata),
    .cpsr_o(cpsr),
    .spsr_we_i(spsr_we),
    .spsr_wdata_i(spsr_wdata),
    .spsr_o(spsr)
  );

  initial clk = 1'b0;
  always #5 clk = !clk;

  task automatic tick;
    @(posedge clk);
    #1;
  endtask

  task automatic write_reg(input arm_mode_t mode_t, input logic [3:0] addr, input logic [31:0] data);
    mode = mode_t;
    waddr = addr;
    wdata = data;
    we = 1'b1;
    tick();
    we = 1'b0;
    waddr = 4'h0;
    wdata = 32'h0;
    #1;
  endtask

  task automatic write_user_reg(input arm_mode_t mode_t, input logic [3:0] addr, input logic [31:0] data);
    mode = mode_t;
    waddr = addr;
    wdata = data;
    wuser = 1'b1;
    we = 1'b1;
    tick();
    we = 1'b0;
    wuser = 1'b0;
    waddr = 4'h0;
    wdata = 32'h0;
    #1;
  endtask

  task automatic read_expect(input arm_mode_t mode_t, input logic [3:0] addr, input logic [31:0] expected);
    mode = mode_t;
    raddr_a = addr;
    raddr_b = addr;
    raddr_c = addr;
    #1;
    if (rdata_a !== expected || rdata_b !== expected || rdata_c !== expected) begin
      $fatal(1, "mode=%05b r%0d expected %08x got a=%08x b=%08x c=%08x",
             mode_t, addr, expected, rdata_a, rdata_b, rdata_c);
    end
  endtask

  task automatic read_c_user_expect(input arm_mode_t mode_t, input logic [3:0] addr,
                                    input logic [31:0] expected);
    mode = mode_t;
    raddr_c = addr;
    raddr_c_user = 1'b1;
    #1;
    if (rdata_c !== expected) begin
      $fatal(1, "mode=%05b user r%0d expected %08x got c=%08x",
             mode_t, addr, expected, rdata_c);
    end
    raddr_c_user = 1'b0;
  endtask

  task automatic write_spsr(input arm_mode_t mode_t, input logic [31:0] data);
    mode = mode_t;
    spsr_wdata = data;
    spsr_we = 1'b1;
    tick();
    spsr_we = 1'b0;
    spsr_wdata = 32'h0;
    #1;
  endtask

  task automatic spsr_expect(input arm_mode_t mode_t, input logic [31:0] expected);
    mode = mode_t;
    #1;
    if (spsr !== expected) begin
      $fatal(1, "mode=%05b SPSR expected %08x got %08x", mode_t, expected, spsr);
    end
  endtask

  initial begin
    rst_n = 1'b0;
    mode = MODE_SVC;
    pc_exec = 32'h0800_0000;
    raddr_a = 4'h0;
    raddr_b = 4'h0;
    raddr_c = 4'h0;
    raddr_c_user = 1'b0;
    we = 1'b0;
    wuser = 1'b0;
    waddr = 4'h0;
    wdata = 32'h0;
    cpsr_we = 1'b0;
    cpsr_wdata = 32'h0;
    spsr_we = 1'b0;
    spsr_wdata = 32'h0;

    repeat (2) tick();
    rst_n = 1'b1;
    tick();

    if (cpsr[7] !== 1'b1 || cpsr[6] !== 1'b1 || cpsr[4:0] !== MODE_SVC) begin
      $fatal(1, "reset CPSR expected SVC with I/F masked, got %08x", cpsr);
    end

    write_reg(MODE_SVC, 4'd0, 32'h1111_0000);
    read_expect(MODE_IRQ, 4'd0, 32'h1111_0000);

    write_reg(MODE_SVC, 4'd13, 32'hAAAA_000D);
    write_reg(MODE_IRQ, 4'd13, 32'hBBBB_000D);
    write_reg(MODE_SYS, 4'd13, 32'hCCCC_000D);
    read_expect(MODE_SVC, 4'd13, 32'hAAAA_000D);
    read_expect(MODE_IRQ, 4'd13, 32'hBBBB_000D);
    read_expect(MODE_USR, 4'd13, 32'hCCCC_000D);
    read_expect(MODE_SYS, 4'd13, 32'hCCCC_000D);

    write_user_reg(MODE_SVC, 4'd13, 32'hDDDD_000D);
    read_expect(MODE_USR, 4'd13, 32'hDDDD_000D);
    read_expect(MODE_SVC, 4'd13, 32'hAAAA_000D);
    read_c_user_expect(MODE_SVC, 4'd13, 32'hDDDD_000D);

    write_reg(MODE_USR, 4'd8, 32'h0000_0008);
    write_reg(MODE_FIQ, 4'd8, 32'hF1F0_0008);
    read_expect(MODE_USR, 4'd8, 32'h0000_0008);
    read_expect(MODE_FIQ, 4'd8, 32'hF1F0_0008);

    write_spsr(MODE_IRQ, 32'h1234_5678);
    write_spsr(MODE_SVC, 32'hA5A5_5A5A);
    spsr_expect(MODE_IRQ, 32'h1234_5678);
    spsr_expect(MODE_SVC, 32'hA5A5_5A5A);
    spsr_expect(MODE_USR, 32'h0000_0000);

    read_expect(MODE_SVC, 4'd15, 32'h0800_0008);

    cpsr_wdata = 32'hF000_001F;
    cpsr_we = 1'b1;
    tick();
    cpsr_we = 1'b0;
    if (cpsr !== 32'hF000_001F) begin
      $fatal(1, "CPSR write expected f000001f got %08x", cpsr);
    end

    $display("tb_arm7tdmi_regfile passed");
    $finish;
  end
endmodule
