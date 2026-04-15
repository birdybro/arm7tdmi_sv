# ARM7TDMI HDL Model Development Reference

This document is the working technical reference for developing the
SystemVerilog ARM7TDMI model in this repository. It distills the downloaded ARM
manuals, HDL models, FPGA implementations, emulators, and simulators into an
implementation-oriented guide.

It is not a substitute for the official ARM documentation in `doc/`. When this
document and an ARM manual disagree, treat the ARM manual as authoritative.

## Local Reference Map

### Authoritative Architecture And Core References

| Local file | Use for |
| --- | --- |
| `doc/ARM_DDI_0210C_ARM7TDMI_r4p1_TRM.pdf` | Primary ARM7TDMI Rev 4 core behavior, programmer model, memory interface, debug, timing, signal descriptions. |
| `doc/ARM_DDI_0029G_ARM7TDMI_r3_TRM.pdf` | Rev 3 behavior and historical comparison. Useful when emulators or older HDL models match Rev 3 assumptions. |
| `doc/ARM_DDI_0234B_ARM7TDMI-S_r4p3_TRM.pdf` | Synthesizable ARM7TDMI-S reference. Important if the project later targets a synthesizable `-S` style wrapper. |
| `doc/ARM_DDI_0084F_ARM7TDMI-S_r3_TRM.pdf` | Older ARM7TDMI-S reference. |
| `doc/ARM_DDI_0100I_ARM_Architecture_Reference_Manual.pdf` | ARM architecture behavior, instruction semantics, ARM/Thumb programmer model, PSR rules. |
| `doc/ARM_DDI_0045D_AMBA_ARM7TDMI_Interface_Datasheet.pdf` | AMBA wrapper/interface behavior, if an AMBA-facing integration layer is added. |
| `doc/ARM7TDMI_Instruction_Set_Quick_Reference_UTexas.pdf` | Quick decode sanity checks. |
| `doc/ARM7TDMI_instruction_set_reference_UW_Madison.pdf` | Quick instruction reference mirror. |

### HDL / FPGA References

| Local path | Use for | Caveats |
| --- | --- | --- |
| `ref/GBA_MiSTer/rtl/gba_cpu.vhd` | Very useful practical model for GBA-compatible ARM7TDMI-class CPU behavior, banked registers, flags, Thumb decode, bus timing, wait states, and prefetch. | It is a GBA CPU integration, not a clean reusable ARM7TDMI core. It mixes CPU logic with GBA wait states, DMA, savestates, halt, debug, and MiSTer concerns. |
| `ref/ARM7-verilog-chsasank` | Simple Verilog datapath partitioning, ALU/shifter/register-file ideas, educational pipeline structure. | Educational and incomplete. Do not treat as architectural authority. |
| `ref/processi-vhdl-adamaq01` | Compact educational VHDL control/datapath split. | Simplified subset. Useful for structure, not completeness. |
| `ref/ARM9-compatible-soft-CPU-core` | Adjacent ARMv4-style soft CPU implementation ideas. | ARM9-compatible, not exact ARM7TDMI. |

### Emulator / Simulator References

| Local path | Use for | Caveats |
| --- | --- | --- |
| `ref/mame/src/devices/cpu/arm7` | Mature C++ ARM7/Thumb implementation, exception flow, register banking, disassembler, device integration. | Emulator code, not cycle-accurate RTL. Some behavior may be generalized across ARM variants. |
| `ref/ares/ares/component/processor/arm7tdmi` | Clean modern ARM7TDMI component layout, registers, algorithms, ARM/Thumb instructions, tests. | Software model; useful as semantic reference and trace oracle. |
| `ref/higan/higan/component/processor/arm7tdmi` | Related predecessor to ares; useful cross-check. | Software model. |
| `ref/mgba/src/arm` | GBA-oriented ARM/Thumb decode and execution. | GBA emulator behavior may blend CPU and platform assumptions. |
| `ref/NanoBoyAdvance/src/nba/src/arm` | GBA ARM7TDMI core and generated decode tables. | Emulator-oriented. |
| `ref/rustboyadvance-ng/arm7tdmi` | Rust ARM7TDMI crate with GDB/debug hooks. | Emulator-oriented. |
| `ref/jgenesis/cpu/arm7tdmi-emu` | Rust ARM7TDMI emulator used by multiple system cores. | Emulator-oriented. |
| `ref/uARM` and `ref/skyeye-sourceforge` | ARM simulator references for broader behavior comparison. | Older codebases; verify against manuals. |

