`timescale 1ns/1ps

module tb_arm7tdmi_core_thumb_prefetch_abort_cycle_timing
  import arm7tdmi_pkg::*;
;
  logic clk;
  logic rst_n;
  logic [31:0] bus_addr;
  logic bus_valid;
  logic bus_write;
  arm_bus_size_t bus_size;
  arm_bus_cycle_t bus_cycle;
  /* verilator lint_off UNUSEDSIGNAL */
  logic [31:0] bus_wdata;
  /* verilator lint_on UNUSEDSIGNAL */
  logic [31:0] bus_rdata;
  logic bus_ready;
  logic bus_abort;
  logic [31:0] debug_pc;
  /* verilator lint_off UNUSEDSIGNAL */
  logic [31:0] debug_cpsr;
  /* verilator lint_on UNUSEDSIGNAL */
  logic debug_reg_we;
  logic [3:0] debug_reg_waddr;
  logic [31:0] debug_reg_wdata;
  logic retired;
  logic unsupported;

  int sim_cycle;
  int fetch_2a;
  int fetch_0c;
  int fetch_10;
  int fetch_14;
  int int_cycles_seen;
  int aborted_write_seen;
  int lr_seen;
  int cpsr_seen;
  int spsr_seen;
  int loop_seen;
  logic [31:0] last_bus_addr;
  logic [3:0] last_reg_waddr;
  logic [31:0] last_reg_wdata;

  arm7tdmi_core #(
    .TIMING_MODE(TIMING_ARM7TDMI_CYCLE)
  ) dut (
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
    .bus_abort_i(bus_abort),
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
      32'h0000_0000: bus_rdata = 32'hEA00_000E; // B 0x40
      32'h0000_000C: bus_rdata = 32'hE10F_0000; // MRS r0, CPSR
      32'h0000_0010: bus_rdata = 32'hE14F_1000; // MRS r1, SPSR
      32'h0000_0014: bus_rdata = 32'hEAFF_FFFE; // B .
      32'h0000_0040: bus_rdata = 32'hE3A0_6021; // MOV r6, #0x21
      32'h0000_0044: bus_rdata = 32'hE12F_FF16; // BX r6
      32'h0000_0028: bus_rdata = 32'h0000_46C0; // Thumb NOP
      32'h0000_002A: bus_rdata = 32'h0000_202A; // Thumb MOV r0, #0x2a, aborted before execute
      default:       bus_rdata = 32'hE1A0_0000;
    endcase
  end

  assign bus_abort = bus_valid && !bus_write && (bus_addr == 32'h0000_002A);

  initial begin
    rst_n = 1'b0;
    bus_ready = 1'b1;
    sim_cycle = 0;
    fetch_2a = -1;
    fetch_0c = -1;
    fetch_10 = -1;
    fetch_14 = -1;
    int_cycles_seen = 0;
    aborted_write_seen = 0;
    lr_seen = 0;
    cpsr_seen = 0;
    spsr_seen = 0;
    loop_seen = 0;
    last_bus_addr = 32'hFFFF_FFFF;
    last_reg_waddr = 4'hF;
    last_reg_wdata = 32'hFFFF_FFFF;

    repeat (2) @(posedge clk);
    rst_n = 1'b1;

    for (int cycle = 0; cycle < 90; cycle++) begin
      @(posedge clk);
      #1;
      sim_cycle++;

      if (unsupported) begin
        $fatal(1, "unexpected unsupported instruction at pc=%08x cpsr=%08x", debug_pc, debug_cpsr);
      end

      if (bus_write || bus_wdata !== 32'h0000_0000) begin
        $fatal(1, "Thumb prefetch abort timing should not write memory");
      end

      if (bus_valid) begin
        last_bus_addr = bus_addr;
        if (!(bus_size inside {BUS_SIZE_HALF, BUS_SIZE_WORD})) begin
          $fatal(1, "Thumb prefetch abort timing saw invalid bus size");
        end
        if (!(bus_cycle inside {BUS_CYCLE_NONSEQ, BUS_CYCLE_SEQ})) begin
          $fatal(1, "Thumb prefetch abort timing saw invalid bus cycle");
        end

        unique case (bus_addr)
          32'h0000_002A: if (fetch_2a < 0) fetch_2a = sim_cycle;
          32'h0000_000C: if (fetch_0c < 0) fetch_0c = sim_cycle;
          32'h0000_0010: if (fetch_10 < 0) fetch_10 = sim_cycle;
          32'h0000_0014: if (fetch_14 < 0) fetch_14 = sim_cycle;
          default: begin
          end
        endcase
      end else if (bus_cycle == BUS_CYCLE_INT) begin
        int_cycles_seen++;
      end

      if (debug_reg_we) begin
        last_reg_waddr = debug_reg_waddr;
        last_reg_wdata = debug_reg_wdata;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd0 && debug_reg_wdata == 32'h0000_002A) begin
        aborted_write_seen++;
      end
      if (debug_reg_we && debug_reg_waddr == 4'd14) begin
        lr_seen++;
      end
      if (debug_reg_we && debug_reg_waddr == 4'd0 && debug_reg_wdata == 32'h4000_00D7) begin
        cpsr_seen++;
      end
      if (debug_reg_we && debug_reg_waddr == 4'd1 && debug_reg_wdata == 32'h4000_00F3) begin
        spsr_seen++;
      end
      if (retired && debug_pc == 32'h0000_0014 && debug_cpsr == 32'h4000_00D7) begin
        loop_seen++;
      end
    end

    if (fetch_2a < 0 || fetch_0c < 0 || fetch_10 < 0 || fetch_14 < 0) begin
      $fatal(1, "missing Thumb prefetch-abort timing fetch timestamps 2a=%0d 0c=%0d 10=%0d 14=%0d last_bus=%08x last_w=%0d:%08x final_cpsr=%08x",
             fetch_2a, fetch_0c, fetch_10, fetch_14, last_bus_addr,
             last_reg_waddr, last_reg_wdata, debug_cpsr);
    end

    if ((fetch_0c - fetch_2a) != 2) begin
      $fatal(1, "Thumb prefetch abort should redirect on the next fetch slot, saw %0d",
             fetch_0c - fetch_2a);
    end

    if (aborted_write_seen != 0 || lr_seen != 1 || cpsr_seen != 1 || spsr_seen != 1) begin
      $fatal(1, "unexpected Thumb prefetch-abort timing observations aborted=%0d lr=%0d cpsr=%0d spsr=%0d last_bus=%08x last_w=%0d:%08x final_cpsr=%08x",
             aborted_write_seen, lr_seen, cpsr_seen, spsr_seen, last_bus_addr,
             last_reg_waddr, last_reg_wdata, debug_cpsr);
    end

    if (loop_seen < 2) begin
      $fatal(1, "expected Thumb prefetch-abort loop to retire at least twice, saw %0d", loop_seen);
    end

    $display("tb_arm7tdmi_core_thumb_prefetch_abort_cycle_timing passed");
    $finish;
  end
endmodule
