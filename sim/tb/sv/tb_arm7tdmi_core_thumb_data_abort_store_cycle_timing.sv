`timescale 1ns/1ps

module tb_arm7tdmi_core_thumb_data_abort_store_cycle_timing
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
  /* verilator lint_off UNUSEDSIGNAL */
  logic [31:0] debug_cpsr;
  /* verilator lint_on UNUSEDSIGNAL */
  logic debug_reg_we;
  logic [3:0] debug_reg_waddr;
  logic [31:0] debug_reg_wdata;
  logic retired;
  logic unsupported;

  logic [31:0] data_word;
  int sim_cycle;
  int fetch_24;
  int fetch_10;
  int fetch_14;
  int fetch_18;
  int int_cycles_seen;
  int lr_seen;
  int cpsr_seen;
  int spsr_seen;
  int aborted_store_seen;
  int loop_seen;
  logic [31:0] last_r0_write;
  logic [31:0] last_r1_write;
  logic [31:0] last_lr_write;

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
      32'h0000_0010: bus_rdata = 32'hE10F_0000; // MRS r0, CPSR
      32'h0000_0014: bus_rdata = 32'hE14F_1000; // MRS r1, SPSR
      32'h0000_0018: bus_rdata = 32'hEAFF_FFFE; // B .
      32'h0000_0040: bus_rdata = 32'hE3A0_6021; // MOV r6, #0x21
      32'h0000_0044: bus_rdata = 32'hE12F_FF16; // BX r6
      32'h0000_0020: bus_rdata = 32'h0000_2060; // Thumb MOV r0, #0x60
      32'h0000_0022: bus_rdata = 32'h0000_212A; // Thumb MOV r1, #0x2a
      32'h0000_0024: bus_rdata = 32'h0000_6041; // Thumb STR r1, [r0, #4]
      32'h0000_0064: bus_rdata = data_word;
      default:       bus_rdata = 32'hE1A0_0000;
    endcase
  end

  assign bus_abort = bus_valid && bus_write && (bus_addr == 32'h0000_0064);

  always_ff @(posedge clk) begin
    if (bus_valid && bus_write) begin
      if (bus_addr !== 32'h0000_0064 || bus_size !== BUS_SIZE_WORD || bus_wdata !== 32'h0000_002A) begin
        $fatal(1, "unexpected Thumb store-abort-cycle write addr=%08x size=%0d data=%08x",
               bus_addr, bus_size, bus_wdata);
      end
      aborted_store_seen <= aborted_store_seen + 1;
    end
  end

  initial begin
    rst_n = 1'b0;
    bus_ready = 1'b1;
    data_word = 32'hCAFE_F00D;
    sim_cycle = 0;
    fetch_24 = -1;
    fetch_10 = -1;
    fetch_14 = -1;
    fetch_18 = -1;
    int_cycles_seen = 0;
    lr_seen = 0;
    cpsr_seen = 0;
    spsr_seen = 0;
    aborted_store_seen = 0;
    loop_seen = 0;
    last_r0_write = 32'hFFFF_FFFF;
    last_r1_write = 32'hFFFF_FFFF;
    last_lr_write = 32'hFFFF_FFFF;

    repeat (2) @(posedge clk);
    rst_n = 1'b1;

    for (int cycle = 0; cycle < 100; cycle++) begin
      @(posedge clk);
      #1;
      sim_cycle++;

      if (unsupported) begin
        $fatal(1, "unexpected unsupported instruction at pc=%08x", debug_pc);
      end

      if (bus_valid) begin
        if (!(bus_size inside {BUS_SIZE_HALF, BUS_SIZE_WORD})) begin
          $fatal(1, "thumb store abort timing saw invalid size");
        end
        if (!(bus_cycle inside {BUS_CYCLE_NONSEQ, BUS_CYCLE_SEQ})) begin
          $fatal(1, "thumb store abort timing bus_valid expected seq/nonseq, got %0d", bus_cycle);
        end
        if (bus_addr == 32'h0000_0024 && fetch_24 < 0) fetch_24 = sim_cycle;
        if (bus_addr == 32'h0000_0010 && fetch_10 < 0) fetch_10 = sim_cycle;
        if (bus_addr == 32'h0000_0014 && fetch_14 < 0) fetch_14 = sim_cycle;
        if (bus_addr == 32'h0000_0018 && fetch_18 < 0) fetch_18 = sim_cycle;
      end else if (bus_cycle == BUS_CYCLE_INT) begin
        int_cycles_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd14) begin
        last_lr_write = debug_reg_wdata;
        if (debug_reg_wdata == 32'h0000_0028) lr_seen++;
      end
      if (debug_reg_we && debug_reg_waddr == 4'd0) begin
        last_r0_write = debug_reg_wdata;
        if (debug_reg_wdata == 32'h0000_00D7) cpsr_seen++;
      end
      if (debug_reg_we && debug_reg_waddr == 4'd1) begin
        last_r1_write = debug_reg_wdata;
        if (debug_reg_wdata == 32'h0000_00F3) spsr_seen++;
      end
      if (retired && debug_pc == 32'h0000_0018) loop_seen++;
    end

    if ((fetch_24 < 0) || (fetch_10 < 0) || (fetch_14 < 0) || (fetch_18 < 0)) begin
      $fatal(1, "missing Thumb store-abort timing fetch timestamps");
    end

    if ((fetch_10 - fetch_24) != 4) begin
      $fatal(1, "Thumb store abort should redirect after the memory abort path in current timing mode, saw %0d",
             fetch_10 - fetch_24);
    end

    if (int_cycles_seen < 1) begin
      $fatal(1, "expected visible Thumb store-abort internal cycle, saw %0d", int_cycles_seen);
    end

    if (lr_seen != 1 || cpsr_seen != 1 || spsr_seen != 1 || aborted_store_seen != 1) begin
      $fatal(1, "unexpected Thumb store-abort timing observations lr=%0d cpsr=%0d spsr=%0d store=%0d last_lr=%08x last_r0=%08x last_r1=%08x final_cpsr=%08x",
             lr_seen, cpsr_seen, spsr_seen, aborted_store_seen,
             last_lr_write, last_r0_write, last_r1_write, debug_cpsr);
    end

    if (debug_cpsr != 32'h0000_00D7) begin
      $fatal(1, "expected Thumb store-abort timing to enter ABT with F masked, got %08x", debug_cpsr);
    end

    if (data_word != 32'hCAFE_F00D) begin
      $fatal(1, "Thumb aborted store changed memory to %08x", data_word);
    end

    if (loop_seen < 2) begin
      $fatal(1, "expected Thumb store-abort timing loop to retire, saw %0d", loop_seen);
    end

    $display("tb_arm7tdmi_core_thumb_data_abort_store_cycle_timing passed");
    $finish;
  end
endmodule