## Design Intent For This Repository

The RTL should be a reusable ARM7TDMI CPU core first, with GBA-specific behavior
added as a separate integration layer. This keeps the design testable and avoids
hard-wiring one platform's memory map or wait-state behavior into the CPU.

Recommended layering:

1. `rtl/arm7tdmi_*`: reusable CPU core and core-local support modules.
2. `rtl/bus/`: optional bus adapters, memory protocol bridges, or AMBA wrapper.
3. `rtl/gba/`: GBA-specific wait states, prefetch, halt/stop, DMA arbitration,
   and memory-map integration.
4. `sim/`: reusable simulation memory, trace, and testbench infrastructure.
5. `tests/`: assembly tests, generated binaries, expected signatures, and
   reference traces.

The CPU core should expose enough bus metadata to support timing later:

- address
- read/write
- transfer size
- transfer cycle class: nonsequential, sequential, internal, coprocessor
- write data
- read data
- ready/wait
- abort/error inputs, added when exceptions are implemented

## Core Architectural Target

The target is ARM7TDMI implementing ARM architecture v4T:

- 32-bit ARM instruction set.
- 16-bit Thumb instruction set.
- ARM/Thumb interworking through `BX`.
- Three-stage pipeline model: fetch, decode, execute.
- Unified instruction/data memory interface.
- Banked registers for privileged modes.
- CPSR and SPSR behavior.
- IRQ and FIQ exceptions.
- Undefined, SWI, prefetch abort, data abort, and reset exceptions.
- Multiply and long multiply instructions.
- JTAG/EmbeddedICE compatibility can be a later optional scope.

The `TDMI` suffix matters:

- `T`: Thumb support.
- `D`: JTAG debug support.
- `M`: multiply/long multiply support.
- `I`: EmbeddedICE debug support.

For the initial HDL model, it is acceptable to defer `D` and `I` behavior behind
explicit stubs, but the module boundaries should not make later debug support
impossible.

## Current RTL Snapshot

As of this document, the new implementation has:

- `rtl/arm7tdmi_pkg.sv`
- `rtl/arm7tdmi_cond.sv`
- `rtl/arm7tdmi_shifter.sv`
- `rtl/arm7tdmi_alu.sv`
- `rtl/arm7tdmi_regfile.sv`
- `rtl/arm7tdmi_core.sv`

Current implemented behavior is intentionally narrow:

- Reset to supervisor mode with IRQ/FIQ masked.
- ARM condition evaluation.
- ARM data-processing ALU operations.
- Immediate operands and register operands with immediate shifts.
- ARM branch and branch-with-link.
- Register banking foundation.
- Simple fetch/execute bus handshake.

Major missing areas:

- Thumb.
- Load/store.
- Register-specified shifts.
- Multiply and long multiply.
- Block transfer.
- PSR transfer.
- Exceptions and aborts.
- IRQ/FIQ entry.
- Debug/JTAG/EmbeddedICE.
- Cycle-accurate timing.
- GBA wait states and prefetch.

## Programmer Model Requirements

### Registers

Architectural registers are `r0-r15`:

- `r0-r7`: unbanked general-purpose registers.
- `r8-r12`: unbanked except in FIQ mode.
- `r13`: stack pointer by convention.
- `r14`: link register.
- `r15`: program counter.

Banking requirements:

| Mode | Banked registers |
| --- | --- |
| User | none beyond shared user bank |
| System | uses user registers, privileged CPSR access rules differ |
| FIQ | `r8-r14`, `SPSR_fiq` |
| IRQ | `r13-r14`, `SPSR_irq` |
| Supervisor | `r13-r14`, `SPSR_svc` |
| Abort | `r13-r14`, `SPSR_abt` |
| Undefined | `r13-r14`, `SPSR_und` |

