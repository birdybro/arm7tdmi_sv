`timescale 1ns/1ps

module tb_arm7tdmi_core_multiply
  import arm7tdmi_pkg::*;
;
  logic clk;
  logic rst_n;
  logic [31:0] bus_addr;
  logic bus_valid;
  logic bus_write;
  arm_bus_size_t bus_size;
  /* verilator lint_off UNUSEDSIGNAL */
  arm_bus_cycle_t bus_cycle;
  /* verilator lint_on UNUSEDSIGNAL */
  logic [31:0] bus_wdata;
  logic [31:0] bus_rdata;
  logic bus_ready;
  logic [31:0] debug_pc;
  /* verilator lint_off UNUSEDSIGNAL */
  logic [31:0] debug_cpsr;
  /* verilator lint_on UNUSEDSIGNAL */
  logic debug_reg_we;
  logic [3:0] debug_reg_waddr;
  logic [31:0] debug_reg_wdata;
  logic retired;
  logic unsupported;

  int r0_seen;
  int r1_seen;
  int r2_seen;
  int r3_seen;
  int r4_seen;
  int r5_seen;
  int r6_seen;
  int r7_seen;
  int r8_seen;
  int r9_seen;
  int r10_seen;
  int r11_seen;
  int zero_flag_seen;
  int loop_seen;

  arm7tdmi_core dut (
    .clk_i(clk),
    .rst_ni(rst_n),
    .bus_addr_o(bus_addr),
    .bus_valid_o(bus_valid),
    .bus_write_o(bus_write),
    .bus_size_o(bus_size),
    .bus_cycle_o(bus_cycle),
    .bus_wdata_o(bus_wdata),
    .bus_rdata_i(bus_rdata),
    .bus_ready_i(bus_ready),
    .irq_i(1'b0),
    .fiq_i(1'b0),
    .debug_pc_o(debug_pc),
    .debug_cpsr_o(debug_cpsr),
    .debug_reg_we_o(debug_reg_we),
    .debug_reg_waddr_o(debug_reg_waddr),
    .debug_reg_wdata_o(debug_reg_wdata),
    .retired_o(retired),
    .unsupported_o(unsupported)
  );

  initial clk = 1'b0;
  always #5 clk = !clk;

  always_comb begin
    unique case (bus_addr)
      32'h0000_0000: bus_rdata = 32'hE3A0_0006; // MOV r0, #6
      32'h0000_0004: bus_rdata = 32'hE3A0_1007; // MOV r1, #7
      32'h0000_0008: bus_rdata = 32'hE002_0190; // MUL r2, r0, r1
      32'h0000_000C: bus_rdata = 32'hE023_2190; // MLA r3, r0, r1, r2
      32'h0000_0010: bus_rdata = 32'hE3A0_4000; // MOV r4, #0
      32'h0000_0014: bus_rdata = 32'hE015_0490; // MULS r5, r0, r4
      32'h0000_0018: bus_rdata = 32'hE087_6190; // UMULL r6, r7, r0, r1
      32'h0000_001C: bus_rdata = 32'hE3E0_8000; // MVN r8, #0
      32'h0000_0020: bus_rdata = 32'hE3A0_9002; // MOV r9, #2
      32'h0000_0024: bus_rdata = 32'hE0CB_A998; // SMULL r10, r11, r8, r9
      32'h0000_0028: bus_rdata = 32'hEAFF_FFFE; // B .
      default:       bus_rdata = 32'hE1A0_0000; // MOV r0, r0
    endcase
  end

  initial begin
    rst_n = 1'b0;
    bus_ready = 1'b1;
    r0_seen = 0;
    r1_seen = 0;
    r2_seen = 0;
    r3_seen = 0;
    r4_seen = 0;
    r5_seen = 0;
    r6_seen = 0;
    r7_seen = 0;
    r8_seen = 0;
    r9_seen = 0;
    r10_seen = 0;
    r11_seen = 0;
    zero_flag_seen = 0;
    loop_seen = 0;

    repeat (2) @(posedge clk);
    rst_n = 1'b1;

    for (int cycle = 0; cycle < 80; cycle++) begin
      @(posedge clk);
      #1;

      if (bus_write || bus_wdata !== 32'h0000_0000) begin
        $fatal(1, "multiply smoke test should not write memory");
      end

      if (bus_valid && bus_size !== BUS_SIZE_WORD) begin
        $fatal(1, "multiply smoke expected word fetches");
      end

      if (unsupported) begin
        $fatal(1, "unexpected unsupported instruction at pc=%08x", debug_pc);
      end

      if (debug_reg_we && debug_reg_waddr == 4'd0 && debug_reg_wdata == 32'h0000_0006) begin
        r0_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd1 && debug_reg_wdata == 32'h0000_0007) begin
        r1_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd2 && debug_reg_wdata == 32'h0000_002A) begin
        r2_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd3 && debug_reg_wdata == 32'h0000_0054) begin
        r3_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd4 && debug_reg_wdata == 32'h0000_0000) begin
        r4_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd5 && debug_reg_wdata == 32'h0000_0000) begin
        r5_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd6 && debug_reg_wdata == 32'h0000_002A) begin
        r6_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd7 && debug_reg_wdata == 32'h0000_0000) begin
        r7_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd8 && debug_reg_wdata == 32'hFFFF_FFFF) begin
        r8_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd9 && debug_reg_wdata == 32'h0000_0002) begin
        r9_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd10 && debug_reg_wdata == 32'hFFFF_FFFE) begin
        r10_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd11 && debug_reg_wdata == 32'hFFFF_FFFF) begin
        r11_seen++;
      end

      if (retired && debug_pc == 32'h0000_0028) begin
        loop_seen++;
      end

      if (debug_cpsr[30]) begin
        zero_flag_seen++;
      end
    end

    if (r0_seen != 1 || r1_seen != 1 || r2_seen != 1 || r3_seen != 1 ||
        r4_seen != 1 || r5_seen != 1 || r6_seen != 1 || r7_seen != 1 ||
        r8_seen != 1 || r9_seen != 1 || r10_seen != 1 || r11_seen != 1) begin
      $fatal(1, "expected one multiply program write each, saw r0=%0d r1=%0d r2=%0d r3=%0d r4=%0d r5=%0d r6=%0d r7=%0d r8=%0d r9=%0d r10=%0d r11=%0d",
             r0_seen, r1_seen, r2_seen, r3_seen, r4_seen, r5_seen,
             r6_seen, r7_seen, r8_seen, r9_seen, r10_seen, r11_seen);
    end

    if (zero_flag_seen == 0) begin
      $fatal(1, "expected MULS zero result to set CPSR Z");
    end

    if (loop_seen < 2) begin
      $fatal(1, "expected branch loop to retire at least twice, saw %0d", loop_seen);
    end

    $display("tb_arm7tdmi_core_multiply passed");
    $finish;
  end
endmodule
