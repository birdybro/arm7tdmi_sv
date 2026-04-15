# ARM7TDMI RTL Completion Plan

The goal is to grow this into a reference-quality ARM7TDMI SystemVerilog core in
layers: architecturally correct functional RTL first, then exceptions and Thumb,
then memory/timing accuracy, then GBA-oriented cycle behavior. The MiSTer GBA
core is a high-value behavioral reference, but should not be copied structurally
because it mixes CPU, GBA wait states, savestates, and practical emulator logic
in one large block.

## Phase 1: Project Structure And Verification Harness

1. Add simulation layout:
   - `sim/tb/` for SystemVerilog testbenches.
   - `sim/model/` for reference helpers or generated traces.
   - `sim/mem/` for simple memory models.
   - `tests/asm/` for small ARM/Thumb assembly programs.
   - `tests/bin/` or another generated build output path ignored by Git.
   - `scripts/` for build, assemble, trace, and regression helpers.

2. Add build automation:
   - `Makefile` or `justfile`.
   - Targets: `lint`, `tb-alu`, `tb-shifter`, `tb-regfile`, `tb-core-smoke`,
     `test`, and `clean`.
   - Use Verilator first since it is already installed and lint passes.

3. Add a simple bus/memory testbench:
   - Word-addressable memory.
   - Configurable wait states.
   - Read/write logging.
   - Optional instruction trace output.

4. Add CI-ready commands:
   - `verilator --lint-only -Wall -sv -f rtl/files.f`
   - Verilator simulation for unit tests.
   - Later add GitHub Actions if desired.

## Phase 2: Leaf Module Correctness

Focus on small deterministic units before expanding the core.

1. ALU testbench:
   - Test all 16 data-processing opcodes.
   - Verify result and NZCV.
   - Cover signed overflow, unsigned carry/borrow, zero result, negative result,
     ADC/SBC/RSC carry-in behavior, and TST/TEQ/CMP/CMN no-write behavior.

2. Shifter testbench:
   - Test LSL, LSR, ASR, ROR, and RRX.
   - Shift amounts: `0`, `1`, `2`, `31`, `32`, `33`, and `255`.
   - Verify carry-out behavior.
   - Distinguish immediate-shift semantics from register-shift semantics.
   - Current scaffold only supports immediate shift; extend to register shift
     after tests exist.

3. Condition-code testbench:
   - Exhaust all condition codes across representative NZCV combinations.
   - Explicitly check `NV` behavior for ARMv4T.

4. Register file testbench:
   - User/system shared registers.
   - FIQ banked `r8-r14`.
   - IRQ/SVC/ABT/UND banked `r13-r14`.
   - SPSR per exception mode.
   - PC read value behavior.
   - CPSR mode switching.

## Phase 3: ARM Data-Processing Completion

Complete ARM-state data-processing before touching memory operations.

1. Decode cleanup:
   - Add `arm7tdmi_arm_decode.sv`.
   - Output a structured decoded instruction record.
   - Keep decode separate from execute.

2. Complete operand2 support:
   - Immediate rotate.
   - Register immediate shifts.
   - Register register-specified shifts.
   - Correct PC operand behavior when `r15` is used.
   - Correct special shift cases from ARMv4T.

3. Complete data-processing semantics:
   - `ANDS/EORS/SUBS/...`
   - `MOVS pc, lr` and exception-return-like paths.
   - Write to `r15` behavior.
   - CPSR update suppression when condition fails.
   - Undefined encodings.

4. Add directed assembly tests:
   - One small program per opcode family.
   - Self-check by storing results to known memory addresses.
   - Testbench checks the memory signature.

## Phase 4: Branch, Interworking, And Pipeline Semantics

1. Implement ARM branch fully:
   - `B`
   - `BL`
   - Correct link value.
   - Signed offset.
   - Pipeline-visible PC behavior.

2. Implement `BX`:
   - Switch ARM/Thumb state from bit 0.
   - Align target address.
   - Flush fetch path.
   - Add tests for ARM-to-Thumb and Thumb-to-ARM transitions.

3. Make PC behavior consistent:
   - ARM reads of `r15` return current instruction address plus 8.
   - Thumb reads of `r15` return current instruction address plus 4.
   - Branches flush instruction stream.
   - Sequential/nonsequential bus cycle marking follows fetch redirection.

## Phase 5: Load/Store And Memory Interface

1. Implement single data transfer:
   - `LDR/STR`
   - Byte/word transfers.
   - Pre/post-index.
   - Up/down.
   - Writeback.
   - Immediate/register offset.
   - Shifted register offset.

2. Implement halfword and signed transfers:
   - `LDRH/STRH`
   - `LDRSB`
   - `LDRSH`

3. Implement alignment behavior:
   - ARMv4T word load rotation rules.
   - Halfword alignment behavior.
   - Decide whether to model strict bus fault inputs separately from GBA behavior.

4. Refine memory bus:
   - Add transaction phase state.
   - Support wait states cleanly.
   - Add abort inputs for prefetch abort and data abort.
   - Preserve bus cycle type: nonsequential, sequential, internal, coprocessor.

5. Add tests:
   - Directed memory access tests.
   - Randomized load/store address and size tests against a software reference
     model.

## Phase 6: Multiply, Swap, Block Transfer

1. Multiply:
   - `MUL`
   - `MLA`
   - `UMULL/UMLAL`
   - `SMULL/SMLAL`
   - Correct flags.
   - Configurable cycle behavior later.

2. Swap:
   - `SWP`
   - `SWPB`

