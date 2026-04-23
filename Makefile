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

.PHONY: lint test tb-cond tb-arm-decode tb-thumb-decode tb-shifter tb-alu tb-regfile tb-core-smoke tb-core-branch tb-core-cycle-timing tb-core-bus-cycle-timing tb-core-mem-cycle-timing tb-core-thumb-cycle-timing tb-core-exception-cycle-timing tb-core-block-cycle-timing tb-core-prefetch-abort-cycle-timing tb-core-interrupt-cycle-timing tb-core-data-abort-cycle-timing tb-core-swap-abort-cycle-timing tb-core-block-abort-cycle-timing tb-core-thumb-data-abort-cycle-timing tb-core-thumb-data-abort-store-cycle-timing tb-core-thumb-interwork-cycle-timing tb-core-thumb-swi-cycle-timing tb-core-thumb-undefined-cycle-timing tb-core-thumb-unsupported-cycle-timing tb-core-thumb-interrupt-cycle-timing tb-core-thumb-prefetch-abort-cycle-timing tb-core-cosim-smoke tb-core-cosim-thumb-interrupt-smoke tb-core-cosim-thumb-prefetch-abort-smoke tb-core-cosim-thumb-alu-smoke tb-core-cosim-thumb-hireg-smoke tb-core-cosim-thumb-shift-smoke tb-core-cosim-thumb-addsub-smoke tb-core-cosim-thumb-stack-smoke tb-core-cosim-thumb-ls-reg-smoke tb-core-cosim-thumb-ls-sp-smoke tb-core-cosim-thumb-sp-adjust-smoke tb-core-cosim-thumb-add-addr-smoke tb-core-thumb-interwork tb-core-thumb-shift tb-core-thumb-addsub tb-core-thumb-condbranch tb-core-thumb-hireg tb-core-thumb-alu tb-core-thumb-ldr-pc tb-core-thumb-ls-imm tb-core-thumb-ls-imm-wait tb-core-thumb-ls-reg tb-core-thumb-ls-sp tb-core-thumb-add-addr tb-core-thumb-sp-adjust tb-core-thumb-block tb-core-thumb-block-wait tb-core-thumb-stack tb-core-thumb-swi tb-core-thumb-bl tb-core-thumb-undefined tb-core-thumb-unsupported tb-core-thumb-data-abort tb-core-thumb-data-abort-store tb-core-mem tb-core-mem-wait tb-core-mem-ttrans tb-core-mem-regoffset tb-core-mem-pc tb-core-mem-pc-store tb-core-mem-pc-byte tb-core-mem-pc-down tb-core-mem-unaligned tb-core-multiply tb-core-halfword tb-core-halfword-modes tb-core-psr tb-core-swap tb-core-swap-wait tb-core-block tb-core-block-wait tb-core-block-empty tb-core-block-pc tb-core-block-pc-restore tb-core-block-user tb-core-exception tb-core-undefined tb-core-interrupt tb-core-prefetch-abort tb-core-data-abort tb-core-data-abort-store tb-core-swap-abort tb-core-block-abort tb-core-block-abort-wait tb-core-exception-return clean

lint:
	$(VERILATOR) --lint-only $(VERILATOR_FLAGS) -f rtl/files.f

test: lint tb-cond tb-arm-decode tb-thumb-decode tb-shifter tb-alu tb-regfile tb-core-smoke tb-core-branch tb-core-cycle-timing tb-core-bus-cycle-timing tb-core-mem-cycle-timing tb-core-thumb-cycle-timing tb-core-exception-cycle-timing tb-core-block-cycle-timing tb-core-prefetch-abort-cycle-timing tb-core-interrupt-cycle-timing tb-core-data-abort-cycle-timing tb-core-swap-abort-cycle-timing tb-core-block-abort-cycle-timing tb-core-thumb-data-abort-cycle-timing tb-core-thumb-data-abort-store-cycle-timing tb-core-thumb-interwork-cycle-timing tb-core-thumb-swi-cycle-timing tb-core-thumb-undefined-cycle-timing tb-core-thumb-unsupported-cycle-timing tb-core-thumb-interrupt-cycle-timing tb-core-thumb-prefetch-abort-cycle-timing tb-core-thumb-interwork tb-core-thumb-shift tb-core-thumb-addsub tb-core-thumb-condbranch tb-core-thumb-hireg tb-core-thumb-alu tb-core-thumb-ldr-pc tb-core-thumb-ls-imm tb-core-thumb-ls-imm-wait tb-core-thumb-ls-reg tb-core-thumb-ls-sp tb-core-thumb-add-addr tb-core-thumb-sp-adjust tb-core-thumb-block tb-core-thumb-block-wait tb-core-thumb-stack tb-core-thumb-swi tb-core-thumb-bl tb-core-thumb-undefined tb-core-thumb-unsupported tb-core-thumb-data-abort tb-core-thumb-data-abort-store tb-core-mem tb-core-mem-wait tb-core-mem-ttrans tb-core-mem-regoffset tb-core-mem-pc tb-core-mem-pc-store tb-core-mem-pc-byte tb-core-mem-pc-down tb-core-mem-unaligned tb-core-multiply tb-core-halfword tb-core-halfword-modes tb-core-psr tb-core-swap tb-core-swap-wait tb-core-block tb-core-block-wait tb-core-block-empty tb-core-block-pc tb-core-block-pc-restore tb-core-block-user tb-core-exception tb-core-undefined tb-core-interrupt tb-core-prefetch-abort tb-core-data-abort tb-core-data-abort-store tb-core-swap-abort tb-core-block-abort tb-core-block-abort-wait tb-core-exception-return

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

tb-core-cycle-timing:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_cycle_timing $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_cycle_timing.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_cycle_timing

tb-core-bus-cycle-timing:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_bus_cycle_timing $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_bus_cycle_timing.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_bus_cycle_timing

tb-core-mem-cycle-timing:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_mem_cycle_timing $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_mem_cycle_timing.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_mem_cycle_timing

