`timescale 1ns/1ps

module tb_arm7tdmi_core_coprocessor_wait
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

  logic        mem_stall_active;
  logic [31:0] mem_stall_addr_q;
  logic        mem_stall_write_q;
  arm_bus_size_t mem_stall_size_q;
  logic [31:0] mem_stall_wdata_q;
  logic        coproc_stall_active;
  arm_coproc_op_t coproc_stall_op_q;
  logic [3:0]  coproc_stall_crd_q;
  logic [31:0] coproc_stall_wdata_q;

  int mrc_wait_cycles;
  int stc_wait_cycles;
  int ldc_mem_wait_cycles;
  int stc_mem_wait_cycles;
  int mrc_seen;
  int ldc_wb_seen;
  int stc_wb_seen;
  int stc_store_seen;
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
      32'h0000_000C: bus_rdata = 32'hE3A0_0040; // MOV r0, #0x40
      32'h0000_0010: bus_rdata = 32'hECD0_4202; // LDC p2, c4, [r0], #8
      32'h0000_0014: bus_rdata = 32'hE3A0_0050; // MOV r0, #0x50
      32'h0000_0018: bus_rdata = 32'hECC0_4202; // STC p2, c4, [r0], #8
      32'h0000_001C: bus_rdata = 32'hEAFF_FFFE; // B .
      32'h0000_0040: bus_rdata = data_word0;
      32'h0000_0044: bus_rdata = data_word1;
      32'h0000_0050: bus_rdata = data_word2;
      32'h0000_0054: bus_rdata = data_word3;
      default:       bus_rdata = 32'hE1A0_0000; // MOV r0, r0
    endcase
  end

  always_comb begin
    bus_ready = 1'b1;
    if (bus_valid && bus_size == BUS_SIZE_WORD && bus_cycle == BUS_CYCLE_COPROC) begin
      if (!bus_write && bus_addr == 32'h0000_0040 && ldc_mem_wait_cycles < 2) begin
        bus_ready = 1'b0;
      end else if (bus_write && bus_addr == 32'h0000_0050 && stc_mem_wait_cycles < 2) begin
        bus_ready = 1'b0;
      end
    end
  end

  always_comb begin
    coproc_accept = 1'b1;
    coproc_ready = coproc_valid;
    coproc_rdata = 32'h0000_0000;
    coproc_last = 1'b1;

    unique case (coproc_op)
      COPROC_OP_MRC: begin
        coproc_rdata = cp_regs[coproc_crn];
        if (mrc_wait_cycles < 2) begin
          coproc_ready = 1'b0;
        end
      end

      COPROC_OP_LDC: begin
        coproc_last = !coproc_long || (coproc_transfer_index == 2'd1);
      end

      COPROC_OP_STC: begin
        coproc_rdata = cp_regs[coproc_crd + {2'b00, coproc_transfer_index}];
        coproc_last = !coproc_long || (coproc_transfer_index == 2'd1);
        if ((stc_store_seen == 0) && (stc_wait_cycles < 2)) begin
          coproc_ready = 1'b0;
        end
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
    if (bus_valid && !bus_ready) begin
      if (mem_stall_active) begin
        if (bus_addr !== mem_stall_addr_q || bus_write !== mem_stall_write_q ||
            bus_size !== mem_stall_size_q || bus_wdata !== mem_stall_wdata_q) begin
          $fatal(1, "coprocessor memory transfer changed while stalled addr=%08x/%08x write=%0d/%0d size=%0d/%0d data=%08x/%08x",
                 bus_addr, mem_stall_addr_q, bus_write, mem_stall_write_q, bus_size,
                 mem_stall_size_q, bus_wdata, mem_stall_wdata_q);
        end
      end

      mem_stall_active <= 1'b1;
      mem_stall_addr_q <= bus_addr;
      mem_stall_write_q <= bus_write;
      mem_stall_size_q <= bus_size;
      mem_stall_wdata_q <= bus_wdata;

      if (!bus_write && bus_addr == 32'h0000_0040) begin
        ldc_mem_wait_cycles <= ldc_mem_wait_cycles + 1;
      end else if (bus_write && bus_addr == 32'h0000_0050) begin
        stc_mem_wait_cycles <= stc_mem_wait_cycles + 1;
      end
    end else begin
      mem_stall_active <= 1'b0;
    end

    if (coproc_valid && !coproc_ready) begin
      if (coproc_stall_active) begin
        if (coproc_op !== coproc_stall_op_q || coproc_crd !== coproc_stall_crd_q ||
            coproc_wdata !== coproc_stall_wdata_q) begin
          $fatal(1, "coprocessor command changed while stalled op=%0d/%0d crd=%0d/%0d data=%08x/%08x",
                 coproc_op, coproc_stall_op_q, coproc_crd, coproc_stall_crd_q,
                 coproc_wdata, coproc_stall_wdata_q);
        end
      end

      coproc_stall_active <= 1'b1;
      coproc_stall_op_q <= coproc_op;
      coproc_stall_crd_q <= coproc_crd;
      coproc_stall_wdata_q <= coproc_wdata;

      if (coproc_op == COPROC_OP_MRC) begin
        mrc_wait_cycles <= mrc_wait_cycles + 1;
      end else if (coproc_op == COPROC_OP_STC && stc_store_seen == 0) begin
        stc_wait_cycles <= stc_wait_cycles + 1;
      end
    end else begin
      coproc_stall_active <= 1'b0;
    end

    if (bus_valid && bus_ready && bus_write && bus_cycle == BUS_CYCLE_COPROC) begin
      unique case (bus_addr)
        32'h0000_0050: data_word2 <= bus_wdata;
        32'h0000_0054: data_word3 <= bus_wdata;
        default:       $fatal(1, "unexpected coprocessor waited store addr=%08x data=%08x",
                              bus_addr, bus_wdata);
      endcase
    end
  end

  initial begin
    rst_n = 1'b0;
    data_word0 = 32'h1122_3344;
    data_word1 = 32'h5566_7788;
    data_word2 = 32'hCAFE_F00D;
    data_word3 = 32'hDEAD_BEEF;
    mem_stall_active = 1'b0;
    mem_stall_addr_q = 32'h0000_0000;
    mem_stall_write_q = 1'b0;
    mem_stall_size_q = BUS_SIZE_WORD;
    mem_stall_wdata_q = 32'h0000_0000;
    coproc_stall_active = 1'b0;
    coproc_stall_op_q = COPROC_OP_NONE;
    coproc_stall_crd_q = 4'h0;
    coproc_stall_wdata_q = 32'h0000_0000;
    mrc_wait_cycles = 0;
    stc_wait_cycles = 0;
    ldc_mem_wait_cycles = 0;
    stc_mem_wait_cycles = 0;
    mrc_seen = 0;
    ldc_wb_seen = 0;
    stc_wb_seen = 0;
    stc_store_seen = 0;
    loop_seen = 0;

    repeat (2) @(posedge clk);
    rst_n = 1'b1;

    for (int cycle = 0; cycle < 120; cycle++) begin
      @(posedge clk);
      #1;

      if (unsupported) begin
        $fatal(1, "unexpected unsupported instruction at pc=%08x cpsr=%08x", debug_pc, debug_cpsr);
      end

      if (bus_valid && !(bus_size inside {BUS_SIZE_WORD})) begin
        $fatal(1, "coprocessor wait smoke expected word transfers only");
      end

      if (bus_valid && !(bus_cycle inside {BUS_CYCLE_NONSEQ, BUS_CYCLE_SEQ, BUS_CYCLE_COPROC})) begin
        $fatal(1, "coprocessor wait smoke saw invalid bus cycle class %0d", bus_cycle);
      end

      if (!bus_ready && (debug_reg_we || retired)) begin
        $fatal(1, "core should not retire or write registers while a coprocessor memory beat is stalled");
      end

      if (coproc_valid && !coproc_ready && (debug_reg_we || retired || bus_valid)) begin
        $fatal(1, "core should hold in coprocessor internal wait without retiring or issuing bus cycles");
      end

      if (debug_reg_we && debug_reg_waddr == 4'd1 && debug_reg_wdata == 32'h0000_0055) begin
        mrc_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd0 && debug_reg_wdata == 32'h0000_0048) begin
        ldc_wb_seen++;
      end

      if (debug_reg_we && debug_reg_waddr == 4'd0 && debug_reg_wdata == 32'h0000_0058) begin
        stc_wb_seen++;
      end

      if (bus_valid && bus_ready && bus_write && bus_cycle == BUS_CYCLE_COPROC &&
          (bus_addr == 32'h0000_0050 || bus_addr == 32'h0000_0054)) begin
        stc_store_seen++;
      end

      if (retired && debug_pc == 32'h0000_001C) begin
        loop_seen++;
      end
    end

    if (mrc_wait_cycles != 2 || stc_wait_cycles != 2) begin
      $fatal(1, "expected two internal coprocessor wait cycles for MRC and STC, saw mrc=%0d stc=%0d",
             mrc_wait_cycles, stc_wait_cycles);
    end

    if (ldc_mem_wait_cycles != 2 || stc_mem_wait_cycles != 2) begin
      $fatal(1, "expected two memory wait cycles for LDC and STC, saw ldc=%0d stc=%0d",
             ldc_mem_wait_cycles, stc_mem_wait_cycles);
    end

    if (mrc_seen != 1 || ldc_wb_seen != 1 || stc_wb_seen != 1) begin
      $fatal(1, "unexpected coprocessor wait results mrc=%0d ldc_wb=%0d stc_wb=%0d",
             mrc_seen, ldc_wb_seen, stc_wb_seen);
    end

    if (stc_store_seen != 2) begin
      $fatal(1, "expected two STC stores after waits, saw %0d", stc_store_seen);
    end

    if (cp_regs[4] !== 32'h1122_3344 || cp_regs[5] !== 32'h5566_7788) begin
      $fatal(1, "unexpected waited LDC payload c4=%08x c5=%08x", cp_regs[4], cp_regs[5]);
    end

    if (data_word2 !== 32'h1122_3344 || data_word3 !== 32'h5566_7788) begin
      $fatal(1, "unexpected waited STC payload [%08x, %08x]", data_word2, data_word3);
    end

    if (loop_seen < 2) begin
      $fatal(1, "expected waited coprocessor loop to retire, saw %0d", loop_seen);
    end

    $display("tb_arm7tdmi_core_coprocessor_wait passed");
    $finish;
  end
endmodule
