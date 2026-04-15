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

.PHONY: lint test tb-cond tb-arm-decode tb-shifter tb-alu tb-regfile tb-core-smoke tb-core-branch tb-core-mem clean

lint:
	$(VERILATOR) --lint-only $(VERILATOR_FLAGS) -f rtl/files.f

test: lint tb-cond tb-arm-decode tb-shifter tb-alu tb-regfile tb-core-smoke tb-core-branch tb-core-mem

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

clean:
	rm -rf $(BUILD_DIR)