tb-core-thumb-cycle-timing:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_thumb_cycle_timing $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_thumb_cycle_timing.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_thumb_cycle_timing

tb-core-exception-cycle-timing:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_exception_cycle_timing $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_exception_cycle_timing.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_exception_cycle_timing

tb-core-block-cycle-timing:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_block_cycle_timing $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_block_cycle_timing.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_block_cycle_timing

tb-core-prefetch-abort-cycle-timing:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_prefetch_abort_cycle_timing $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_prefetch_abort_cycle_timing.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_prefetch_abort_cycle_timing

tb-core-interrupt-cycle-timing:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_interrupt_cycle_timing $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_interrupt_cycle_timing.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_interrupt_cycle_timing

tb-core-data-abort-cycle-timing:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_data_abort_cycle_timing $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_data_abort_cycle_timing.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_data_abort_cycle_timing

tb-core-swap-abort-cycle-timing:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_swap_abort_cycle_timing $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_swap_abort_cycle_timing.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_swap_abort_cycle_timing

tb-core-block-abort-cycle-timing:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_block_abort_cycle_timing $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_block_abort_cycle_timing.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_block_abort_cycle_timing

tb-core-thumb-data-abort-cycle-timing:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_thumb_data_abort_cycle_timing $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_thumb_data_abort_cycle_timing.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_thumb_data_abort_cycle_timing

tb-core-thumb-data-abort-store-cycle-timing:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_thumb_data_abort_store_cycle_timing $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_thumb_data_abort_store_cycle_timing.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_thumb_data_abort_store_cycle_timing

tb-core-thumb-interwork-cycle-timing:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_thumb_interwork_cycle_timing $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_thumb_interwork_cycle_timing.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_thumb_interwork_cycle_timing

tb-core-thumb-swi-cycle-timing:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_thumb_swi_cycle_timing $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_thumb_swi_cycle_timing.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_thumb_swi_cycle_timing

tb-core-thumb-undefined-cycle-timing:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_thumb_undefined_cycle_timing $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_thumb_undefined_cycle_timing.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_thumb_undefined_cycle_timing

tb-core-thumb-unsupported-cycle-timing:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_thumb_unsupported_cycle_timing $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_thumb_unsupported_cycle_timing.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_thumb_unsupported_cycle_timing

tb-core-thumb-interrupt-cycle-timing:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_thumb_interrupt_cycle_timing $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_thumb_interrupt_cycle_timing.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_thumb_interrupt_cycle_timing

tb-core-thumb-prefetch-abort-cycle-timing:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_thumb_prefetch_abort_cycle_timing $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_thumb_prefetch_abort_cycle_timing.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_thumb_prefetch_abort_cycle_timing

tb-core-cosim-smoke:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_cosim_trace $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_cosim_trace.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_cosim_trace +memh=sim/model/arm7tdmi_cosim_smoke.memh +trace=/tmp/arm7tdmi_cosim_smoke_rtl.jsonl +retired_limit=5 +max_cycles=200
	python3 scripts/cosim/compare_arm7tdmi_traces.py --rtl /tmp/arm7tdmi_cosim_smoke_rtl.jsonl --ref sim/model/arm7tdmi_cosim_smoke_ref.jsonl

tb-core-cosim-thumb-smoke:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_cosim_trace $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_cosim_trace.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_cosim_trace +memh=sim/model/arm7tdmi_cosim_thumb_smoke.memh +trace=/tmp/arm7tdmi_cosim_thumb_smoke_rtl.jsonl +retired_limit=5 +max_cycles=200
	python3 scripts/cosim/compare_arm7tdmi_traces.py --rtl /tmp/arm7tdmi_cosim_thumb_smoke_rtl.jsonl --ref sim/model/arm7tdmi_cosim_thumb_smoke_ref.jsonl

tb-core-cosim-thumb-ls-smoke:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_cosim_trace $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_cosim_trace.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_cosim_trace +memh=sim/model/arm7tdmi_cosim_thumb_ls_smoke.memh +trace=/tmp/arm7tdmi_cosim_thumb_ls_smoke_rtl.jsonl +retired_limit=10 +max_cycles=240
	python3 scripts/cosim/compare_arm7tdmi_traces.py --rtl /tmp/arm7tdmi_cosim_thumb_ls_smoke_rtl.jsonl --ref sim/model/arm7tdmi_cosim_thumb_ls_smoke_ref.jsonl

tb-core-cosim-thumb-bl-smoke:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_cosim_trace $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_cosim_trace.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_cosim_trace +memh=sim/model/arm7tdmi_cosim_thumb_bl_smoke.memh +trace=/tmp/arm7tdmi_cosim_thumb_bl_smoke_rtl.jsonl +retired_limit=7 +max_cycles=220
	python3 scripts/cosim/compare_arm7tdmi_traces.py --rtl /tmp/arm7tdmi_cosim_thumb_bl_smoke_rtl.jsonl --ref sim/model/arm7tdmi_cosim_thumb_bl_smoke_ref.jsonl

tb-core-cosim-thumb-ldr-pc-smoke:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_cosim_trace $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_cosim_trace.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_cosim_trace +memh=sim/model/arm7tdmi_cosim_thumb_ldr_pc_smoke.memh +trace=/tmp/arm7tdmi_cosim_thumb_ldr_pc_smoke_rtl.jsonl +retired_limit=6 +max_cycles=220
	python3 scripts/cosim/compare_arm7tdmi_traces.py --rtl /tmp/arm7tdmi_cosim_thumb_ldr_pc_smoke_rtl.jsonl --ref sim/model/arm7tdmi_cosim_thumb_ldr_pc_smoke_ref.jsonl

tb-core-cosim-thumb-condbranch-smoke:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_cosim_trace $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_cosim_trace.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_cosim_trace +memh=sim/model/arm7tdmi_cosim_thumb_condbranch_smoke.memh +trace=/tmp/arm7tdmi_cosim_thumb_condbranch_smoke_rtl.jsonl +retired_limit=7 +max_cycles=220
	python3 scripts/cosim/compare_arm7tdmi_traces.py --rtl /tmp/arm7tdmi_cosim_thumb_condbranch_smoke_rtl.jsonl --ref sim/model/arm7tdmi_cosim_thumb_condbranch_smoke_ref.jsonl