Implementation guidance:

- Keep register banking in a dedicated module.
- Do not duplicate bank-selection logic throughout decode/execute.
- Include explicit read/write paths for CPSR and current-mode SPSR.
- User and System mode do not have an SPSR.
- Reads of `r15` must return the architecture-visible pipelined PC value, not
  simply the fetch address.

### CPSR

Important CPSR fields:

| Bits | Meaning |
| --- | --- |
| `31` | N flag |
| `30` | Z flag |
| `29` | C flag |
| `28` | V flag |
| `7` | I, IRQ disable |
| `6` | F, FIQ disable |
| `5` | T, Thumb state |
| `4:0` | Mode |

Valid ARM7TDMI mode values:

| Mode | CPSR bits `4:0` |
| --- | --- |
| User | `10000` |
| FIQ | `10001` |
| IRQ | `10010` |
| Supervisor | `10011` |
| Abort | `10111` |
| Undefined | `11011` |
| System | `11111` |

Reset should enter Supervisor mode with IRQ and FIQ masked.

## Pipeline And PC Semantics

The core is architecturally a three-stage pipeline. This matters even in a
functional model because reads of `r15`, branch link values, exception return
values, and fetch cycle classification depend on pipeline-visible PC behavior.

Minimum requirements:

- ARM state instruction size is 4 bytes.
- Thumb state instruction size is 2 bytes.
- ARM reads of `r15` return current instruction address plus 8.
- Thumb reads of `r15` return current instruction address plus 4.
- ARM branch link value is the address of the next ARM instruction after the
  branch, with ARM-state conventions.
- Branch, exception entry, and writes to `r15` flush/refill the instruction
  stream.
- After a branch or exception, the next fetch is nonsequential.
- Straight-line fetches are sequential after the first access.

Implementation guidance:

- Track at least one explicit architectural execute PC.
- Do not infer visible PC from the bus address in every module.
- Keep a `thumb_state` bit as part of CPSR, not a separate unsynchronized flag.
- Treat pipeline refill as a first-class control event.

## Condition Codes

ARM instructions normally include a top-nibble condition field. The condition
must be evaluated before architectural side effects are committed.

Condition table:

| Code | Mnemonic | Pass condition |
| --- | --- | --- |
| `0000` | EQ | `Z == 1` |
| `0001` | NE | `Z == 0` |
| `0010` | CS/HS | `C == 1` |
| `0011` | CC/LO | `C == 0` |
| `0100` | MI | `N == 1` |
| `0101` | PL | `N == 0` |
| `0110` | VS | `V == 1` |
| `0111` | VC | `V == 0` |
| `1000` | HI | `C == 1 && Z == 0` |
| `1001` | LS | `C == 0 || Z == 1` |
| `1010` | GE | `N == V` |
| `1011` | LT | `N != V` |
| `1100` | GT | `Z == 0 && N == V` |
| `1101` | LE | `Z == 1 || N != V` |
| `1110` | AL | always |
| `1111` | NV | architecture-specific/reserved in ARMv4T; do not treat as AL |

Implementation guidance:

- Failed conditions must suppress register writes, memory writes, CPSR/SPSR
  writes, branch state changes, and exception-like effects from that instruction.
- Failed-condition instructions still consume fetch/decode time. Cycle-accurate
  mode must account for this later.

## ARM Instruction Decode Coverage

A clean decoder should emit a structured operation record rather than scattering
bit checks across the execute state machine.

Recommended decoded fields:

- instruction set state: ARM or Thumb
- condition
- operation class
- ALU opcode
- source/destination register indices
- operand2 kind
- shift kind
- shift amount source
- immediate value
- load/store size and sign-extension mode
- pre/post-index
- up/down
- writeback
- branch target/offset
- link bit
- PSR transfer masks
- exception request kind
- undefined/unsupported flag

ARM operation classes to cover:

1. Branch and branch with link.
2. Branch and exchange.
3. Data processing.
4. PSR transfer.
5. Multiply and multiply-accumulate.
6. Long multiply.
7. Single data transfer.
8. Halfword and signed data transfer.
9. Block data transfer.
10. Single data swap.
11. Software interrupt.
12. Coprocessor instructions.
13. Undefined instructions.

