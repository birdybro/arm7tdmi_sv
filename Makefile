VERILATOR ?= verilator
VERILATOR_FLAGS ?= -Wall -sv --timing
BUILD_DIR ?= obj_dir

RTL_FILES := rtl/arm7tdmi_pkg.sv \
	rtl/arm7tdmi_cond.sv \
	rtl/arm7tdmi_shifter.sv \
	rtl/arm7tdmi_alu.sv \
	rtl/arm7tdmi_regfile.sv \
	rtl/arm7tdmi_core.sv

.PHONY: lint test tb-cond tb-shifter tb-alu tb-regfile clean

lint:
	$(VERILATOR) --lint-only $(VERILATOR_FLAGS) -f rtl/files.f

test: lint tb-cond tb-shifter tb-alu tb-regfile

tb-cond:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_cond $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_cond.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_cond

tb-shifter:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_shifter $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_shifter.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_shifter

tb-alu:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_alu $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_alu.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_alu

tb-regfile:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_regfile $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_regfile.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_regfile

clean:
	rm -rf $(BUILD_DIR)