tb-core-cosim-thumb-interrupt-smoke:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_cosim_trace $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_cosim_trace.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_cosim_trace +memh=sim/model/arm7tdmi_cosim_thumb_interrupt_smoke.memh +trace=/tmp/arm7tdmi_cosim_thumb_interrupt_smoke_rtl.jsonl +retired_limit=12 +max_cycles=260 +irq_raise_cycle=9 +irq_clear_on_reg_addr=14
	python3 scripts/cosim/compare_arm7tdmi_traces.py --rtl /tmp/arm7tdmi_cosim_thumb_interrupt_smoke_rtl.jsonl --ref sim/model/arm7tdmi_cosim_thumb_interrupt_smoke_ref.jsonl

tb-core-cosim-thumb-prefetch-abort-smoke:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_cosim_trace $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_cosim_trace.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_cosim_trace +memh=sim/model/arm7tdmi_cosim_thumb_prefetch_abort_smoke.memh +trace=/tmp/arm7tdmi_cosim_thumb_prefetch_abort_smoke_rtl.jsonl +retired_limit=10 +max_cycles=220 +abort_on_fetch_addr=2a
	python3 scripts/cosim/compare_arm7tdmi_traces.py --rtl /tmp/arm7tdmi_cosim_thumb_prefetch_abort_smoke_rtl.jsonl --ref sim/model/arm7tdmi_cosim_thumb_prefetch_abort_smoke_ref.jsonl

tb-core-cosim-thumb-alu-smoke:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_cosim_trace $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_cosim_trace.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_cosim_trace +memh=sim/model/arm7tdmi_cosim_thumb_alu_smoke.memh +trace=/tmp/arm7tdmi_cosim_thumb_alu_smoke_rtl.jsonl +retired_limit=23 +max_cycles=360
	python3 scripts/cosim/compare_arm7tdmi_traces.py --rtl /tmp/arm7tdmi_cosim_thumb_alu_smoke_rtl.jsonl --ref sim/model/arm7tdmi_cosim_thumb_alu_smoke_ref.jsonl

tb-core-cosim-thumb-hireg-smoke:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_cosim_trace $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_cosim_trace.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_cosim_trace +memh=sim/model/arm7tdmi_cosim_thumb_hireg_smoke.memh +trace=/tmp/arm7tdmi_cosim_thumb_hireg_smoke_rtl.jsonl +retired_limit=11 +max_cycles=220
	python3 scripts/cosim/compare_arm7tdmi_traces.py --rtl /tmp/arm7tdmi_cosim_thumb_hireg_smoke_rtl.jsonl --ref sim/model/arm7tdmi_cosim_thumb_hireg_smoke_ref.jsonl

tb-core-cosim-thumb-shift-smoke:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_cosim_trace $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_cosim_trace.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_cosim_trace +memh=sim/model/arm7tdmi_cosim_thumb_shift_smoke.memh +trace=/tmp/arm7tdmi_cosim_thumb_shift_smoke_rtl.jsonl +retired_limit=9 +max_cycles=180
	python3 scripts/cosim/compare_arm7tdmi_traces.py --rtl /tmp/arm7tdmi_cosim_thumb_shift_smoke_rtl.jsonl --ref sim/model/arm7tdmi_cosim_thumb_shift_smoke_ref.jsonl

tb-core-cosim-thumb-addsub-smoke:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_cosim_trace $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_cosim_trace.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_cosim_trace +memh=sim/model/arm7tdmi_cosim_thumb_addsub_smoke.memh +trace=/tmp/arm7tdmi_cosim_thumb_addsub_smoke_rtl.jsonl +retired_limit=10 +max_cycles=200
	python3 scripts/cosim/compare_arm7tdmi_traces.py --rtl /tmp/arm7tdmi_cosim_thumb_addsub_smoke_rtl.jsonl --ref sim/model/arm7tdmi_cosim_thumb_addsub_smoke_ref.jsonl

tb-core-cosim-thumb-stack-smoke:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_cosim_trace $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_cosim_trace.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_cosim_trace +memh=sim/model/arm7tdmi_cosim_thumb_stack_smoke.memh +trace=/tmp/arm7tdmi_cosim_thumb_stack_smoke_rtl.jsonl +retired_limit=12 +max_cycles=220
	python3 scripts/cosim/compare_arm7tdmi_traces.py --rtl /tmp/arm7tdmi_cosim_thumb_stack_smoke_rtl.jsonl --ref sim/model/arm7tdmi_cosim_thumb_stack_smoke_ref.jsonl

tb-core-cosim-thumb-ls-reg-smoke:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_cosim_trace $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_cosim_trace.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_cosim_trace +memh=sim/model/arm7tdmi_cosim_thumb_ls_reg_smoke.memh +trace=/tmp/arm7tdmi_cosim_thumb_ls_reg_smoke_rtl.jsonl +retired_limit=18 +max_cycles=320
	python3 scripts/cosim/compare_arm7tdmi_traces.py --rtl /tmp/arm7tdmi_cosim_thumb_ls_reg_smoke_rtl.jsonl --ref sim/model/arm7tdmi_cosim_thumb_ls_reg_smoke_ref.jsonl

tb-core-cosim-thumb-ls-sp-smoke:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_cosim_trace $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_cosim_trace.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_cosim_trace +memh=sim/model/arm7tdmi_cosim_thumb_ls_sp_smoke.memh +trace=/tmp/arm7tdmi_cosim_thumb_ls_sp_smoke_rtl.jsonl +retired_limit=7 +max_cycles=200
	python3 scripts/cosim/compare_arm7tdmi_traces.py --rtl /tmp/arm7tdmi_cosim_thumb_ls_sp_smoke_rtl.jsonl --ref sim/model/arm7tdmi_cosim_thumb_ls_sp_smoke_ref.jsonl

