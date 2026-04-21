`timescale 1ns/1ps

module tb_arm7tdmi_core_thumb_data_abort_store
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
  logic bus_abort;
  logic [31:0] debug_pc;
  logic [31:0] debug_cpsr;
  logic debug_reg_we;
  logic [3:0] debug_reg_waddr;
  logic [31:0] debug_reg_wdata;
  logic retired;
  logic unsupported;

  logic [31:0] data_word;
  int lr_seen;
  int cpsr_seen;
  int spsr_seen;
  int aborted_store_seen;
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
      32'h0000_0004: bus_rdata = 32'hE10F_0000; // MRS r0, CPSR
      32'h0000_0008: bus_rdata = 32'hE14F_1000; // MRS r1, SPSR
      32'h0000_000C: bus_rdata = 32'hEAFF_FFFE; // B .
      32'h0000_0040: bus_rdata = 32'hE3A0_6021; // MOV r6, #0x21
      32'h0000_0044: bus_rdata = 32'hE12F_FF16; // BX r6
      32'h0000_0020: bus_rdata = 32'h0000_2040; // Thumb MOV r0, #0x40
      32'h0000_0022: bus_rdata = 32'h0000_212A; // Thumb MOV r1, #0x2a
      32'h0000_0024: bus_rdata = 32'h0000_6041; // Thumb STR r1, [r0, #4]
      32'h0000_0044: bus_rdata = data_word;
      default:       bus_rdata = 32'hE1A0_0000;
    endcase
  end

  assign bus_abort = bus_valid && bus_write && (bus_addr == 32'h0000_0044);

  always_ff @(posedge clk) begin
    if (bus_valid && bus_write) begin
      if (bus_addr !== 32'h0000_0044 || bus_size !== BUS_SIZE_WORD || bus_wdata !== 32'h0000_002A) begin
        $fatal(1, "unexpected Thumb data-abort-store write addr=%08x size=%0d data=%08x",
               bus_addr, bus_size, bus_wdata);
      end
      aborted_store_seen <= aborted_store_seen + 1;
    end
  end

  initial begin
    rst_n = 1'b0;
    bus_ready = 1'b1;
    data_word = 32'hCAFE_F00D;
    lr_seen = 0;
    cpsr_seen = 0;
    spsr_seen = 0;
    aborted_store_seen = 0;
    loop_seen = 0;

    repeat (2) @(posedge clk);
    rst_n = 1'b1;

    for (int cycle = 0; cycle < 100; cycle++) begin
      @(posedge clk);
      #1;

      if (bus_valid && !(bus_size inside {BUS_SIZE_HALF, BUS_SIZE_WORD})) begin
        $fatal(1, "thumb data abort store saw invalid bus size");
      end
      if (bus_valid && !(bus_cycle inside {BUS_CYCLE_NONSEQ, BUS_CYCLE_SEQ})) begin
        $fatal(1, "thumb data abort store saw invalid cycle class");
      end
      if (unsupported) begin
        $fatal(1, "unexpected unsupported instruction at pc=%08x cpsr=%08x", debug_pc, debug_cpsr);
      end

      if (debug_reg_we && debug_reg_waddr == 4'd14 && debug_reg_wdata == 32'h0000_0028) lr_seen++;
      if (debug_reg_we && debug_reg_waddr == 4'd0 && debug_reg_wdata == 32'h0000_0097) cpsr_seen++;
      if (debug_reg_we && debug_reg_waddr == 4'd1 && debug_reg_wdata == 32'h0000_00F3) spsr_seen++;
      if (retired && debug_pc == 32'h0000_000C && debug_cpsr == 32'h0000_0097) loop_seen++;
    end

    if (lr_seen != 1 || cpsr_seen != 1 || spsr_seen != 1) begin
      $fatal(1, "expected one Thumb store-abort context write/read, saw lr=%0d cpsr=%0d spsr=%0d",
             lr_seen, cpsr_seen, spsr_seen);
    end
    if (aborted_store_seen != 1) begin
      $fatal(1, "expected one Thumb aborted store request, saw %0d", aborted_store_seen);
    end
    if (data_word != 32'hCAFE_F00D) begin
      $fatal(1, "Thumb aborted store changed memory to %08x", data_word);
    end
    if (debug_cpsr != 32'h0000_0097) begin
      $fatal(1, "expected Thumb store data abort to enter ABT, got %08x", debug_cpsr);
    end
    if (loop_seen < 2) begin
      $fatal(1, "expected Thumb data-abort-store vector loop to retire, saw %0d", loop_seen);
    end

    $display("tb_arm7tdmi_core_thumb_data_abort_store passed");
    $finish;
  end
endmodule
