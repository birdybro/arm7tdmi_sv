VERILATOR ?= verilator
VERILATOR_FLAGS ?= -Wall -sv --timing
BUILD_DIR ?= obj_dir

RTL_FILES := rtl/arm7tdmi_pkg.sv \
	rtl/arm7tdmi_cond.sv \
	rtl/arm7tdmi_arm_decode.sv \
	rtl/arm7tdmi_shifter.sv \
	rtl/arm7tdmi_alu.sv \
	rtl/arm7tdmi_regfile.sv \
	rtl/arm7tdmi_core.sv

.PHONY: lint test tb-cond tb-arm-decode tb-shifter tb-alu tb-regfile tb-core-smoke tb-core-branch tb-core-mem tb-core-mem-regoffset tb-core-mem-pc tb-core-multiply tb-core-halfword tb-core-psr tb-core-swap tb-core-block tb-core-block-pc tb-core-block-pc-restore tb-core-exception tb-core-undefined tb-core-interrupt tb-core-exception-return clean

lint:
	$(VERILATOR) --lint-only $(VERILATOR_FLAGS) -f rtl/files.f

test: lint tb-cond tb-arm-decode tb-shifter tb-alu tb-regfile tb-core-smoke tb-core-branch tb-core-mem tb-core-mem-regoffset tb-core-mem-pc tb-core-multiply tb-core-halfword tb-core-psr tb-core-swap tb-core-block tb-core-block-pc tb-core-block-pc-restore tb-core-exception tb-core-undefined tb-core-interrupt tb-core-exception-return

tb-cond:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_cond $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_cond.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_cond

tb-arm-decode:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_arm_decode $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_arm_decode.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_arm_decode

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

tb-core-mem:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_mem $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_mem.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_mem

tb-core-mem-regoffset:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_mem_regoffset $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_mem_regoffset.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_mem_regoffset

tb-core-mem-pc:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_mem_pc $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_mem_pc.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_mem_pc

tb-core-multiply:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_multiply $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_multiply.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_multiply

tb-core-halfword:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_halfword $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_halfword.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_halfword

tb-core-psr:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_psr $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_psr.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_psr

tb-core-swap:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_swap $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_swap.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_swap

tb-core-block:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_block $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_block.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_block

tb-core-block-pc:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_block_pc $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_block_pc.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_block_pc

tb-core-block-pc-restore:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_block_pc_restore $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_block_pc_restore.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_block_pc_restore

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