tb-core-cosim-thumb-sp-adjust-smoke:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_cosim_trace $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_cosim_trace.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_cosim_trace +memh=sim/model/arm7tdmi_cosim_thumb_sp_adjust_smoke.memh +trace=/tmp/arm7tdmi_cosim_thumb_sp_adjust_smoke_rtl.jsonl +retired_limit=7 +max_cycles=160
	python3 scripts/cosim/compare_arm7tdmi_traces.py --rtl /tmp/arm7tdmi_cosim_thumb_sp_adjust_smoke_rtl.jsonl --ref sim/model/arm7tdmi_cosim_thumb_sp_adjust_smoke_ref.jsonl

tb-core-cosim-thumb-add-addr-smoke:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_cosim_trace $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_cosim_trace.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_cosim_trace +memh=sim/model/arm7tdmi_cosim_thumb_add_addr_smoke.memh +trace=/tmp/arm7tdmi_cosim_thumb_add_addr_smoke_rtl.jsonl +retired_limit=7 +max_cycles=160
	python3 scripts/cosim/compare_arm7tdmi_traces.py --rtl /tmp/arm7tdmi_cosim_thumb_add_addr_smoke_rtl.jsonl --ref sim/model/arm7tdmi_cosim_thumb_add_addr_smoke_ref.jsonl

tb-core-cosim-arm-swi-smoke:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_cosim_trace $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_cosim_trace.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_cosim_trace +memh=sim/model/arm7tdmi_cosim_arm_swi_smoke.memh +trace=/tmp/arm7tdmi_cosim_arm_swi_smoke_rtl.jsonl +retired_limit=5 +max_cycles=220
	python3 scripts/cosim/compare_arm7tdmi_traces.py --rtl /tmp/arm7tdmi_cosim_arm_swi_smoke_rtl.jsonl --ref sim/model/arm7tdmi_cosim_arm_swi_smoke_ref.jsonl

tb-core-cosim-thumb-swi-smoke:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_cosim_trace $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_cosim_trace.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_cosim_trace +memh=sim/model/arm7tdmi_cosim_thumb_swi_smoke.memh +trace=/tmp/arm7tdmi_cosim_thumb_swi_smoke_rtl.jsonl +retired_limit=5 +max_cycles=240
	python3 scripts/cosim/compare_arm7tdmi_traces.py --rtl /tmp/arm7tdmi_cosim_thumb_swi_smoke_rtl.jsonl --ref sim/model/arm7tdmi_cosim_thumb_swi_smoke_ref.jsonl

tb-core-cosim-thumb-undefined-smoke:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_cosim_trace $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_cosim_trace.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_cosim_trace +memh=sim/model/arm7tdmi_cosim_thumb_undefined_smoke.memh +trace=/tmp/arm7tdmi_cosim_thumb_undefined_smoke_rtl.jsonl +retired_limit=5 +max_cycles=240
	python3 scripts/cosim/compare_arm7tdmi_traces.py --rtl /tmp/arm7tdmi_cosim_thumb_undefined_smoke_rtl.jsonl --ref sim/model/arm7tdmi_cosim_thumb_undefined_smoke_ref.jsonl

tb-core-cosim-thumb-unsupported-smoke:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_cosim_trace $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_cosim_trace.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_cosim_trace +memh=sim/model/arm7tdmi_cosim_thumb_unsupported_smoke.memh +trace=/tmp/arm7tdmi_cosim_thumb_unsupported_smoke_rtl.jsonl +retired_limit=5 +max_cycles=240
	python3 scripts/cosim/compare_arm7tdmi_traces.py --rtl /tmp/arm7tdmi_cosim_thumb_unsupported_smoke_rtl.jsonl --ref sim/model/arm7tdmi_cosim_thumb_unsupported_smoke_ref.jsonl

tb-core-cosim-arm-undefined-smoke:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_cosim_trace $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_cosim_trace.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_cosim_trace +memh=sim/model/arm7tdmi_cosim_arm_undefined_smoke.memh +trace=/tmp/arm7tdmi_cosim_arm_undefined_smoke_rtl.jsonl +retired_limit=5 +max_cycles=160
	python3 scripts/cosim/compare_arm7tdmi_traces.py --rtl /tmp/arm7tdmi_cosim_arm_undefined_smoke_rtl.jsonl --ref sim/model/arm7tdmi_cosim_arm_undefined_smoke_ref.jsonl

tb-core-cosim-arm-branch-smoke:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_cosim_trace $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_cosim_trace.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_cosim_trace +memh=sim/model/arm7tdmi_cosim_arm_branch_smoke.memh +trace=/tmp/arm7tdmi_cosim_arm_branch_smoke_rtl.jsonl +retired_limit=6 +max_cycles=180
	python3 scripts/cosim/compare_arm7tdmi_traces.py --rtl /tmp/arm7tdmi_cosim_arm_branch_smoke_rtl.jsonl --ref sim/model/arm7tdmi_cosim_arm_branch_smoke_ref.jsonl

tb-core-cosim-arm-mem-smoke:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_cosim_trace $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_cosim_trace.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_cosim_trace +memh=sim/model/arm7tdmi_cosim_arm_mem_smoke.memh +trace=/tmp/arm7tdmi_cosim_arm_mem_smoke_rtl.jsonl +retired_limit=16 +max_cycles=320
	python3 scripts/cosim/compare_arm7tdmi_traces.py --rtl /tmp/arm7tdmi_cosim_arm_mem_smoke_rtl.jsonl --ref sim/model/arm7tdmi_cosim_arm_mem_smoke_ref.jsonl

tb-core-cosim-arm-halfword-smoke:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_cosim_trace $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_cosim_trace.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_cosim_trace +memh=sim/model/arm7tdmi_cosim_arm_halfword_smoke.memh +trace=/tmp/arm7tdmi_cosim_arm_halfword_smoke_rtl.jsonl +retired_limit=8 +max_cycles=220
	python3 scripts/cosim/compare_arm7tdmi_traces.py --rtl /tmp/arm7tdmi_cosim_arm_halfword_smoke_rtl.jsonl --ref sim/model/arm7tdmi_cosim_arm_halfword_smoke_ref.jsonl

