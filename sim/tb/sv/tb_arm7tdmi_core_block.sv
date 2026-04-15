`timescale 1ns/1ps

module tb_arm7tdmi_core_block
  import arm7tdmi_pkg::*;
;
  logic clk;
  logic rst_n;
  logic [31:0] bus_addr;
  logic bus_valid;
  logic bus_write;
  arm_bus_size_t bus_size;
  arm_bus_cycle_t bus_cycle;
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

  logic [31:0] mem0;
  logic [31:0] mem1;
  logic [31:0] mem2;
  int base_seen;
  int r1_seen;
  int r2_seen;
  int r3_seen;
  int r7_seen;
  int r7_wb_seen;
  int r4_seen;
  int r5_seen;
  int r6_seen;
  int r0_wb_seen;
  int stm_seen;
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
      32'h0000_0000: bus_rdata = 32'hE3A0_0080; // MOV r0, #0x80
      32'h0000_0004: bus_rdata = 32'hE3A0_1011; // MOV r1, #0x11
      32'h0000_0008: bus_rdata = 32'hE3A0_2022; // MOV r2, #0x22
      32'h0000_000C: bus_rdata = 32'hE3A0_3033; // MOV r3, #0x33
      32'h0000_0010: bus_rdata = 32'hE8A0_000E; // STMIA r0!, {r1-r3}
      32'h0000_0014: bus_rdata = 32'hE3A0_7080; // MOV r7, #0x80
      32'h0000_0018: bus_rdata = 32'hE8B7_0070; // LDMIA r7!, {r4-r6}
      32'h0000_001C: bus_rdata = 32'hEAFF_FFFE; // B .
      32'h0000_0080: bus_rdata = mem0;
      32'h0000_0084: bus_rdata = mem1;
      32'h0000_0088: bus_rdata = mem2;
      default:       bus_rdata = 32'hE1A0_0000; // MOV r0, r0
    endcase
  end

  always_ff @(posedge clk) begin
    if (bus_valid && bus_write) begin
      if (bus_size !== BUS_SIZE_WORD || bus_cycle !== BUS_CYCLE_NONSEQ) begin
        $fatal(1, "STMIA expected word nonseq transfer");
      end

      unique case (bus_addr)
        32'h0000_0080: begin
          if (bus_wdata !== 32'h0000_0011) begin
            $fatal(1, "STMIA r1 store mismatch: %08x", bus_wdata);
          end
          mem0 <= bus_wdata;
          stm_seen <= stm_seen + 1;
        end
        32'h0000_0084: begin
          if (bus_wdata !== 32'h0000_0022) begin
            $fatal(1, "STMIA r2 store mismatch: %08x", bus_wdata);
          end
          mem1 <= bus_wdata;
          stm_seen <= stm_seen + 1;
        end
        32'h0000_0088: begin
          if (bus_wdata !== 32'h0000_0033) begin
            $fatal(1, "STMIA r3 store mismatch: %08x", bus_wdata);
          end
          mem2 <= bus_wdata;
          stm_seen <= stm_seen + 1;
        end
        default: begin
          $fatal(1, "unexpected block store address %08x", bus_addr);
        end
      endcase
    end
  end

  initial begin
    rst_n = 1'b0;
    bus_ready = 1'b1;
    mem0 = 32'hCAFE_0000;
    mem1 = 32'hCAFE_0001;
    mem2 = 32'hCAFE_0002;
    base_seen = 0;
    r1_seen = 0;
    r2_seen = 0;
    r3_seen = 0;
    r7_seen = 0;
    r7_wb_seen = 0;
    r4_seen = 0;
    r5_seen = 0;
    r6_seen = 0;
    r0_wb_seen = 0;
    stm_seen = 0;
    loop_seen = 0;

    repeat (2) @(posedge clk);
    rst_n = 1'b1;

    for (int cycle = 0; cycle < 100; cycle++) begin
      @(posedge clk);
      #1;

      if (unsupported) begin
        $fatal(1, "unexpected unsupported instruction at pc=%08x", debug_pc);
      end

      if (debug_reg_we && debug_reg_waddr == 4'd0 && debug_reg_wdata == 32'h0000_0080) begin
        base_seen++;
      end
      if (debug_reg_we && debug_reg_waddr == 4'd1 && debug_reg_wdata == 32'h0000_0011) begin
        r1_seen++;
      end
      if (debug_reg_we && debug_reg_waddr == 4'd2 && debug_reg_wdata == 32'h0000_0022) begin
        r2_seen++;
      end
      if (debug_reg_we && debug_reg_waddr == 4'd3 && debug_reg_wdata == 32'h0000_0033) begin
        r3_seen++;
      end
      if (debug_reg_we && debug_reg_waddr == 4'd0 && debug_reg_wdata == 32'h0000_008C) begin
        r0_wb_seen++;
      end
      if (debug_reg_we && debug_reg_waddr == 4'd7 && debug_reg_wdata == 32'h0000_0080) begin
        r7_seen++;
      end
      if (debug_reg_we && debug_reg_waddr == 4'd7 && debug_reg_wdata == 32'h0000_008C) begin
        r7_wb_seen++;
      end
      if (debug_reg_we && debug_reg_waddr == 4'd4 && debug_reg_wdata == 32'h0000_0011) begin
        r4_seen++;
      end
      if (debug_reg_we && debug_reg_waddr == 4'd5 && debug_reg_wdata == 32'h0000_0022) begin
        r5_seen++;
      end
      if (debug_reg_we && debug_reg_waddr == 4'd6 && debug_reg_wdata == 32'h0000_0033) begin
        r6_seen++;
      end
      if (retired && debug_pc == 32'h0000_001C) begin
        loop_seen++;
      end
    end

    if (base_seen != 1 || r1_seen != 1 || r2_seen != 1 || r3_seen != 1) begin
      $fatal(1, "expected setup writes once, saw base=%0d r1=%0d r2=%0d r3=%0d",
             base_seen, r1_seen, r2_seen, r3_seen);
    end

    if (stm_seen != 3) begin
      $fatal(1, "expected three STMIA stores, saw %0d", stm_seen);
    end

    if (r0_wb_seen != 1 || r7_seen != 1 || r7_wb_seen != 1) begin
      $fatal(1, "expected block writeback, saw r0_wb=%0d r7=%0d r7_wb=%0d",
             r0_wb_seen, r7_seen, r7_wb_seen);
    end

    if (r4_seen != 1 || r5_seen != 1 || r6_seen != 1) begin
      $fatal(1, "expected LDMIA loads once, saw r4=%0d r5=%0d r6=%0d",
             r4_seen, r5_seen, r6_seen);
    end

    if (loop_seen < 2) begin
      $fatal(1, "expected branch loop to retire at least twice, saw %0d", loop_seen);
    end

    $display("tb_arm7tdmi_core_block passed");
    $finish;
  end
endmodule