Use the ARM architecture manual as the decode authority. Use MAME, ares, mGBA,
and MiSTer as cross-checks for implementation details and edge cases.

## ARM Data-Processing Requirements

Data-processing opcodes:

| Opcode | Mnemonic | Result write? | Operation |
| --- | --- | --- | --- |
| `0000` | AND | yes | `Rn & op2` |
| `0001` | EOR | yes | `Rn ^ op2` |
| `0010` | SUB | yes | `Rn - op2` |
| `0011` | RSB | yes | `op2 - Rn` |
| `0100` | ADD | yes | `Rn + op2` |
| `0101` | ADC | yes | `Rn + op2 + C` |
| `0110` | SBC | yes | `Rn - op2 - !C` |
| `0111` | RSC | yes | `op2 - Rn - !C` |
| `1000` | TST | no | flags from `Rn & op2` |
| `1001` | TEQ | no | flags from `Rn ^ op2` |
| `1010` | CMP | no | flags from `Rn - op2` |
| `1011` | CMN | no | flags from `Rn + op2` |
| `1100` | ORR | yes | `Rn | op2` |
| `1101` | MOV | yes | `op2` |
| `1110` | BIC | yes | `Rn & ~op2` |
| `1111` | MVN | yes | `~op2` |

Flag rules:

- Logical operations update `N` and `Z` from the result when `S=1`.
- Logical operations update `C` from the shifter carry when `S=1`.
- Logical operations generally preserve `V`.
- Arithmetic operations update `N`, `Z`, `C`, and `V` when `S=1`.
- Compare/test operations update flags and never write `Rd`.
- When `Rd == r15` and `S=1` in privileged modes, special SPSR-to-CPSR restore
  behavior is required for exception return paths.

Implementation guidance:

- Keep shifter carry separate from arithmetic carry.
- Implement add/sub carry and overflow using explicit 33-bit arithmetic plus
  signed overflow checks.
- Treat writes to `r15` as control-flow changes that flush the pipeline.
- Add exhaustive ALU unit tests before expanding decode.

## Operand2 And Barrel Shifter

ARM data-processing operand2 forms:

1. Immediate rotated right by an even amount.
2. Register shifted by immediate amount.
3. Register shifted by register amount.

Shift types:

- LSL
- LSR
- ASR
- ROR
- RRX, encoded as ROR with immediate amount zero

Key requirements:

- Shift amount zero has special behavior, especially for LSR, ASR, and ROR/RRX.
- Carry-out behavior is architecturally visible through logical instructions with
  `S=1`.
- Register-specified shifts consume an extra internal cycle in cycle-accurate
  mode.
- If `r15` is used as an operand, the value must match architecture-visible PC
  semantics for the current instruction state.

Implementation guidance:

- Split shifter into a combinational primitive plus operand2 decode/control.
- Unit-test shift behavior independently from the ALU.
- Add a second shifter path or mode for register-specified shifts rather than
  overloading the immediate-shift inputs.

## Branch And Interworking

Branch instructions:

- `B`: PC-relative branch.
- `BL`: PC-relative branch with link.
- `BX`: branch to register and optionally switch instruction set state.

Requirements:

- `B/BL` target is sign-extended immediate offset shifted left by 2, added to
  the ARM-visible PC base.
- `BL` writes the link register with the return address.
- `BX` uses bit 0 of the register target to choose Thumb or ARM state.
- Target address must be aligned after state selection.
- `BX` is the core interworking mechanism for ARMv4T.

Implementation guidance:

- Implement `BX` before full Thumb execution so tests can verify T-bit changes
  and target alignment.
- Treat branch target selection as a pipeline refill event.
- Avoid GBA-specific BIOS return assumptions in the CPU core.

## Load/Store Requirements

Single data transfer:

- `LDR`
- `STR`
- byte and word transfers
- pre-index and post-index
- up/down offset
- writeback
- immediate offset
- register offset
- shifted register offset

Halfword and signed transfer:

- `LDRH`
- `STRH`
- `LDRSB`
- `LDRSH`