tb-core-cosim-arm-swap-smoke:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_cosim_trace $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_cosim_trace.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_cosim_trace +memh=sim/model/arm7tdmi_cosim_arm_swap_smoke.memh +trace=/tmp/arm7tdmi_cosim_arm_swap_smoke_rtl.jsonl +retired_limit=7 +max_cycles=220
	python3 scripts/cosim/compare_arm7tdmi_traces.py --rtl /tmp/arm7tdmi_cosim_arm_swap_smoke_rtl.jsonl --ref sim/model/arm7tdmi_cosim_arm_swap_smoke_ref.jsonl

tb-core-cosim-arm-block-smoke:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_cosim_trace $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_cosim_trace.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_cosim_trace +memh=sim/model/arm7tdmi_cosim_arm_block_smoke.memh +trace=/tmp/arm7tdmi_cosim_arm_block_smoke_rtl.jsonl +retired_limit=18 +max_cycles=420
	python3 scripts/cosim/compare_arm7tdmi_traces.py --rtl /tmp/arm7tdmi_cosim_arm_block_smoke_rtl.jsonl --ref sim/model/arm7tdmi_cosim_arm_block_smoke_ref.jsonl

tb-core-cosim-arm-block-empty-smoke:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_cosim_trace $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_cosim_trace.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_cosim_trace +memh=sim/model/arm7tdmi_cosim_arm_block_empty_smoke.memh +trace=/tmp/arm7tdmi_cosim_arm_block_empty_smoke_rtl.jsonl +retired_limit=6 +max_cycles=220
	python3 scripts/cosim/compare_arm7tdmi_traces.py --rtl /tmp/arm7tdmi_cosim_arm_block_empty_smoke_rtl.jsonl --ref sim/model/arm7tdmi_cosim_arm_block_empty_smoke_ref.jsonl

tb-core-cosim-arm-block-user-smoke:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_cosim_trace $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_cosim_trace.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_cosim_trace +memh=sim/model/arm7tdmi_cosim_arm_block_user_smoke.memh +trace=/tmp/arm7tdmi_cosim_arm_block_user_smoke_rtl.jsonl +retired_limit=14 +max_cycles=360
	python3 scripts/cosim/compare_arm7tdmi_traces.py --rtl /tmp/arm7tdmi_cosim_arm_block_user_smoke_rtl.jsonl --ref sim/model/arm7tdmi_cosim_arm_block_user_smoke_ref.jsonl

tb-core-cosim-arm-block-pc-smoke:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_cosim_trace $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_cosim_trace.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_cosim_trace +memh=sim/model/arm7tdmi_cosim_arm_block_pc_smoke.memh +trace=/tmp/arm7tdmi_cosim_arm_block_pc_smoke_rtl.jsonl +retired_limit=6 +max_cycles=220
	python3 scripts/cosim/compare_arm7tdmi_traces.py --rtl /tmp/arm7tdmi_cosim_arm_block_pc_smoke_rtl.jsonl --ref sim/model/arm7tdmi_cosim_arm_block_pc_smoke_ref.jsonl

tb-core-cosim-arm-block-pc-restore-smoke:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_cosim_trace $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_cosim_trace.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_cosim_trace +memh=sim/model/arm7tdmi_cosim_arm_block_pc_restore_smoke.memh +trace=/tmp/arm7tdmi_cosim_arm_block_pc_restore_smoke_rtl.jsonl +retired_limit=8 +max_cycles=260 +irq_raise_cycle=1 +irq_clear_on_reg_addr=14 +irq_clear_on_reg_data=10
	python3 scripts/cosim/compare_arm7tdmi_traces.py --rtl /tmp/arm7tdmi_cosim_arm_block_pc_restore_smoke_rtl.jsonl --ref sim/model/arm7tdmi_cosim_arm_block_pc_restore_smoke_ref.jsonl

cosim-mame-smoke-script:
	python3 scripts/cosim/render_mame_debug_script.py --cpu :maincpu --trace-output /tmp/arm7tdmi_cosim_smoke_mame_raw.trace --stop 0x10 --output /tmp/arm7tdmi_cosim_smoke_mame.cmd

cosim-mame-cm2005-smoke-rom:
	python3 scripts/cosim/prepare_mame_rom_set.py --memh sim/model/arm7tdmi_cosim_smoke.memh --set-name cm2005 --rom-name a29800uv.11b --rom-size 0x100000 --output-root /tmp/arm7tdmi_mame_roms --placeholder-rom a29800uv.12b:0x100000 --placeholder-rom gal16v8.10a:0x40000 --placeholder-rom gal16v8.10b:0x40000

cosim-mame-cm2005-smoke-prepare: cosim-mame-cm2005-smoke-rom cosim-mame-smoke-script

cosim-mame-cm2005-thumb-smoke-rom:
	python3 scripts/cosim/prepare_mame_rom_set.py --memh sim/model/arm7tdmi_cosim_thumb_smoke.memh --set-name cm2005 --rom-name a29800uv.11b --rom-size 0x100000 --output-root /tmp/arm7tdmi_mame_roms --placeholder-rom a29800uv.12b:0x100000 --placeholder-rom gal16v8.10a:0x40000 --placeholder-rom gal16v8.10b:0x40000

cosim-mame-cm2005-thumb-ls-smoke-rom:
	python3 scripts/cosim/prepare_mame_rom_set.py --memh sim/model/arm7tdmi_cosim_thumb_ls_smoke.memh --set-name cm2005 --rom-name a29800uv.11b --rom-size 0x100000 --output-root /tmp/arm7tdmi_mame_roms --placeholder-rom a29800uv.12b:0x100000 --placeholder-rom gal16v8.10a:0x40000 --placeholder-rom gal16v8.10b:0x40000

