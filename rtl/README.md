# ARM7TDMI SystemVerilog Core

This is a fresh SystemVerilog implementation scaffold informed by the reference
HDL models in `ref/`, especially:

- `ref/GBA_MiSTer/rtl/gba_cpu.vhd` for practical ARM7TDMI-class register banking,
  condition handling, fetch/decode/execute organization, and GBA timing concerns.
- `ref/ARM7-verilog-chsasank` for simple Verilog datapath partitioning.
- `ref/processi-vhdl-adamaq01` for compact educational control/datapath split.

The first version deliberately separates reusable ARM7TDMI core behavior from
GBA-specific wait states, prefetch, DMA, and savestate machinery. The external
bus already exposes transfer size and cycle class so those pieces can be added
without changing the core boundary.

## Current Modules

| File | Purpose |
| --- | --- |
| `arm7tdmi_pkg.sv` | Shared mode, condition, ALU, shift, and bus type definitions. |
| `arm7tdmi_cond.sv` | ARM condition-code evaluator. |
| `arm7tdmi_arm_decode.sv` | Structured ARM-state instruction classifier and field decoder. |
| `arm7tdmi_shifter.sv` | ARM barrel-shifter primitive for immediate-shift operands. |
| `arm7tdmi_alu.sv` | ARM data-processing ALU operations and NZCV generation. |
| `arm7tdmi_regfile.sv` | Banked ARM register file foundation, CPSR, and SPSR storage. |
| `arm7tdmi_core.sv` | Initial fetch/execute top level with a simple memory handshake. |

## Verification Entry Points

The repository Makefile provides the current regression surface:

- `make lint`
- `make tb-cond`
- `make tb-arm-decode`
- `make tb-shifter`
- `make tb-alu`
- `make tb-regfile`
- `make tb-core-branch`
- `make tb-core-mem`
- `make tb-core-mem-regoffset`
- `make tb-core-mem-pc`
- `make tb-core-mem-unaligned`
- `make tb-core-multiply`
- `make tb-core-halfword`
- `make tb-core-psr`
- `make tb-core-swap`
- `make tb-core-block`
- `make tb-core-block-pc`
- `make tb-core-block-pc-restore`
- `make tb-core-block-user`
- `make tb-core-exception`
- `make tb-core-undefined`
- `make tb-core-interrupt`
- `make tb-core-exception-return`
- `make test`

## Implemented So Far

- Reset to supervisor mode with IRQ/FIQ masked.
- ARM condition evaluation.
- ARM data-processing ALU operation set.
- Immediate operands and register operands with immediate shifts.
- Register-specified shifts, including shifter carry propagation into flag-setting ALU operations.
- ARM branch and branch-with-link.
- ARM branch-and-exchange to ARM-state targets.
- ARM multiply and multiply-accumulate, including N/Z flag updates for `MULS`.
- ARM non-accumulating long multiply `UMULL`/`SMULL`.
- ARM immediate halfword transfer group: `LDRH`, `STRH`, `LDRSB`, and `LDRSH`.
- ARM PSR transfers: `MRS Rd, CPSR/SPSR` and register/immediate-form `MSR CPSR/SPSR_fields` byte-mask writes.
- ARM swap transfers: `SWP` and `SWPB`.
- ARM block data transfer foundation: increment/decrement after/before `LDM`/`STM`, with optional writeback when `Rn` is not in the register list.
- ARM block load to `PC`, including `LDM ... {pc}^` CPSR restore from SPSR.
- ARM privileged block-transfer user-bank forms: `LDM/STM ...^` without `PC`.
- ARM single data transfer foundation: immediate and scaled-register pre/post-indexed up/down word/byte `LDR`/`STR`, load/store writeback, word `LDR` to `PC`, and unaligned word-load rotation.
- ARM SWI exception entry to the SVC vector with LR/SPSR save.
- ARM undefined-instruction exception entry to the UND vector for undefined and coprocessor instruction classes.
- ARM IRQ and FIQ exception entry, with mask-bit checks and FIQ priority over IRQ.
- Data-processing exception return through `Rd == r15` and `S == 1`, restoring CPSR from SPSR.
- Register banking foundation for FIQ, IRQ, SVC, ABT, and UND modes.
- Bus request fields for address, read/write, transfer size, and cycle class.

## Explicit Gaps

- Thumb decode and execution.
- Remaining block transfer edge cases and load/store edge cases.
- Remaining abort exceptions.
- JTAG/EmbeddedICE/debug behavior.
- Cycle-accurate instruction timing.
- GBA-specific wait-state and prefetch behavior.

The next sensible step is to add a small self-checking Verilator testbench around
`arm7tdmi_alu`, `arm7tdmi_shifter`, and the core fetch path before expanding the
instruction decoder.