Key architectural issues:

- Word loads from unaligned addresses have ARMv4T-specific rotation behavior.
- Store behavior must drive the correct byte lanes or transfer size.
- Loads into `r15` are control-flow changes.
- Writeback with base equal to destination has constrained/special cases; verify
  against the architecture manual and software references.
- Data abort must prevent or adjust side effects according to the instruction
  class.

Implementation guidance:

- Add a memory transaction state machine before implementing every addressing
  form.
- Keep address generation separate from bus transaction sequencing.
- Store the original base register value for writeback and abort handling.
- Add byte-lane or transfer-size semantics explicitly in the bus interface.

## Block Transfer Requirements

Block transfer instructions:

- `LDM`
- `STM`

Addressing modes:

- increment after
- increment before
- decrement after
- decrement before

Key architectural issues:

- Register list order is ascending register number.
- Empty register list behavior is non-obvious and must be checked against the
  ARM architecture manual.
- Writeback timing matters when the base register is in the list.
- Loading `r15` changes control flow.
- `S` bit behavior differs depending on whether `r15` is in the list.
- User-mode register transfer from privileged modes is required.

Implementation guidance:

- Implement as a multi-cycle micro-operation sequence.
- Compute start address, final address, and writeback value up front.
- Commit one transfer per memory transaction.
- Add dedicated tests for every addressing mode and base-in-list case.

## Multiply Requirements

Multiply instructions:

- `MUL`
- `MLA`
- `UMULL`
- `UMLAL`
- `SMULL`
- `SMLAL`

Requirements:

- Correct 32-bit and 64-bit results.
- Correct signed versus unsigned behavior.
- Correct optional flag updates.
- Correct operand register restrictions for ARM7TDMI.
- Correct multi-cycle timing later.

Implementation guidance:

- Start with functional multi-cycle or single-cycle multiply behind a clean
  interface.
- Add a parameterized timing model later.
- Verify with randomized tests against a software reference.

## PSR Transfer Requirements

Instructions:

- `MRS`
- `MSR`

Requirements:

- Access CPSR or current-mode SPSR depending on instruction fields.
- Enforce user-mode restrictions.
- Respect field masks.
- Writes to CPSR can change mode, interrupt masks, and Thumb state.
- Writes that change mode affect visible banked registers immediately after the
  architectural update point.

Implementation guidance:

- Centralize CPSR/SPSR write logic.
- Never let arbitrary modules mutate mode bits directly.
- Add tests that write CPSR mode and verify register-bank switching.

## Exception Requirements

Exception vectors:

| Exception | Vector |
| --- | --- |
| Reset | `0x00000000` |
| Undefined instruction | `0x00000004` |
| SWI | `0x00000008` |
| Prefetch abort | `0x0000000C` |
| Data abort | `0x00000010` |
| IRQ | `0x00000018` |
| FIQ | `0x0000001C` |

Exception entry must:

- Save current CPSR to the target mode's SPSR.
- Switch to the target mode.
- Set interrupt mask bits as required.
- Clear Thumb state and enter ARM state.
- Write the mode's link register with the correct return address.
- Set PC to the vector address.
- Refill the pipeline.

Implementation guidance:

- Implement exception entry through one shared helper/microsequence.
- Keep exception priority explicit.
- Model reset separately from normal exceptions.
- Add prefetch abort and data abort signals to the bus protocol before claiming
  abort support.

IRQ/FIQ guidance:

- IRQ is ignored when CPSR `I` is set.
- FIQ is ignored when CPSR `F` is set.
- FIQ has higher priority than IRQ.
- FIQ entry masks both IRQ and FIQ.
- IRQ entry masks IRQ.

## Thumb Requirements

Thumb is not optional for ARM7TDMI. It can be implemented after ARM-state
foundations are stable, but the design must not block it.

Thumb instruction groups:

1. Move shifted register.
2. Add/subtract.
3. Immediate operations.
4. ALU operations.
5. Hi-register operations.
6. `BX`.
7. PC-relative load.
8. Load/store register offset.
9. Load/store sign-extended byte/halfword.
10. Load/store immediate offset.
11. SP-relative load/store.
12. Load address.
13. Add offset to SP.
14. Push/pop.
15. Multiple load/store.
16. Conditional branch.
17. SWI.
18. Unconditional branch.
19. Long branch with link.