cosim-mame-cm2005-thumb-bl-smoke-rom:
	python3 scripts/cosim/prepare_mame_rom_set.py --memh sim/model/arm7tdmi_cosim_thumb_bl_smoke.memh --set-name cm2005 --rom-name a29800uv.11b --rom-size 0x100000 --output-root /tmp/arm7tdmi_mame_roms --placeholder-rom a29800uv.12b:0x100000 --placeholder-rom gal16v8.10a:0x40000 --placeholder-rom gal16v8.10b:0x40000

cosim-mame-cm2005-thumb-ldr-pc-smoke-rom:
	python3 scripts/cosim/prepare_mame_rom_set.py --memh sim/model/arm7tdmi_cosim_thumb_ldr_pc_smoke.memh --set-name cm2005 --rom-name a29800uv.11b --rom-size 0x100000 --output-root /tmp/arm7tdmi_mame_roms --placeholder-rom a29800uv.12b:0x100000 --placeholder-rom gal16v8.10a:0x40000 --placeholder-rom gal16v8.10b:0x40000

cosim-mame-cm2005-thumb-condbranch-smoke-rom:
	python3 scripts/cosim/prepare_mame_rom_set.py --memh sim/model/arm7tdmi_cosim_thumb_condbranch_smoke.memh --set-name cm2005 --rom-name a29800uv.11b --rom-size 0x100000 --output-root /tmp/arm7tdmi_mame_roms --placeholder-rom a29800uv.12b:0x100000 --placeholder-rom gal16v8.10a:0x40000 --placeholder-rom gal16v8.10b:0x40000

cosim-mame-cm2005-thumb-interrupt-smoke-rom:
	python3 scripts/cosim/prepare_mame_rom_set.py --memh sim/model/arm7tdmi_cosim_thumb_interrupt_smoke.memh --set-name cm2005 --rom-name a29800uv.11b --rom-size 0x100000 --output-root /tmp/arm7tdmi_mame_roms --placeholder-rom a29800uv.12b:0x100000 --placeholder-rom gal16v8.10a:0x40000 --placeholder-rom gal16v8.10b:0x40000

cosim-mame-cm2005-thumb-prefetch-abort-smoke-rom:
	python3 scripts/cosim/prepare_mame_rom_set.py --memh sim/model/arm7tdmi_cosim_thumb_prefetch_abort_smoke.memh --set-name cm2005 --rom-name a29800uv.11b --rom-size 0x100000 --output-root /tmp/arm7tdmi_mame_roms --placeholder-rom a29800uv.12b:0x100000 --placeholder-rom gal16v8.10a:0x40000 --placeholder-rom gal16v8.10b:0x40000

cosim-mame-cm2005-thumb-alu-smoke-rom:
	python3 scripts/cosim/prepare_mame_rom_set.py --memh sim/model/arm7tdmi_cosim_thumb_alu_smoke.memh --set-name cm2005 --rom-name a29800uv.11b --rom-size 0x100000 --output-root /tmp/arm7tdmi_mame_roms --placeholder-rom a29800uv.12b:0x100000 --placeholder-rom gal16v8.10a:0x40000 --placeholder-rom gal16v8.10b:0x40000

cosim-mame-cm2005-thumb-hireg-smoke-rom:
	python3 scripts/cosim/prepare_mame_rom_set.py --memh sim/model/arm7tdmi_cosim_thumb_hireg_smoke.memh --set-name cm2005 --rom-name a29800uv.11b --rom-size 0x100000 --output-root /tmp/arm7tdmi_mame_roms --placeholder-rom a29800uv.12b:0x100000 --placeholder-rom gal16v8.10a:0x40000 --placeholder-rom gal16v8.10b:0x40000

cosim-mame-cm2005-thumb-shift-smoke-rom:
	python3 scripts/cosim/prepare_mame_rom_set.py --memh sim/model/arm7tdmi_cosim_thumb_shift_smoke.memh --set-name cm2005 --rom-name a29800uv.11b --rom-size 0x100000 --output-root /tmp/arm7tdmi_mame_roms --placeholder-rom a29800uv.12b:0x100000 --placeholder-rom gal16v8.10a:0x40000 --placeholder-rom gal16v8.10b:0x40000

cosim-mame-cm2005-thumb-addsub-smoke-rom:
	python3 scripts/cosim/prepare_mame_rom_set.py --memh sim/model/arm7tdmi_cosim_thumb_addsub_smoke.memh --set-name cm2005 --rom-name a29800uv.11b --rom-size 0x100000 --output-root /tmp/arm7tdmi_mame_roms --placeholder-rom a29800uv.12b:0x100000 --placeholder-rom gal16v8.10a:0x40000 --placeholder-rom gal16v8.10b:0x40000

cosim-mame-cm2005-thumb-stack-smoke-rom:
	python3 scripts/cosim/prepare_mame_rom_set.py --memh sim/model/arm7tdmi_cosim_thumb_stack_smoke.memh --set-name cm2005 --rom-name a29800uv.11b --rom-size 0x100000 --output-root /tmp/arm7tdmi_mame_roms --placeholder-rom a29800uv.12b:0x100000 --placeholder-rom gal16v8.10a:0x40000 --placeholder-rom gal16v8.10b:0x40000

cosim-mame-cm2005-thumb-ls-reg-smoke-rom:
	python3 scripts/cosim/prepare_mame_rom_set.py --memh sim/model/arm7tdmi_cosim_thumb_ls_reg_smoke.memh --set-name cm2005 --rom-name a29800uv.11b --rom-size 0x100000 --output-root /tmp/arm7tdmi_mame_roms --placeholder-rom a29800uv.12b:0x100000 --placeholder-rom gal16v8.10a:0x40000 --placeholder-rom gal16v8.10b:0x40000

cosim-mame-cm2005-thumb-ls-sp-smoke-rom:
	python3 scripts/cosim/prepare_mame_rom_set.py --memh sim/model/arm7tdmi_cosim_thumb_ls_sp_smoke.memh --set-name cm2005 --rom-name a29800uv.11b --rom-size 0x100000 --output-root /tmp/arm7tdmi_mame_roms --placeholder-rom a29800uv.12b:0x100000 --placeholder-rom gal16v8.10a:0x40000 --placeholder-rom gal16v8.10b:0x40000

