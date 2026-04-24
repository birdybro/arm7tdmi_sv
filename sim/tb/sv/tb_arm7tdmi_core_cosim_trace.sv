`timescale 1ns/1ps

module tb_arm7tdmi_core_cosim_trace
  import arm7tdmi_pkg::*;
;
  localparam int MEM_BYTES = 65536;

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
  logic [31:0] debug_cpsr;
  logic debug_reg_we;
  logic [3:0] debug_reg_waddr;
  logic [31:0] debug_reg_wdata;
  logic retired;
  logic unsupported;
  logic irq;
  logic fiq;
  logic bus_abort;
  logic coproc_dummy_enable;
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

  logic [7:0] mem [0:MEM_BYTES-1];
  logic [31:0] cp_regs [0:15];
  logic [1:0] coproc_transfer_index;

  integer trace_fd;
  integer retired_count;
  integer cycle_count;
  integer retired_limit;
  integer max_cycles;
  integer irq_initial;
  integer fiq_initial;
  integer irq_raise_cycle;
  integer fiq_raise_cycle;
  integer irq_clear_on_reg_addr;
  integer fiq_clear_on_reg_addr;
  logic [31:0] irq_clear_on_reg_data;
  logic [31:0] fiq_clear_on_reg_data;
  logic irq_clear_on_reg_data_valid;
  logic fiq_clear_on_reg_data_valid;
  logic [31:0] abort_on_fetch_addr;
  logic abort_on_fetch_addr_valid;
  logic [31:0] abort_on_write_addr;
  logic abort_on_write_addr_valid;
  logic [31:0] abort_on_debug_pc;
  logic abort_on_debug_pc_valid;
  integer mem_write_count;
  logic [31:0] last_mem_addr;
  logic [31:0] last_mem_data;
  arm_bus_size_t last_mem_size;
  logic pending_log;
  logic [31:0] pending_pc;
  logic [31:0] pending_cpsr;
  logic pending_thumb;
  logic [31:0] pending_insn;
  logic pending_reg_we;
  logic [3:0] pending_reg_waddr;
  logic [31:0] pending_reg_wdata;
  integer pending_mem_write_count;
  logic [31:0] pending_mem_addr;
  logic [31:0] pending_mem_data;
  arm_bus_size_t pending_mem_size;
  logic [31:0] sampled_pc;
  logic sampled_thumb;

  string memh_path;
  string trace_path;

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
    .irq_i(irq),
    .fiq_i(fiq),
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

  function automatic logic [31:0] read32(input logic [31:0] addr);
    logic [31:0] a;
    begin
      a = addr & 32'h0000_FFFF;
      read32 = {mem[a + 32'd3], mem[a + 32'd2], mem[a + 32'd1], mem[a]};
    end
  endfunction

  function automatic logic [15:0] read16(input logic [31:0] addr);
    logic [31:0] a;
    begin
      a = addr & 32'h0000_FFFF;
      read16 = {mem[a + 32'd1], mem[a]};
    end
  endfunction

  function automatic logic [31:0] arch_reg(input logic [4:0] mode_bits, input int idx);
    arm_mode_t mode;
    begin
      mode = arm_mode_t'(mode_bits);
      if (idx <= 7) begin
        arch_reg = dut.u_regfile.r_usr[idx];
      end else if (idx <= 12) begin
        arch_reg = (mode == MODE_FIQ) ? dut.u_regfile.r_fiq[idx] : dut.u_regfile.r_usr[idx];
      end else if (idx == 13 || idx == 14) begin
        unique case (mode)
          MODE_FIQ: arch_reg = dut.u_regfile.r_fiq[idx];
          MODE_IRQ: arch_reg = dut.u_regfile.r_irq[idx];
          MODE_SVC: arch_reg = dut.u_regfile.r_svc[idx];
          MODE_ABT: arch_reg = dut.u_regfile.r_abt[idx];
          MODE_UND: arch_reg = dut.u_regfile.r_und[idx];
          default:  arch_reg = dut.u_regfile.r_usr[idx];
        endcase
      end else begin
        arch_reg = 32'h0000_0000;
      end
    end
  endfunction

  task automatic log_retire;
    string line;
    begin
      line = $sformatf(
        "{\"seq\":%0d,\"pc\":\"%08x\",\"cpsr\":\"%08x\",\"thumb\":%s,\"insn\":\"%08x\",\"reg_write_valid\":%s,\"reg_write_addr\":%0d,\"reg_write_data\":\"%08x\",\"mem_write_count\":%0d,\"mem_write_addr\":\"%08x\",\"mem_write_size\":\"%0d\",\"mem_write_data\":\"%08x\",\"r0\":\"%08x\",\"r1\":\"%08x\",\"r2\":\"%08x\",\"r3\":\"%08x\",\"r4\":\"%08x\",\"r5\":\"%08x\",\"r6\":\"%08x\",\"r7\":\"%08x\",\"r8\":\"%08x\",\"r9\":\"%08x\",\"r10\":\"%08x\",\"r11\":\"%08x\",\"r12\":\"%08x\",\"r13\":\"%08x\",\"r14\":\"%08x\"}",
        retired_count,
        pending_pc,
        pending_cpsr,
        pending_thumb ? "true" : "false",
        pending_insn,
        pending_reg_we ? "true" : "false",
        pending_reg_waddr,
        pending_reg_wdata,
        pending_mem_write_count,
        pending_mem_addr,
        pending_mem_size,
        pending_mem_data,
        arch_reg(pending_cpsr[4:0], 0),
        arch_reg(pending_cpsr[4:0], 1),
        arch_reg(pending_cpsr[4:0], 2),
        arch_reg(pending_cpsr[4:0], 3),
        arch_reg(pending_cpsr[4:0], 4),
        arch_reg(pending_cpsr[4:0], 5),
        arch_reg(pending_cpsr[4:0], 6),
        arch_reg(pending_cpsr[4:0], 7),
        arch_reg(pending_cpsr[4:0], 8),
        arch_reg(pending_cpsr[4:0], 9),
        arch_reg(pending_cpsr[4:0], 10),
        arch_reg(pending_cpsr[4:0], 11),
        arch_reg(pending_cpsr[4:0], 12),
        arch_reg(pending_cpsr[4:0], 13),
        arch_reg(pending_cpsr[4:0], 14)
      );
      $fdisplay(trace_fd, "%s", line);
    end
  endtask

  always_comb begin
    bus_abort = 1'b0;

    if (abort_on_fetch_addr_valid && bus_valid && !bus_write &&
        bus_addr == abort_on_fetch_addr &&
        (!abort_on_debug_pc_valid || debug_pc == abort_on_debug_pc)) begin
      bus_abort = 1'b1;
    end
    if (abort_on_write_addr_valid && bus_valid && bus_write &&
        bus_addr == abort_on_write_addr &&
        (!abort_on_debug_pc_valid || debug_pc == abort_on_debug_pc)) begin
      bus_abort = 1'b1;
    end

    if (!bus_valid || bus_write) begin
      bus_rdata = 32'h0000_0000;
    end else begin
      unique case (bus_size)
        BUS_SIZE_BYTE: bus_rdata = {24'h0, mem[bus_addr & 32'h0000_FFFF]};
        BUS_SIZE_HALF: bus_rdata = {16'h0, read16(bus_addr)};
        default:       bus_rdata = read32(bus_addr);
      endcase
    end
  end

  always_comb begin
    coproc_accept = 1'b0;
    coproc_ready = 1'b0;
    coproc_rdata = 32'h0000_0000;
    coproc_last = 1'b1;

    if (coproc_dummy_enable) begin
      coproc_accept = 1'b1;
      coproc_ready = coproc_valid;

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
  end

  always_ff @(posedge clk) begin
    if (bus_valid && bus_ready && bus_write && !bus_abort) begin
      last_mem_addr <= bus_addr;
      last_mem_data <= bus_wdata;
      last_mem_size <= bus_size;
      mem_write_count <= mem_write_count + 1;

      unique case (bus_size)
        BUS_SIZE_BYTE: mem[bus_addr & 32'h0000_FFFF] <= bus_wdata[7:0];
        BUS_SIZE_HALF: begin
          mem[bus_addr & 32'h0000_FFFF] <= bus_wdata[7:0];
          mem[(bus_addr + 32'd1) & 32'h0000_FFFF] <= bus_wdata[15:8];
        end
        default: begin
          mem[bus_addr & 32'h0000_FFFF] <= bus_wdata[7:0];
          mem[(bus_addr + 32'd1) & 32'h0000_FFFF] <= bus_wdata[15:8];
          mem[(bus_addr + 32'd2) & 32'h0000_FFFF] <= bus_wdata[23:16];
          mem[(bus_addr + 32'd3) & 32'h0000_FFFF] <= bus_wdata[31:24];
        end
      endcase
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      coproc_transfer_index <= 2'd0;
      for (int idx = 0; idx < 16; idx++) begin
        cp_regs[idx] <= 32'h0000_0000;
      end
    end else if (coproc_dummy_enable && coproc_valid && coproc_accept && coproc_ready) begin
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

  initial begin
    for (int i = 0; i < MEM_BYTES; i++) begin
      mem[i] = 8'h00;
    end

    if (!$value$plusargs("memh=%s", memh_path)) begin
      $fatal(1, "missing +memh=<path>");
    end
    if (!$value$plusargs("trace=%s", trace_path)) begin
      $fatal(1, "missing +trace=<path>");
    end
    if (!$value$plusargs("retired_limit=%d", retired_limit)) begin
      retired_limit = 100;
    end
    if (!$value$plusargs("max_cycles=%d", max_cycles)) begin
      max_cycles = 1000;
    end
    if (!$value$plusargs("irq_initial=%d", irq_initial)) begin
      irq_initial = 0;
    end
    if (!$value$plusargs("fiq_initial=%d", fiq_initial)) begin
      fiq_initial = 0;
    end
    if (!$value$plusargs("irq_raise_cycle=%d", irq_raise_cycle)) begin
      irq_raise_cycle = -1;
    end
    if (!$value$plusargs("fiq_raise_cycle=%d", fiq_raise_cycle)) begin
      fiq_raise_cycle = -1;
    end
    if (!$value$plusargs("irq_clear_on_reg_addr=%d", irq_clear_on_reg_addr)) begin
      irq_clear_on_reg_addr = -1;
    end
    if (!$value$plusargs("fiq_clear_on_reg_addr=%d", fiq_clear_on_reg_addr)) begin
      fiq_clear_on_reg_addr = -1;
    end
    coproc_dummy_enable = $test$plusargs("coproc_dummy");
    irq_clear_on_reg_data_valid = $value$plusargs("irq_clear_on_reg_data=%h", irq_clear_on_reg_data);
    fiq_clear_on_reg_data_valid = $value$plusargs("fiq_clear_on_reg_data=%h", fiq_clear_on_reg_data);
    abort_on_fetch_addr_valid = $value$plusargs("abort_on_fetch_addr=%h", abort_on_fetch_addr);
    abort_on_write_addr_valid = $value$plusargs("abort_on_write_addr=%h", abort_on_write_addr);
    abort_on_debug_pc_valid = $value$plusargs("abort_on_debug_pc=%h", abort_on_debug_pc);

    $readmemh(memh_path, mem);

    trace_fd = $fopen(trace_path, "w");
    if (trace_fd == 0) begin
      $fatal(1, "failed to open trace file '%s'", trace_path);
    end

    rst_n = 1'b0;
    bus_ready = 1'b1;
    irq = (irq_initial != 0);
    fiq = (fiq_initial != 0);
    retired_count = 0;
    cycle_count = 0;
    mem_write_count = 0;
    last_mem_addr = 32'h0000_0000;
    last_mem_data = 32'h0000_0000;
    last_mem_size = BUS_SIZE_WORD;
    pending_log = 1'b0;
    pending_pc = 32'h0000_0000;
    pending_cpsr = 32'h0000_0000;
    pending_thumb = 1'b0;
    pending_insn = 32'h0000_0000;
    pending_reg_we = 1'b0;
    pending_reg_waddr = 4'd0;
    pending_reg_wdata = 32'h0000_0000;
    pending_mem_write_count = 0;
    pending_mem_addr = 32'h0000_0000;
    pending_mem_data = 32'h0000_0000;
    pending_mem_size = BUS_SIZE_WORD;
    sampled_pc = 32'h0000_0000;
    sampled_thumb = 1'b0;

    repeat (2) @(posedge clk);
    rst_n = 1'b1;

    while (retired_count < retired_limit) begin
      @(posedge clk);
      #1;
      cycle_count++;

      if (irq_raise_cycle >= 0 && cycle_count == irq_raise_cycle) begin
        irq = 1'b1;
      end
      if (fiq_raise_cycle >= 0 && cycle_count == fiq_raise_cycle) begin
        fiq = 1'b1;
      end

      if (unsupported) begin
        $fatal(1, "unsupported instruction at pc=%08x", debug_pc);
      end

      if (pending_log) begin
        log_retire();
        retired_count = retired_count + 1;
        pending_log = 1'b0;
      end

      if (retired) begin
        pending_pc = sampled_pc;
        pending_cpsr = debug_cpsr;
        pending_thumb = debug_cpsr[5];
        pending_insn = sampled_thumb ? {16'h0000, read16(sampled_pc)} : read32(sampled_pc);
        pending_reg_we = debug_reg_we;
        pending_reg_waddr = debug_reg_waddr;
        pending_reg_wdata = debug_reg_wdata;
        pending_mem_write_count = mem_write_count;
        pending_mem_addr = last_mem_addr;
        pending_mem_data = last_mem_data;
        pending_mem_size = last_mem_size;
        pending_log = 1'b1;
        mem_write_count = 0;
        last_mem_addr = 32'h0000_0000;
        last_mem_data = 32'h0000_0000;
        last_mem_size = BUS_SIZE_WORD;
      end

      if (irq && debug_reg_we && irq_clear_on_reg_addr >= 0 &&
          debug_reg_waddr == irq_clear_on_reg_addr[3:0] &&
          (!irq_clear_on_reg_data_valid || debug_reg_wdata == irq_clear_on_reg_data)) begin
        irq = 1'b0;
      end
      if (fiq && debug_reg_we && fiq_clear_on_reg_addr >= 0 &&
          debug_reg_waddr == fiq_clear_on_reg_addr[3:0] &&
          (!fiq_clear_on_reg_data_valid || debug_reg_wdata == fiq_clear_on_reg_data)) begin
        fiq = 1'b0;
      end

      sampled_pc = debug_pc;
      sampled_thumb = debug_cpsr[5];

      if (cycle_count >= max_cycles) begin
        $fatal(1, "cosim trace bench hit max_cycles=%0d before retired_limit=%0d", max_cycles, retired_limit);
      end
    end

    $fclose(trace_fd);
    $display("tb_arm7tdmi_core_cosim_trace passed");
    $finish;
  end
endmodule
