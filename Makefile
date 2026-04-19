VERILATOR ?= verilator
VERILATOR_FLAGS ?= -Wall -sv --timing
BUILD_DIR ?= obj_dir

RTL_FILES := rtl/arm7tdmi_pkg.sv \
	rtl/arm7tdmi_cond.sv \
	rtl/arm7tdmi_arm_decode.sv \
	rtl/arm7tdmi_thumb_decode.sv \
	rtl/arm7tdmi_shifter.sv \
	rtl/arm7tdmi_alu.sv \
	rtl/arm7tdmi_regfile.sv \
	rtl/arm7tdmi_core.sv

.PHONY: lint test tb-cond tb-arm-decode tb-thumb-decode tb-shifter tb-alu tb-regfile tb-core-smoke tb-core-branch tb-core-thumb-interwork tb-core-thumb-shift tb-core-thumb-addsub tb-core-thumb-condbranch tb-core-thumb-hireg tb-core-thumb-alu tb-core-thumb-ldr-pc tb-core-thumb-ls-imm tb-core-thumb-ls-reg tb-core-mem tb-core-mem-regoffset tb-core-mem-pc tb-core-mem-unaligned tb-core-multiply tb-core-halfword tb-core-halfword-modes tb-core-psr tb-core-swap tb-core-block tb-core-block-empty tb-core-block-pc tb-core-block-pc-restore tb-core-block-user tb-core-exception tb-core-undefined tb-core-interrupt tb-core-exception-return clean

lint:
	$(VERILATOR) --lint-only $(VERILATOR_FLAGS) -f rtl/files.f

test: lint tb-cond tb-arm-decode tb-thumb-decode tb-shifter tb-alu tb-regfile tb-core-smoke tb-core-branch tb-core-thumb-interwork tb-core-thumb-shift tb-core-thumb-addsub tb-core-thumb-condbranch tb-core-thumb-hireg tb-core-thumb-alu tb-core-thumb-ldr-pc tb-core-thumb-ls-imm tb-core-thumb-ls-reg tb-core-mem tb-core-mem-regoffset tb-core-mem-pc tb-core-mem-unaligned tb-core-multiply tb-core-halfword tb-core-halfword-modes tb-core-psr tb-core-swap tb-core-block tb-core-block-empty tb-core-block-pc tb-core-block-pc-restore tb-core-block-user tb-core-exception tb-core-undefined tb-core-interrupt tb-core-exception-return

tb-cond:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_cond $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_cond.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_cond

tb-arm-decode:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_arm_decode $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_arm_decode.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_arm_decode

tb-thumb-decode:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_thumb_decode $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_thumb_decode.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_thumb_decode

tb-shifter:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_shifter $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_shifter.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_shifter

tb-alu:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_alu $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_alu.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_alu

tb-regfile:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_regfile $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_regfile.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_regfile

tb-core-smoke:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_smoke $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_smoke.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_smoke

tb-core-branch:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_branch $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_branch.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_branch

tb-core-thumb-interwork:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_thumb_interwork $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_thumb_interwork.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_thumb_interwork

tb-core-thumb-shift:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_thumb_shift $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_thumb_shift.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_thumb_shift

tb-core-thumb-addsub:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_thumb_addsub $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_thumb_addsub.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_thumb_addsub

tb-core-thumb-condbranch:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_thumb_condbranch $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_thumb_condbranch.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_thumb_condbranch

tb-core-thumb-hireg:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_thumb_hireg $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_thumb_hireg.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_thumb_hireg

tb-core-thumb-alu:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_thumb_alu $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_thumb_alu.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_thumb_alu

tb-core-thumb-ldr-pc:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_thumb_ldr_pc $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_thumb_ldr_pc.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_thumb_ldr_pc

tb-core-thumb-ls-imm:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_thumb_ls_imm $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_thumb_ls_imm.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_thumb_ls_imm

tb-core-thumb-ls-reg:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_thumb_ls_reg $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_thumb_ls_reg.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_thumb_ls_reg

tb-core-mem:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_mem $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_mem.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_mem

tb-core-mem-regoffset:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_mem_regoffset $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_mem_regoffset.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_mem_regoffset

tb-core-mem-pc:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_mem_pc $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_mem_pc.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_mem_pc

tb-core-mem-unaligned:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_mem_unaligned $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_mem_unaligned.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_mem_unaligned

tb-core-multiply:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_multiply $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_multiply.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_multiply

tb-core-halfword:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_halfword $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_halfword.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_halfword

tb-core-halfword-modes:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_halfword_modes $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_halfword_modes.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_halfword_modes

tb-core-psr:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_psr $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_psr.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_psr

tb-core-swap:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_swap $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_swap.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_swap

tb-core-block:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_block $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_block.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_block

tb-core-block-empty:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_block_empty $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_block_empty.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_block_empty

tb-core-block-pc:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_block_pc $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_block_pc.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_block_pc

tb-core-block-pc-restore:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_block_pc_restore $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_block_pc_restore.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_block_pc_restore

tb-core-block-user:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_block_user $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_block_user.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_block_user

tb-core-exception:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_exception $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_exception.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_exception

tb-core-undefined:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_undefined $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_undefined.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_undefined

tb-core-interrupt:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_interrupt $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_interrupt.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_interrupt

tb-core-exception-return:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_exception_return $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_exception_return.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_exception_return

clean:
	rm -rf $(BUILD_DIR)