cosim-mame-cm2005-thumb-sp-adjust-smoke-rom:
	python3 scripts/cosim/prepare_mame_rom_set.py --memh sim/model/arm7tdmi_cosim_thumb_sp_adjust_smoke.memh --set-name cm2005 --rom-name a29800uv.11b --rom-size 0x100000 --output-root /tmp/arm7tdmi_mame_roms --placeholder-rom a29800uv.12b:0x100000 --placeholder-rom gal16v8.10a:0x40000 --placeholder-rom gal16v8.10b:0x40000

cosim-mame-cm2005-thumb-add-addr-smoke-rom:
	python3 scripts/cosim/prepare_mame_rom_set.py --memh sim/model/arm7tdmi_cosim_thumb_add_addr_smoke.memh --set-name cm2005 --rom-name a29800uv.11b --rom-size 0x100000 --output-root /tmp/arm7tdmi_mame_roms --placeholder-rom a29800uv.12b:0x100000 --placeholder-rom gal16v8.10a:0x40000 --placeholder-rom gal16v8.10b:0x40000

cosim-mame-cm2005-arm-swi-smoke-rom:
	python3 scripts/cosim/prepare_mame_rom_set.py --memh sim/model/arm7tdmi_cosim_arm_swi_smoke.memh --set-name cm2005 --rom-name a29800uv.11b --rom-size 0x100000 --output-root /tmp/arm7tdmi_mame_roms --placeholder-rom a29800uv.12b:0x100000 --placeholder-rom gal16v8.10a:0x40000 --placeholder-rom gal16v8.10b:0x40000

cosim-mame-cm2005-thumb-swi-smoke-rom:
	python3 scripts/cosim/prepare_mame_rom_set.py --memh sim/model/arm7tdmi_cosim_thumb_swi_smoke.memh --set-name cm2005 --rom-name a29800uv.11b --rom-size 0x100000 --output-root /tmp/arm7tdmi_mame_roms --placeholder-rom a29800uv.12b:0x100000 --placeholder-rom gal16v8.10a:0x40000 --placeholder-rom gal16v8.10b:0x40000

cosim-mame-cm2005-thumb-undefined-smoke-rom:
	python3 scripts/cosim/prepare_mame_rom_set.py --memh sim/model/arm7tdmi_cosim_thumb_undefined_smoke.memh --set-name cm2005 --rom-name a29800uv.11b --rom-size 0x100000 --output-root /tmp/arm7tdmi_mame_roms --placeholder-rom a29800uv.12b:0x100000 --placeholder-rom gal16v8.10a:0x40000 --placeholder-rom gal16v8.10b:0x40000

cosim-mame-cm2005-thumb-unsupported-smoke-rom:
	python3 scripts/cosim/prepare_mame_rom_set.py --memh sim/model/arm7tdmi_cosim_thumb_unsupported_smoke.memh --set-name cm2005 --rom-name a29800uv.11b --rom-size 0x100000 --output-root /tmp/arm7tdmi_mame_roms --placeholder-rom a29800uv.12b:0x100000 --placeholder-rom gal16v8.10a:0x40000 --placeholder-rom gal16v8.10b:0x40000

cosim-mame-cm2005-arm-undefined-smoke-rom:
	python3 scripts/cosim/prepare_mame_rom_set.py --memh sim/model/arm7tdmi_cosim_arm_undefined_smoke.memh --set-name cm2005 --rom-name a29800uv.11b --rom-size 0x100000 --output-root /tmp/arm7tdmi_mame_roms --placeholder-rom a29800uv.12b:0x100000 --placeholder-rom gal16v8.10a:0x40000 --placeholder-rom gal16v8.10b:0x40000

cosim-mame-cm2005-arm-branch-smoke-rom:
	python3 scripts/cosim/prepare_mame_rom_set.py --memh sim/model/arm7tdmi_cosim_arm_branch_smoke.memh --set-name cm2005 --rom-name a29800uv.11b --rom-size 0x100000 --output-root /tmp/arm7tdmi_mame_roms --placeholder-rom a29800uv.12b:0x100000 --placeholder-rom gal16v8.10a:0x40000 --placeholder-rom gal16v8.10b:0x40000

cosim-mame-cm2005-arm-mem-smoke-rom:
	python3 scripts/cosim/prepare_mame_rom_set.py --memh sim/model/arm7tdmi_cosim_arm_mem_smoke.memh --set-name cm2005 --rom-name a29800uv.11b --rom-size 0x100000 --output-root /tmp/arm7tdmi_mame_roms --placeholder-rom a29800uv.12b:0x100000 --placeholder-rom gal16v8.10a:0x40000 --placeholder-rom gal16v8.10b:0x40000

cosim-mame-cm2005-arm-halfword-smoke-rom:
	python3 scripts/cosim/prepare_mame_rom_set.py --memh sim/model/arm7tdmi_cosim_arm_halfword_smoke.memh --set-name cm2005 --rom-name a29800uv.11b --rom-size 0x100000 --output-root /tmp/arm7tdmi_mame_roms --placeholder-rom a29800uv.12b:0x100000 --placeholder-rom gal16v8.10a:0x40000 --placeholder-rom gal16v8.10b:0x40000

cosim-mame-cm2005-arm-swap-smoke-rom:
	python3 scripts/cosim/prepare_mame_rom_set.py --memh sim/model/arm7tdmi_cosim_arm_swap_smoke.memh --set-name cm2005 --rom-name a29800uv.11b --rom-size 0x100000 --output-root /tmp/arm7tdmi_mame_roms --placeholder-rom a29800uv.12b:0x100000 --placeholder-rom gal16v8.10a:0x40000 --placeholder-rom gal16v8.10b:0x40000

