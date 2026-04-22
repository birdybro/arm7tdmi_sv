`timescale 1ns/1ps

module tb_arm7tdmi_core_thumb_interrupt_cycle_timing
  import arm7tdmi_pkg::*;
;
  logic clk;
  logic rst_n;
  logic irq;
  logic fiq;
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
  logic [31:0] debug_pc;
  /* verilator lint_off UNUSEDSIGNAL */
  logic [31:0] debug_cpsr;
  /* verilator lint_on UNUSEDSIGNAL */
  logic debug_reg_we;
  logic [3:0] debug_reg_waddr;
  logic [31:0] debug_reg_wdata;
  logic retired;
  logic unsupported;

  logic fiq_scenario;

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
    .bus_abort_i(1'b0),
    .irq_i(irq),
    .fiq_i(fiq),
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
    bus_rdata = 32'hE1A0_0000;
    unique case (bus_addr)
      32'h0000_0000: bus_rdata = 32'hE321_F013; // MSR CPSR_c, #0x13
      32'h0000_0004: bus_rdata = 32'hEA00_000D; // B 0x40
      32'h0000_0018: bus_rdata = fiq_scenario ? 32'hE1A0_0000 : 32'hE10F_0000;
      32'h0000_001C: bus_rdata = fiq_scenario ? 32'hE10F_0000 : 32'hE14F_1000;
      32'h0000_0020: bus_rdata = fiq_scenario ? 32'hE14F_1000 : 32'hEAFF_FFFE;
      32'h0000_0024: bus_rdata = 32'hEAFF_FFFE;
      32'h0000_0040: bus_rdata = 32'hE3A0_6061; // MOV r6, #0x61
      32'h0000_0044: bus_rdata = 32'hE12F_FF16; // BX r6
      32'h0000_0060: bus_rdata = 32'h0000_212A; // Thumb MOV r1, #0x2a
      32'h0000_0062: bus_rdata = 32'h0000_3101; // Thumb ADD r1, #1
      32'h0000_0064: bus_rdata = 32'h0000_292B; // Thumb CMP r1, #0x2b
      32'h0000_0066: bus_rdata = 32'h0000_E7FE; // Thumb B .
      default: begin
      end
    endcase
  end

  task automatic run_case(
      input logic use_fiq,
      input logic [31:0] expected_cpsr,
      input logic [31:0] expected_spsr,
      input logic [31:0] vector_addr,
      input logic [31:0] loop_pc
  );
    int sim_cycle;
    int trigger_cycle;
    int fetch_vector;
    int int_cycles_seen;
    int lr_seen;
    int cpsr_seen;
    int spsr_seen;
    int loop_seen;
    int trigger_retired_seen;
    logic [31:0] last_bus_addr;
    logic [31:0] last_pc;
    logic [3:0] last_reg_waddr;
    logic [31:0] last_reg_wdata;
    logic [31:0] last_lr_write;

    fiq_scenario = use_fiq;
    irq = 1'b0;
    fiq = 1'b0;
    rst_n = 1'b0;
    bus_ready = 1'b1;
    sim_cycle = 0;
    trigger_cycle = -1;
    fetch_vector = -1;
    int_cycles_seen = 0;
    lr_seen = 0;
    cpsr_seen = 0;
    spsr_seen = 0;
    loop_seen = 0;
    trigger_retired_seen = 0;
    last_bus_addr = 32'hFFFF_FFFF;
    last_pc = 32'hFFFF_FFFF;
    last_reg_waddr = 4'hF;
    last_reg_wdata = 32'hFFFF_FFFF;
    last_lr_write = 32'hFFFF_FFFF;

    repeat (2) @(posedge clk);
    rst_n = 1'b1;

    for (int cycle = 0; cycle < 100; cycle++) begin
      @(posedge clk);
      #1;
      sim_cycle++;
      last_pc = debug_pc;

      if (retired && debug_pc == 32'h0000_0066 && debug_cpsr[5]) begin
        trigger_retired_seen++;
        if (trigger_cycle < 0) trigger_cycle = sim_cycle;
        irq = 1'b1;
        fiq = use_fiq;
      end

      if (unsupported) begin
        $fatal(1, "unexpected unsupported instruction at pc=%08x cpsr=%08x", debug_pc, debug_cpsr);
      end

      if (bus_write || bus_wdata !== 32'h0000_0000) begin
        $fatal(1, "Thumb interrupt timing test should not write memory");
      end

      if (bus_valid) begin
        last_bus_addr = bus_addr;
        if (!(bus_size inside {BUS_SIZE_HALF, BUS_SIZE_WORD})) begin
          $fatal(1, "Thumb interrupt timing saw invalid bus size");
        end
        if (!(bus_cycle inside {BUS_CYCLE_NONSEQ, BUS_CYCLE_SEQ})) begin
          $fatal(1, "Thumb interrupt timing saw invalid bus cycle");
        end

        if ((bus_addr == vector_addr) && (fetch_vector < 0)) begin
          fetch_vector = sim_cycle;
        end
      end else if (bus_cycle == BUS_CYCLE_INT) begin
        int_cycles_seen++;
      end

      if (debug_reg_we) begin
        last_reg_waddr = debug_reg_waddr;
        last_reg_wdata = debug_reg_wdata;
        if (debug_reg_waddr == 4'd14) last_lr_write = debug_reg_wdata;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd14) begin
        lr_seen++;
      end
      if (debug_reg_we && debug_reg_waddr == 4'd0 && debug_reg_wdata == expected_cpsr) begin
        cpsr_seen++;
      end
      if (debug_reg_we && debug_reg_waddr == 4'd1 && debug_reg_wdata == expected_spsr) begin
        spsr_seen++;
      end
      if (retired && debug_pc == loop_pc) begin
        loop_seen++;
      end
    end

    if (trigger_cycle < 0 || fetch_vector < 0) begin
      $fatal(1, "missing Thumb interrupt timing fetch timestamps trig=%0d vec=%0d trig_retired=%0d last_bus=%08x last_pc=%08x last_w=%0d:%08x final_cpsr=%08x",
             trigger_cycle, fetch_vector, trigger_retired_seen, last_bus_addr, last_pc,
             last_reg_waddr, last_reg_wdata, debug_cpsr);
    end

    if ((fetch_vector - trigger_cycle) != 2) begin
      $fatal(1, "Thumb interrupt should incur one internal cycle before vector fetch, saw %0d",
             fetch_vector - trigger_cycle);
    end

    if (int_cycles_seen < 1) begin
      $fatal(1, "expected visible Thumb interrupt internal cycle, saw %0d", int_cycles_seen);
    end

    if (lr_seen != 1 || cpsr_seen != 1 || spsr_seen != 1) begin
      $fatal(1, "unexpected Thumb interrupt timing observations lr=%0d cpsr=%0d spsr=%0d last_lr=%08x final_cpsr=%08x",
             lr_seen, cpsr_seen, spsr_seen, last_lr_write, debug_cpsr);
    end

    if (loop_seen < 2) begin
      $fatal(1, "expected Thumb interrupt loop to retire at least twice, saw %0d", loop_seen);
    end

    irq = 1'b0;
    fiq = 1'b0;
  endtask

  initial begin
    irq = 1'b0;
    fiq = 1'b0;
    fiq_scenario = 1'b0;
    bus_ready = 1'b1;
    rst_n = 1'b0;

    run_case(1'b0, 32'h0000_0092, 32'h0000_0033, 32'h0000_0018, 32'h0000_0020);
    run_case(1'b1, 32'h0000_00D1, 32'h0000_0033, 32'h0000_001C, 32'h0000_0024);

    $display("tb_arm7tdmi_core_thumb_interrupt_cycle_timing passed");
    $finish;
  end
endmodule
