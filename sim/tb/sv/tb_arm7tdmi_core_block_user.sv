`timescale 1ns/1ps

module tb_arm7tdmi_core_block_user
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
  logic [31:0] debug_cpsr;
  logic debug_reg_we;
  logic [3:0] debug_reg_waddr;
  logic [31:0] debug_reg_wdata;
  logic retired;
  logic unsupported;

  logic [31:0] mem_user_sp;
  logic [31:0] mem_user_lr;
  int stm_user_seen;
  int user_sp_seen;
  int user_lr_seen;
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
      32'h0000_0000: bus_rdata = 32'hE321_F01F; // MSR CPSR_c, #0x1f
      32'h0000_0004: bus_rdata = 32'hE3A0_00A0; // MOV r0, #0xa0
      32'h0000_0008: bus_rdata = 32'hE3A0_D070; // MOV sp, #0x70
      32'h0000_000C: bus_rdata = 32'hE3A0_E080; // MOV lr, #0x80
      32'h0000_0010: bus_rdata = 32'hE321_F013; // MSR CPSR_c, #0x13
      32'h0000_0014: bus_rdata = 32'hE3A0_D011; // MOV sp, #0x11
      32'h0000_0018: bus_rdata = 32'hE3A0_E022; // MOV lr, #0x22
      32'h0000_001C: bus_rdata = 32'hE8C0_6000; // STMIA r0, {sp,lr}^
      32'h0000_0020: bus_rdata = 32'hE3A0_00A8; // MOV r0, #0xa8
      32'h0000_0024: bus_rdata = 32'hE8D0_6000; // LDMIA r0, {sp,lr}^
      32'h0000_0028: bus_rdata = 32'hE321_F01F; // MSR CPSR_c, #0x1f
      32'h0000_002C: bus_rdata = 32'hE1A0_100D; // MOV r1, sp
      32'h0000_0030: bus_rdata = 32'hE1A0_200E; // MOV r2, lr
      32'h0000_0034: bus_rdata = 32'hEAFF_FFFE; // B .
      32'h0000_00A0: bus_rdata = mem_user_sp;
      32'h0000_00A4: bus_rdata = mem_user_lr;
      32'h0000_00A8: bus_rdata = 32'h0000_0055;
      32'h0000_00AC: bus_rdata = 32'h0000_0066;
      default:       bus_rdata = 32'hE1A0_0000; // MOV r0, r0
    endcase
  end

  always_ff @(posedge clk) begin
    if (bus_valid && bus_write) begin
      if (bus_size !== BUS_SIZE_WORD || bus_cycle !== BUS_CYCLE_NONSEQ) begin
        $fatal(1, "user-bank block transfer expected word nonseq stores");
      end

      unique case (bus_addr)
        32'h0000_00A0: begin
          if (bus_wdata !== 32'h0000_0070) begin
            $fatal(1, "STM user-bank SP expected 0x70, got %08x", bus_wdata);
          end
          mem_user_sp <= bus_wdata;
          stm_user_seen <= stm_user_seen + 1;
        end
        32'h0000_00A4: begin
          if (bus_wdata !== 32'h0000_0080) begin
            $fatal(1, "STM user-bank LR expected 0x80, got %08x", bus_wdata);
          end
          mem_user_lr <= bus_wdata;
          stm_user_seen <= stm_user_seen + 1;
        end
        default: begin
          $fatal(1, "unexpected user-bank block store address %08x", bus_addr);
        end
      endcase
    end
  end

  task automatic check_bus_contract;
    logic unused_wdata;
    unused_wdata = ^bus_wdata;

    if (bus_valid && bus_size !== BUS_SIZE_WORD) begin
      $fatal(1, "user-bank block smoke expected word transfers");
    end

    if (bus_valid && bus_cycle !== BUS_CYCLE_NONSEQ && bus_cycle !== BUS_CYCLE_SEQ) begin
      $fatal(1, "user-bank block smoke saw invalid bus cycle");
    end

    if (unsupported) begin
      $fatal(1, "unexpected unsupported instruction at pc=%08x cpsr=%08x", debug_pc, debug_cpsr);
    end
  endtask

  initial begin
    rst_n = 1'b0;
    bus_ready = 1'b1;
    mem_user_sp = 32'hCAFE_0000;
    mem_user_lr = 32'hCAFE_0001;
    stm_user_seen = 0;
    user_sp_seen = 0;
    user_lr_seen = 0;
    loop_seen = 0;

    repeat (2) @(posedge clk);
    rst_n = 1'b1;

    for (int cycle = 0; cycle < 100; cycle++) begin
      @(posedge clk);
      #1;
      check_bus_contract();

      if (debug_reg_we && debug_reg_waddr == 4'd1 && debug_reg_wdata == 32'h0000_0055) begin
        user_sp_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd2 && debug_reg_wdata == 32'h0000_0066) begin
        user_lr_seen++;
      end

      if (retired && debug_pc == 32'h0000_0034) begin
        loop_seen++;
      end
    end

    if (stm_user_seen != 2) begin
      $fatal(1, "expected two user-bank STM stores, saw %0d", stm_user_seen);
    end

    if (user_sp_seen != 1 || user_lr_seen != 1) begin
      $fatal(1, "expected user-bank LDM values once, saw sp=%0d lr=%0d",
             user_sp_seen, user_lr_seen);
    end

    if (loop_seen < 2) begin
      $fatal(1, "expected user-bank block loop to retire at least twice, saw %0d", loop_seen);
    end

    $display("tb_arm7tdmi_core_block_user passed");
    $finish;
  end
endmodule