3. Block data transfer:
   - `LDM/STM`
   - All addressing modes.
   - Writeback.
   - Empty register list behavior.
   - `S` bit behavior.
   - `r15` in list.
   - User-mode register transfer from privileged modes.

4. Add tests:
   - Directed instruction tests.
   - Compare against emulator traces from MAME, mGBA, or jgenesis where practical.

## Phase 7: PSR, Exceptions, And Privileged Behavior

1. Implement PSR transfer:
   - `MRS`
   - `MSR`
   - CPSR field masks.
   - SPSR access rules.
   - User-mode restrictions.

2. Implement exception entry:
   - Reset.
   - Undefined instruction.
   - SWI.
   - Prefetch abort.
   - Data abort.
   - IRQ.
   - FIQ.

3. Implement exception return:
   - `MOVS pc, lr`
   - `SUBS pc, lr, #imm`
   - `LDM ...^` with PC.
   - Restore CPSR from SPSR where required.

4. Implement priority and masking:
   - IRQ/FIQ masks.
   - FIQ priority.
   - Aborts versus interrupts.
   - Exceptions always enter ARM state.

5. Add tests:
   - One directed test per exception type.
   - Nested exception tests.
   - Banked register preservation tests.

## Phase 8: Thumb Implementation

1. Add `arm7tdmi_thumb_decode.sv`.

2. Implement Thumb groups:
   - Move shifted register.
   - Add/subtract.
   - Immediate operations.
   - ALU operations.
   - Hi-register operations.
   - `BX`.
   - PC-relative load.
   - Load/store register offset.
   - Load/store sign-extended byte/halfword.
   - Load/store immediate offset.
   - SP-relative load/store.
   - Load address.
   - Add offset to SP.
   - Push/pop.
   - Multiple load/store.
   - Conditional branch.
   - SWI.
   - Unconditional branch.
   - Long branch with link.

3. Implement Thumb PC behavior:
   - PC reads as current instruction plus 4.
   - Halfword alignment.
   - Correct BL two-instruction sequence.

4. Add tests:
   - Directed Thumb instruction tests.
   - ARM/Thumb interworking tests.
   - GBA-style boot snippets.

## Phase 9: Cycle Timing And ARM7TDMI Bus Accuracy

After functional correctness is stable, add timing.

1. Add timing mode parameter:
   - `FUNCTIONAL`
   - `ARM7TDMI_CYCLE`
   - Possibly `GBA_COMPAT`

2. Implement instruction cycle timing:
   - Use TRM instruction cycle tables.
   - Model internal cycles.
   - Model sequential/nonsequential fetch transitions.
   - Model multiply early termination if applicable.

3. Implement memory cycle behavior:
   - Wait-state handshaking.
   - Sequential access classification.
   - Nonsequential on branch/fetch refill.
   - Abort timing.

4. Compare against:
   - ARM TRM timing tables.
   - MiSTer GBA behavior for GBA-specific cases.
   - Known GBA timing tests eventually.

## Phase 10: GBA Integration Layer

Keep this separate from the reusable CPU core.

1. Add `platform/gba/` or `rtl/gba/`.
2. Implement GBA memory wait-state controller:
   - BIOS.
   - EWRAM.
   - IWRAM.
   - IO.
   - Palette/VRAM/OAM.
   - Game Pak regions.
   - SRAM.
3. Implement GBA prefetch behavior outside the CPU core.
4. Add DMA bus-arbitration hooks.
5. Add halt/stop interaction.
6. Compare against MiSTer `gba_cpu.vhd` and GBA test ROMs.

## Phase 11: Reference Comparison Strategy

Use multiple references because each has different strengths.

1. MiSTer GBA core:
   - Best for GBA timing and integration behavior.
   - Good for practical CPU state flow.
   - Not a clean complete ARM7TDMI specification model.

2. ARM manuals:
   - Authoritative for architecture, exceptions, bus, debug, and timing.

3. MAME, ares, and higan:
   - Useful for instruction semantics and disassembly.
   - Good for checking odd instruction behavior.

4. mGBA, NanoBoyAdvance, and rustboyadvance:
   - Useful for GBA-specific CPU behavior and test ROM compatibility.

5. HDL models:
   - Useful for structure and datapath ideas.
   - Treat educational models as inspiration, not authority.

## Phase 12: Testing Progression

1. Unit tests:
   - ALU.
   - Shifter.
   - Condition logic.
   - Register file.
   - Decoder.

2. Directed instruction tests:
   - Assembly programs with memory signatures.

3. Co-simulation:
   - Run instruction streams through RTL and a software reference.
   - Compare registers, CPSR, PC, and memory writes after each retired instruction.

4. Random instruction tests:
   - Start with data-processing only.
   - Add memory with constrained valid addresses.
   - Add modes and exceptions last.

5. Public test ROMs:
   - ARMwrestler.
   - GBA CPU tests.
   - mGBA test suites where licensing permits local use.

6. Timing tests:
   - Keep separate from functional tests.
   - Assert cycle counts and bus cycle classifications.

## Suggested Next Milestone

1. Add Verilator C++ or SystemVerilog testbenches for:
   - ALU.
   - Shifter.
   - Condition logic.
   - Register file.

2. Fix any behavior those tests expose.

3. Add a tiny core smoke test:
   - Fetch `MOV r0, #1`.
   - Fetch `ADD r1, r0, #2`.
   - Fetch `B .`.
   - Verify register writes and PC flow.

This creates a stable verification base before the decoder grows.
