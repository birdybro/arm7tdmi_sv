`timescale 1ns/1ps

module tb_arm7tdmi_core_coprocessor_cycle_timing
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

  logic coproc_valid;
  arm_coproc_op_t coproc_op;
  /* verilator lint_off UNUSEDSIGNAL */
  logic [3:0] coproc_num;
  logic [3:0] coproc_opcode1;
  logic [2:0] coproc_opcode2;
  logic [3:0] coproc_crn;
  logic [3:0] coproc_crd;
  logic [3:0] coproc_crm;
  /* verilator lint_on UNUSEDSIGNAL */
  logic coproc_long;
  logic [31:0] coproc_wdata;
  logic coproc_accept;
  logic coproc_ready;
  logic [31:0] coproc_rdata;
  logic coproc_last;

  logic [31:0] data_word0;
  logic [31:0] data_word1;
  logic [31:0] data_word2;
  logic [31:0] data_word3;
  logic [31:0] cp_regs [0:15];
  logic [1:0] coproc_transfer_index;

  int sim_cycle;
  int fetch_04;
  int fetch_08;
  int fetch_0c;
  int fetch_10;
  int fetch_14;
  int fetch_18;
  int fetch_1c;
  int fetch_20;
  int fetch_24;
  int coproc_internal_cycles;
  int coproc_mem_cycles;
  int mrc_seen;
  int cdp_seen;
  int loop_seen;

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
    .irq_i(1'b0),
    .fiq_i(1'b0),
    .coproc_valid_o(coproc_valid),
    .coproc_op_o(coproc_op),
    .coproc_num_o(coproc_num),
    .coproc_opcode1_o(coproc_opcode1),
    .coproc_opcode2_o(coproc_opcode2),
    .coproc_crn_o(coproc_crn),
    .coproc_crd_o(coproc_crd),
    .coproc_crm_o(coproc_crm),
    .coproc_long_o(coproc_long),
    .coproc_wdata_o(coproc_wdata),
    .coproc_accept_i(coproc_accept),
    .coproc_ready_i(coproc_ready),
    .coproc_rdata_i(coproc_rdata),
    .coproc_last_i(coproc_last),
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
      32'h0000_0000: bus_rdata = 32'hE3A0_0055; // MOV r0, #0x55
      32'h0000_0004: bus_rdata = 32'hEE01_0210; // MCR p2, 0, r0, c1, c0, 0
      32'h0000_0008: bus_rdata = 32'hEE11_1210; // MRC p2, 0, r1, c1, c0, 0
      32'h0000_000C: bus_rdata = 32'hEE11_3200; // CDP p2, 1, c3, c1, c0, 0
      32'h0000_0010: bus_rdata = 32'hEE13_2210; // MRC p2, 1, r2, c3, c0, 0
      32'h0000_0014: bus_rdata = 32'hE3A0_0040; // MOV r0, #0x40
      32'h0000_0018: bus_rdata = 32'hECD0_4202; // LDC p2, c4, [r0], #8
      32'h0000_001C: bus_rdata = 32'hE3A0_0050; // MOV r0, #0x50
      32'h0000_0020: bus_rdata = 32'hECC0_4202; // STC p2, c4, [r0], #8
      32'h0000_0024: bus_rdata = 32'hEAFF_FFFE; // B .
      32'h0000_0040: bus_rdata = data_word0;
      32'h0000_0044: bus_rdata = data_word1;
      32'h0000_0050: bus_rdata = data_word2;
      32'h0000_0054: bus_rdata = data_word3;
      default:       bus_rdata = 32'hE1A0_0000;
    endcase
  end

  always_comb begin
    coproc_accept = 1'b1;
    coproc_ready = coproc_valid;
    coproc_rdata = 32'h0000_0000;
    coproc_last = 1'b1;

    unique case (coproc_op)
      COPROC_OP_MRC: begin
        coproc_rdata = cp_regs[coproc_crn];
      end

      COPROC_OP_LDC: begin
        coproc_last = !coproc_long || (coproc_transfer_index == 2'd1);
      end

      COPROC_OP_STC: begin
        coproc_rdata = cp_regs[coproc_crd + {2'b00, coproc_transfer_index}];
        coproc_last = !coproc_long || (coproc_transfer_index == 2'd1);
      end

      default: begin
      end
    endcase
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      coproc_transfer_index <= 2'd0;
      for (int idx = 0; idx < 16; idx++) begin
        cp_regs[idx] <= 32'h0000_0000;
      end
    end else if (coproc_valid && coproc_accept && coproc_ready) begin
      unique case (coproc_op)
        COPROC_OP_MCR: cp_regs[coproc_crn] <= coproc_wdata;
        COPROC_OP_CDP: cp_regs[coproc_crd] <= cp_regs[coproc_crn] + {28'h0, coproc_opcode1};
        COPROC_OP_LDC: cp_regs[coproc_crd + {2'b00, coproc_transfer_index}] <= coproc_wdata;
        default: begin
        end
      endcase

      if (coproc_op inside {COPROC_OP_LDC, COPROC_OP_STC}) begin
        if (coproc_last) begin
          coproc_transfer_index <= 2'd0;
        end else begin
          coproc_transfer_index <= coproc_transfer_index + 2'd1;
        end
      end else begin
        coproc_transfer_index <= 2'd0;
      end
    end
  end

  always_ff @(posedge clk) begin
    if (bus_valid && bus_write && bus_cycle == BUS_CYCLE_COPROC) begin
      unique case (bus_addr)
        32'h0000_0050: data_word2 <= bus_wdata;
        32'h0000_0054: data_word3 <= bus_wdata;
        default:       $fatal(1, "unexpected coprocessor timing store addr=%08x data=%08x",
                              bus_addr, bus_wdata);
      endcase
    end
  end

  initial begin
    rst_n = 1'b0;
    bus_ready = 1'b1;
    data_word0 = 32'h1122_3344;
    data_word1 = 32'h5566_7788;
    data_word2 = 32'hCAFE_F00D;
    data_word3 = 32'hDEAD_BEEF;
    sim_cycle = 0;
    fetch_04 = -1;
    fetch_08 = -1;
    fetch_0c = -1;
    fetch_10 = -1;
    fetch_14 = -1;
    fetch_18 = -1;
    fetch_1c = -1;
    fetch_20 = -1;
    fetch_24 = -1;
    coproc_internal_cycles = 0;
    coproc_mem_cycles = 0;
    mrc_seen = 0;
    cdp_seen = 0;
    loop_seen = 0;

    repeat (2) @(posedge clk);
    rst_n = 1'b1;

    for (int cycle = 0; cycle < 120; cycle++) begin
      @(posedge clk);
      #1;
      sim_cycle++;

      if (unsupported) begin
        $fatal(1, "unexpected unsupported instruction at pc=%08x cpsr=%08x", debug_pc, debug_cpsr);
      end

      if (bus_valid) begin
        if (!(bus_size inside {BUS_SIZE_WORD})) begin
          $fatal(1, "coprocessor timing expected word bus accesses only");
        end

        if (!(bus_cycle inside {BUS_CYCLE_NONSEQ, BUS_CYCLE_SEQ, BUS_CYCLE_COPROC})) begin
          $fatal(1, "coprocessor timing saw invalid cycle class %0d", bus_cycle);
        end

        unique case (bus_addr)
          32'h0000_0004: if (fetch_04 < 0) fetch_04 = sim_cycle;
          32'h0000_0008: if (fetch_08 < 0) fetch_08 = sim_cycle;
          32'h0000_000C: if (fetch_0c < 0) fetch_0c = sim_cycle;
          32'h0000_0010: if (fetch_10 < 0) fetch_10 = sim_cycle;
          32'h0000_0014: if (fetch_14 < 0) fetch_14 = sim_cycle;
          32'h0000_0018: if (fetch_18 < 0) fetch_18 = sim_cycle;
          32'h0000_001C: if (fetch_1c < 0) fetch_1c = sim_cycle;
          32'h0000_0020: if (fetch_20 < 0) fetch_20 = sim_cycle;
          32'h0000_0024: if (fetch_24 < 0) fetch_24 = sim_cycle;
          32'h0000_0040,
          32'h0000_0044,
          32'h0000_0050,
          32'h0000_0054: begin
            if (bus_cycle != BUS_CYCLE_COPROC) begin
              $fatal(1, "coprocessor memory transfer beat should use coproc cycle, saw %0d",
                     bus_cycle);
            end
            coproc_mem_cycles++;
          end
          default: begin
          end
        endcase
      end else if (bus_cycle == BUS_CYCLE_COPROC) begin
        coproc_internal_cycles++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd1 && debug_reg_wdata == 32'h0000_0055) begin
        mrc_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd2 && debug_reg_wdata == 32'h0000_0056) begin
        cdp_seen++;
      end

      if (retired && debug_pc == 32'h0000_0024) begin
        loop_seen++;
      end
    end

    if ((fetch_04 < 0) || (fetch_08 < 0) || (fetch_0c < 0) || (fetch_10 < 0) ||
        (fetch_14 < 0) || (fetch_18 < 0) || (fetch_1c < 0) || (fetch_20 < 0) ||
        (fetch_24 < 0)) begin
      $fatal(1, "missing coprocessor timing fetch timestamps");
    end

    if ((fetch_08 - fetch_04) != 3) begin
      $fatal(1, "MCR should consume one coprocessor cycle before the next fetch, saw spacing %0d",
             fetch_08 - fetch_04);
    end

    if ((fetch_0c - fetch_08) != 3) begin
      $fatal(1, "MRC should consume one coprocessor cycle before the next fetch, saw spacing %0d",
             fetch_0c - fetch_08);
    end

    if ((fetch_10 - fetch_0c) != 3) begin
      $fatal(1, "CDP should consume one coprocessor cycle before the next fetch, saw spacing %0d",
             fetch_10 - fetch_0c);
    end

    if ((fetch_14 - fetch_10) != 3) begin
      $fatal(1, "second MRC should consume one coprocessor cycle before the next fetch, saw spacing %0d",
             fetch_14 - fetch_10);
    end

    if ((fetch_18 - fetch_14) != 2) begin
      $fatal(1, "plain MOV before LDC should keep two-cycle fetch spacing, saw %0d",
             fetch_18 - fetch_14);
    end

    if ((fetch_1c - fetch_18) != 6) begin
      $fatal(1, "two-beat LDC should stretch fetch spacing to 6 cycles, saw %0d",
             fetch_1c - fetch_18);
    end

    if ((fetch_20 - fetch_1c) != 2) begin
      $fatal(1, "plain MOV before STC should keep two-cycle fetch spacing, saw %0d",
             fetch_20 - fetch_1c);
    end

    if ((fetch_24 - fetch_20) != 7) begin
      $fatal(1, "two-beat STC should stretch fetch spacing to 7 cycles, saw %0d",
             fetch_24 - fetch_20);
    end

    if (coproc_internal_cycles < 8) begin
      $fatal(1, "expected visible coprocessor internal cycles, saw %0d", coproc_internal_cycles);
    end

    if (coproc_mem_cycles != 4) begin
      $fatal(1, "expected four coprocessor memory beats across LDC/STC, saw %0d",
             coproc_mem_cycles);
    end

    if (mrc_seen < 1 || cdp_seen < 1) begin
      $fatal(1, "expected MRC/CDP observations mrc=%0d cdp=%0d", mrc_seen, cdp_seen);
    end

    if (loop_seen < 2) begin
      $fatal(1, "expected coprocessor timing loop to retire, saw %0d", loop_seen);
    end

    $display("tb_arm7tdmi_core_coprocessor_cycle_timing passed");
    $finish;
  end
endmodule
