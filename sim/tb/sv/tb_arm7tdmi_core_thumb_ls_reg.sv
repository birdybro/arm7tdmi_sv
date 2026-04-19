`timescale 1ns/1ps

module tb_arm7tdmi_core_thumb_ls_reg
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

  logic [31:0] data_word;
  logic [7:0] byte_slot;
  logic [15:0] half_slot;
  int word_store_seen;
  int word_load_seen;
  int byte_store_seen;
  int byte_load_seen;
  int half_store_seen;
  int half_load_seen;
  int signed_byte_seen;
  int signed_half_seen;
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
      32'h0000_0000: bus_rdata = 32'hE3A0_6021; // MOV r6, #0x21
      32'h0000_0004: bus_rdata = 32'hE12F_FF16; // BX r6
      32'h0000_0020: bus_rdata = 32'h0000_2040; // Thumb MOV r0, #0x40
      32'h0000_0022: bus_rdata = 32'h0000_2504; // Thumb MOV r5, #4
      32'h0000_0024: bus_rdata = 32'h0000_2606; // Thumb MOV r6, #6
      32'h0000_0026: bus_rdata = 32'h0000_212A; // Thumb MOV r1, #0x2a
      32'h0000_0028: bus_rdata = 32'h0000_5141; // Thumb STR r1, [r0, r5]
      32'h0000_002A: bus_rdata = 32'h0000_5942; // Thumb LDR r2, [r0, r5]
      32'h0000_002C: bus_rdata = 32'h0000_5441; // Thumb STRB r1, [r0, r1]
      32'h0000_002E: bus_rdata = 32'h0000_5C43; // Thumb LDRB r3, [r0, r1]
      32'h0000_0030: bus_rdata = 32'h0000_5381; // Thumb STRH r1, [r0, r6]
      32'h0000_0032: bus_rdata = 32'h0000_5B84; // Thumb LDRH r4, [r0, r6]
      32'h0000_0034: bus_rdata = 32'h0000_2301; // Thumb MOV r3, #1
      32'h0000_0036: bus_rdata = 32'h0000_56C6; // Thumb LDRSB r6, [r0, r3]
      32'h0000_0038: bus_rdata = 32'h0000_5EC7; // Thumb LDRSH r7, [r0, r3]
      32'h0000_003A: bus_rdata = 32'h0000_E7FE; // Thumb B .
      32'h0000_0041: bus_rdata = (bus_size == BUS_SIZE_BYTE) ? 32'h0000_0080 :
                                                               32'h0000_802A;
      32'h0000_0044: bus_rdata = data_word;
      32'h0000_0046: bus_rdata = {16'h0, half_slot};
      32'h0000_006A: bus_rdata = (bus_size == BUS_SIZE_HALF) ? {16'h0, half_slot} :
                                                               {24'h0, byte_slot};
      default:       bus_rdata = 32'hE1A0_0000;
    endcase
  end

  always_ff @(posedge clk) begin
    if (bus_valid && bus_write) begin
      if (bus_addr == 32'h0000_0044) begin
        if (bus_size !== BUS_SIZE_WORD || bus_wdata !== 32'h0000_002A) begin
          $fatal(1, "Thumb register STR expected word 0x2a, got size=%0d data=%08x", bus_size, bus_wdata);
        end

        data_word <= bus_wdata;
        word_store_seen <= word_store_seen + 1;
      end else if (bus_addr == 32'h0000_006A && bus_size == BUS_SIZE_BYTE) begin
        if (bus_size !== BUS_SIZE_BYTE || bus_wdata !== 32'h0000_002A) begin
          $fatal(1, "Thumb register STRB expected byte 0x2a, got size=%0d data=%08x", bus_size, bus_wdata);
        end

        byte_slot <= bus_wdata[7:0];
        byte_store_seen <= byte_store_seen + 1;
      end else if (bus_addr == 32'h0000_0046 && bus_size == BUS_SIZE_HALF) begin
        if (bus_size !== BUS_SIZE_HALF || bus_wdata !== 32'h0000_002A) begin
          $fatal(1, "Thumb register STRH expected halfword 0x2a, got size=%0d data=%08x", bus_size, bus_wdata);
        end

        half_slot <= bus_wdata[15:0];
        half_store_seen <= half_store_seen + 1;
      end else begin
        $fatal(1, "unexpected Thumb register store address %08x size=%0d data=%08x pc=%08x",
               bus_addr, bus_size, bus_wdata, debug_pc);
      end
    end
  end

  task automatic check_bus_contract;
    if (bus_valid && !(bus_size inside {BUS_SIZE_BYTE, BUS_SIZE_HALF, BUS_SIZE_WORD})) begin
      $fatal(1, "Thumb register load/store saw invalid bus size");
    end

    if (bus_valid && !(bus_cycle inside {BUS_CYCLE_NONSEQ, BUS_CYCLE_SEQ})) begin
      $fatal(1, "Thumb register load/store saw invalid cycle class");
    end

    if (unsupported) begin
      $fatal(1, "unexpected unsupported instruction at pc=%08x cpsr=%08x", debug_pc, debug_cpsr);
    end
  endtask

  initial begin
    rst_n = 1'b0;
    bus_ready = 1'b1;
    data_word = 32'hFFFF_002A;
    byte_slot = 8'h00;
    half_slot = 16'h0000;
    word_store_seen = 0;
    word_load_seen = 0;
    byte_store_seen = 0;
    byte_load_seen = 0;
    half_store_seen = 0;
    half_load_seen = 0;
    signed_byte_seen = 0;
    signed_half_seen = 0;
    loop_seen = 0;

    repeat (2) @(posedge clk);
    rst_n = 1'b1;

    for (int cycle = 0; cycle < 180; cycle++) begin
      @(posedge clk);
      #1;
      check_bus_contract();

      if (debug_reg_we && debug_pc == 32'h0000_002C &&
          debug_reg_waddr == 4'd2 && debug_reg_wdata == 32'h0000_002A) begin
        word_load_seen++;
      end

      if (debug_reg_we && debug_pc == 32'h0000_0030 &&
          debug_reg_waddr == 4'd3 && debug_reg_wdata == 32'h0000_002A) begin
        byte_load_seen++;
      end

      if (debug_reg_we && debug_pc == 32'h0000_0034 &&
          debug_reg_waddr == 4'd4 && debug_reg_wdata == 32'h0000_002A) begin
        half_load_seen++;
      end

      if (debug_reg_we && debug_pc == 32'h0000_0038 &&
          debug_reg_waddr == 4'd6 && debug_reg_wdata == 32'hFFFF_FF80) begin
        signed_byte_seen++;
      end

      if (debug_reg_we && debug_pc == 32'h0000_003A &&
          debug_reg_waddr == 4'd7 && debug_reg_wdata == 32'hFFFF_802A) begin
        signed_half_seen++;
      end

      if (retired && debug_pc == 32'h0000_003A && debug_cpsr[5]) begin
        loop_seen++;
      end
    end

    if (word_store_seen != 1 || word_load_seen != 1 ||
        byte_store_seen != 1 || byte_load_seen != 1 ||
        half_store_seen != 1 || half_load_seen != 1 ||
        signed_byte_seen != 1 || signed_half_seen != 1) begin
      $fatal(1, "expected one Thumb register LS path, saw sw=%0d lw=%0d sb=%0d lb=%0d sh=%0d lh=%0d lsb=%0d lsh=%0d",
             word_store_seen, word_load_seen, byte_store_seen, byte_load_seen,
             half_store_seen, half_load_seen, signed_byte_seen, signed_half_seen);
    end

    if (loop_seen < 2) begin
      $fatal(1, "expected Thumb register load/store loop to retire, saw %0d", loop_seen);
    end

    $display("tb_arm7tdmi_core_thumb_ls_reg passed");
    $finish;
  end
endmodule