Implementation guidance:

- Add `arm7tdmi_thumb_decode.sv`.
- Decode Thumb into the same internal micro-op representation used by ARM where
  practical.
- Preserve Thumb-specific PC behavior: current instruction address plus 4.
- Fetch halfwords, but account for the 32-bit external bus as an integration
  concern.
- Verify ARM/Thumb interworking early.

## Memory Interface And Timing

The ARM7TDMI core distinguishes cycle classes:

- nonsequential
- sequential
- internal
- coprocessor

Cycle class matters for external memory systems and GBA wait-state behavior. The
current core interface already has `bus_cycle_o`; preserve and expand it rather
than replacing it with a generic valid/ready-only protocol.

Functional mode:

- Must produce correct architectural state.
- May complete operations in simplified cycle counts.
- Should still produce plausible bus cycle classes where easy.

Cycle-accurate mode:

- Must use TRM instruction timing.
- Must distinguish internal cycles from bus cycles.
- Must model register-specified shift extra cycles.
- Must model multiply timing.
- Must model sequential versus nonsequential memory accesses.

GBA-compatible mode:

- Belongs in a GBA integration layer where possible.
- Must account for BIOS, EWRAM, IWRAM, IO, palette, VRAM, OAM, Game Pak, and
  SRAM regions.
- Must account for GBA wait-state registers.
- Must account for Game Pak prefetch.
- Must account for DMA bus arbitration and CPU halt behavior.

MiSTer-specific observations:

- `gba_cpu.vhd` keeps memory wait arrays indexed by high address bits.
- It distinguishes 16-bit and 32-bit wait-state paths.
- It updates Game Pak wait states from `WAITCNT`.
- It models prefetch as a platform-level timing behavior.

For this project, keep those concepts but avoid copying the GBA memory map into
the reusable CPU module.

## Coprocessor And Undefined Behavior

ARM7TDMI does not normally include application coprocessors, but the ARM
instruction space includes coprocessor encodings.

Implementation guidance:

- Decode coprocessor instructions explicitly.
- Provide a coprocessor interface or return undefined behavior depending on the
  selected configuration.
- Do not silently treat unsupported instructions as NOPs.
- Undefined instruction must raise the undefined exception when implemented.

## Debug, JTAG, And EmbeddedICE

Debug support can be deferred, but the architecture includes it.

Potential future modules:

- TAP controller.
- EmbeddedICE register block.
- Breakpoint/watchpoint comparators.
- Debug request/acknowledge interface.
- Debug Communications Channel.

Implementation guidance:

- Reserve clean top-level ports or a separate debug wrapper.
- Keep debug state out of the basic functional datapath until required.
- Do not let simulation-only trace become the hardware debug interface.

## Verification Strategy

### Unit Tests

Create focused tests for:

- condition-code evaluator
- shifter
- ALU
- register file
- ARM decoder
- Thumb decoder
- address generator
- exception-entry helper

These should run quickly under Verilator.

### Directed Assembly Tests

Use small ARM/Thumb programs that write memory signatures:

- data processing
- branches and links
- `BX` interworking
- single load/store
- halfword/signed transfers
- block transfers
- multiply
- PSR transfer
- exception entry and return
- Thumb instruction groups

The testbench should load the program into memory, run until a halt convention
or timeout, then compare signature memory against expected values.

### Co-Simulation

Use software references to compare traces:

- ares/higan for clean ARM7TDMI semantics.
- MAME for mature ARM7/Thumb edge cases.
- mGBA/NanoBoyAdvance/rustboyadvance for GBA-specific behavior.

Trace fields to compare:

- retired instruction PC
- instruction word/halfword
- CPSR
- mode
- register writes
- memory writes
- exception events

Do not compare every internal cycle until the functional model is stable.

### Random Testing

Recommended progression:

1. Random data-processing instructions without `r15`.
2. Add shifts and flag updates.
3. Add branches.
4. Add load/store within a constrained memory region.
5. Add register banking and mode changes.
6. Add exceptions.
7. Add Thumb.