cosim-mame-cm2005-arm-block-smoke-rom:
	python3 scripts/cosim/prepare_mame_rom_set.py --memh sim/model/arm7tdmi_cosim_arm_block_smoke.memh --set-name cm2005 --rom-name a29800uv.11b --rom-size 0x100000 --output-root /tmp/arm7tdmi_mame_roms --placeholder-rom a29800uv.12b:0x100000 --placeholder-rom gal16v8.10a:0x40000 --placeholder-rom gal16v8.10b:0x40000

cosim-mame-cm2005-arm-block-empty-smoke-rom:
	python3 scripts/cosim/prepare_mame_rom_set.py --memh sim/model/arm7tdmi_cosim_arm_block_empty_smoke.memh --set-name cm2005 --rom-name a29800uv.11b --rom-size 0x100000 --output-root /tmp/arm7tdmi_mame_roms --placeholder-rom a29800uv.12b:0x100000 --placeholder-rom gal16v8.10a:0x40000 --placeholder-rom gal16v8.10b:0x40000

cosim-mame-cm2005-arm-block-user-smoke-rom:
	python3 scripts/cosim/prepare_mame_rom_set.py --memh sim/model/arm7tdmi_cosim_arm_block_user_smoke.memh --set-name cm2005 --rom-name a29800uv.11b --rom-size 0x100000 --output-root /tmp/arm7tdmi_mame_roms --placeholder-rom a29800uv.12b:0x100000 --placeholder-rom gal16v8.10a:0x40000 --placeholder-rom gal16v8.10b:0x40000

cosim-mame-cm2005-arm-block-pc-smoke-rom:
	python3 scripts/cosim/prepare_mame_rom_set.py --memh sim/model/arm7tdmi_cosim_arm_block_pc_smoke.memh --set-name cm2005 --rom-name a29800uv.11b --rom-size 0x100000 --output-root /tmp/arm7tdmi_mame_roms --placeholder-rom a29800uv.12b:0x100000 --placeholder-rom gal16v8.10a:0x40000 --placeholder-rom gal16v8.10b:0x40000

cosim-mame-cm2005-arm-block-pc-restore-smoke-rom:
	python3 scripts/cosim/prepare_mame_rom_set.py --memh sim/model/arm7tdmi_cosim_arm_block_pc_restore_smoke.memh --set-name cm2005 --rom-name a29800uv.11b --rom-size 0x100000 --output-root /tmp/arm7tdmi_mame_roms --placeholder-rom a29800uv.12b:0x100000 --placeholder-rom gal16v8.10a:0x40000 --placeholder-rom gal16v8.10b:0x40000

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

tb-core-thumb-ls-imm-wait:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_thumb_ls_imm_wait $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_thumb_ls_imm_wait.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_thumb_ls_imm_wait

tb-core-thumb-ls-reg:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_thumb_ls_reg $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_thumb_ls_reg.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_thumb_ls_reg

tb-core-thumb-ls-sp:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_thumb_ls_sp $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_thumb_ls_sp.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_thumb_ls_sp

tb-core-thumb-add-addr:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_thumb_add_addr $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_thumb_add_addr.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_thumb_add_addr

tb-core-thumb-sp-adjust:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_thumb_sp_adjust $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_thumb_sp_adjust.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_thumb_sp_adjust

tb-core-thumb-block:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_thumb_block $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_thumb_block.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_thumb_block

tb-core-thumb-block-wait:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_thumb_block_wait $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_thumb_block_wait.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_thumb_block_wait

tb-core-thumb-stack:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_thumb_stack $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_thumb_stack.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_thumb_stack

tb-core-thumb-swi:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_thumb_swi $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_thumb_swi.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_thumb_swi

tb-core-thumb-bl:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_thumb_bl $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_thumb_bl.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_thumb_bl

tb-core-thumb-undefined:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_thumb_undefined $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_thumb_undefined.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_thumb_undefined

tb-core-thumb-unsupported:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_thumb_unsupported $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_thumb_unsupported.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_thumb_unsupported

tb-core-thumb-data-abort:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_thumb_data_abort $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_thumb_data_abort.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_thumb_data_abort

tb-core-thumb-data-abort-store:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_thumb_data_abort_store $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_thumb_data_abort_store.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_thumb_data_abort_store

tb-core-mem:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_mem $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_mem.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_mem

tb-core-mem-wait:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_mem_wait $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_mem_wait.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_mem_wait

tb-core-mem-ttrans:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_mem_ttrans $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_mem_ttrans.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_mem_ttrans

tb-core-mem-regoffset:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_mem_regoffset $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_mem_regoffset.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_mem_regoffset

tb-core-mem-pc:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_mem_pc $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_mem_pc.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_mem_pc

tb-core-mem-pc-store:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_mem_pc_store $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_mem_pc_store.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_mem_pc_store

tb-core-mem-pc-byte:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_mem_pc_byte $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_mem_pc_byte.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_mem_pc_byte

tb-core-mem-pc-down:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_mem_pc_down $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_mem_pc_down.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_mem_pc_down

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

tb-core-swap-wait:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_swap_wait $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_swap_wait.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_swap_wait

tb-core-block:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_block $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_block.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_block

tb-core-block-wait:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_block_wait $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_block_wait.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_block_wait

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

tb-core-prefetch-abort:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_prefetch_abort $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_prefetch_abort.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_prefetch_abort

tb-core-data-abort:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_data_abort $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_data_abort.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_data_abort

tb-core-data-abort-store:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_data_abort_store $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_data_abort_store.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_data_abort_store

tb-core-swap-abort:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_swap_abort $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_swap_abort.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_swap_abort

tb-core-block-abort:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_block_abort $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_block_abort.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_block_abort

tb-core-block-abort-wait:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_block_abort_wait $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_block_abort_wait.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_block_abort_wait

tb-core-exception-return:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module tb_arm7tdmi_core_exception_return $(RTL_FILES) sim/tb/sv/tb_arm7tdmi_core_exception_return.sv
	./$(BUILD_DIR)/Vtb_arm7tdmi_core_exception_return

clean:
	rm -rf $(BUILD_DIR)