Random tests should use a software reference model and shrink failing cases when
possible.

### Timing Tests

Keep timing tests separate from functional tests:

- instruction cycle counts
- bus cycle classes
- wait-state insertion
- sequential/nonsequential transitions
- branch refill timing
- multiply timing
- load/store multiple timing

## RTL Coding Guidelines

- Prefer small modules with explicit packed types over one large state machine.
- Keep decoder, register file, shifter, ALU, address generation, memory
  sequencing, and exception sequencing separable.
- Use `always_comb` and `always_ff`.
- Keep default assignments at the top of combinational blocks.
- Use enums for architectural classes and states.
- Do not use inferred latches.
- Avoid platform-specific behavior in the reusable CPU core.
- Treat writes to `r15`, CPSR mode changes, and exception entry as control-flow
  events.
- Keep unsupported instruction reporting explicit until undefined exceptions are
  implemented.
- Maintain Verilator lint cleanliness with `-Wall`.

## Source-Specific Lessons

### MiSTer GBA Core

Use as a guide for:

- banked register implementation details
- CPSR-like flag and mode storage
- Thumb-to-ARM decode mapping patterns
- GBA wait-state and prefetch behavior
- practical bus timing concerns

Avoid copying:

- monolithic CPU/platform coupling
- savestate plumbing into core state
- GBA memory timing inside the reusable CPU
- debug outputs as architectural structure

### MAME

Use as a guide for:

- exception control flow
- mode switching
- CPSR/SPSR behavior
- instruction decode edge cases
- disassembly cross-checks

Avoid copying:

- emulator-specific callback structure
- host memory abstractions
- generalized ARM-family behavior without checking ARM7TDMI docs

### ares / higan

Use as a guide for:

- clean ARM7TDMI component organization
- register-bank accessors
- serialization as a list of complete architectural state
- instruction semantic clarity

Avoid copying:

- C++ execution structure directly into RTL
- emulator scheduling assumptions as hardware timing

### Educational HDL Models

Use as a guide for:

- simple ALU/shifter partitioning
- control/datapath separation
- approachable pipeline diagrams

Avoid copying:

- simplified instruction coverage
- incomplete exception behavior
- unverified flag and timing behavior

## Development Order

Recommended implementation sequence:

1. Finish unit tests for current ALU, shifter, condition, and register file.
2. Add a structured ARM decoder.
3. Complete ARM operand2, including register-specified shifts.
4. Complete ARM data-processing behavior.
5. Add branch and `BX` interworking.
6. Add memory transaction sequencing.
7. Add single load/store.
8. Add halfword/signed transfer.
9. Add multiply and long multiply.
10. Add block transfer.
11. Add PSR transfer.
12. Add exception entry and return.
13. Add Thumb decoder and execution.
14. Add functional co-simulation.
15. Add cycle timing.
16. Add GBA integration layer.
17. Add optional debug/JTAG/EmbeddedICE.

## Completion Criteria

The core should not be considered complete until:

- ARM and Thumb instruction sets are implemented for ARMv4T.
- All architectural modes and banked registers work.
- CPSR/SPSR behavior is verified.
- All standard exceptions work.
- IRQ/FIQ masking and priority are verified.
- Memory alignment behavior matches ARMv4T.
- Bus cycle class outputs are meaningful.
- Directed assembly tests pass.
- Co-simulation traces match at least one trusted software reference.
- Verilator lint is clean.
- Timing mode has documented limitations or passes TRM-derived tests.
- GBA integration behavior is tested separately from reusable core behavior.

## Immediate Next Work Items

1. Add `sim/tb/` and a Verilator test harness.
2. Add unit tests for:
   - `arm7tdmi_cond`
   - `arm7tdmi_shifter`
   - `arm7tdmi_alu`
   - `arm7tdmi_regfile`
3. Add an instruction-memory smoke test for `arm7tdmi_core`.
4. Add `arm7tdmi_arm_decode.sv`.
5. Move ARM data-processing decode out of `arm7tdmi_core.sv`.
6. Add directed tests for the current data-processing subset.

