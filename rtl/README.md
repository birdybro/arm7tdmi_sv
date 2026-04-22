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
- `make tb-thumb-decode`
- `make tb-shifter`
- `make tb-alu`
- `make tb-regfile`
- `make tb-core-branch`
- `make tb-core-cycle-timing`
- `make tb-core-bus-cycle-timing`
- `make tb-core-mem-cycle-timing`
- `make tb-core-thumb-cycle-timing`
- `make tb-core-exception-cycle-timing`
- `make tb-core-block-cycle-timing`
- `make tb-core-prefetch-abort-cycle-timing`
- `make tb-core-interrupt-cycle-timing`
- `make tb-core-data-abort-cycle-timing`
- `make tb-core-swap-abort-cycle-timing`
- `make tb-core-block-abort-cycle-timing`
- `make tb-core-thumb-data-abort-cycle-timing`
- `make tb-core-thumb-data-abort-store-cycle-timing`
- `make tb-core-thumb-interwork-cycle-timing`
- `make tb-core-thumb-swi-cycle-timing`
- `make tb-core-thumb-undefined-cycle-timing`
- `make tb-core-thumb-unsupported-cycle-timing`
- `make tb-core-thumb-interrupt-cycle-timing`
- `make tb-core-thumb-prefetch-abort-cycle-timing`
- `make tb-core-cosim-smoke`
- `make tb-core-cosim-thumb-smoke`
- `make tb-core-cosim-thumb-ls-smoke`
- `make tb-core-cosim-thumb-bl-smoke`
- `make tb-core-thumb-interwork`
- `make tb-core-thumb-shift`
- `make tb-core-thumb-addsub`
- `make tb-core-thumb-condbranch`
- `make tb-core-thumb-hireg`
- `make tb-core-thumb-alu`
- `make tb-core-thumb-ldr-pc`
- `make tb-core-thumb-ls-imm`
- `make tb-core-thumb-ls-imm-wait`
- `make tb-core-thumb-ls-reg`
- `make tb-core-thumb-ls-sp`
- `make tb-core-thumb-add-addr`
- `make tb-core-thumb-sp-adjust`
- `make tb-core-thumb-block`
- `make tb-core-thumb-block-wait`
- `make tb-core-thumb-stack`
- `make tb-core-thumb-swi`
- `make tb-core-thumb-bl`
- `make tb-core-thumb-undefined`
- `make tb-core-thumb-unsupported`
- `make tb-core-thumb-data-abort`
- `make tb-core-thumb-data-abort-store`
- `make tb-core-mem`
- `make tb-core-mem-wait`
- `make tb-core-mem-ttrans`
- `make tb-core-mem-regoffset`
- `make tb-core-mem-pc`
- `make tb-core-mem-pc-store`
- `make tb-core-mem-pc-byte`
- `make tb-core-mem-pc-down`
- `make tb-core-mem-unaligned`
- `make tb-core-multiply`
- `make tb-core-halfword`
- `make tb-core-halfword-modes`
- `make tb-core-psr`
- `make tb-core-swap`
- `make tb-core-swap-wait`
- `make tb-core-block`
- `make tb-core-block-wait`
- `make tb-core-block-empty`
- `make tb-core-block-pc`
- `make tb-core-block-pc-restore`
- `make tb-core-block-user`
- `make tb-core-exception`
- `make tb-core-undefined`
- `make tb-core-interrupt`
- `make tb-core-prefetch-abort`
- `make tb-core-data-abort`
- `make tb-core-data-abort-store`
- `make tb-core-swap-abort`
- `make tb-core-block-abort`
- `make tb-core-block-abort-wait`
- `make tb-core-exception-return`
- `make test`

## Implemented So Far

- Reset to supervisor mode with IRQ/FIQ masked.
- ARM condition evaluation.
- ARM data-processing ALU operation set.
- Immediate operands and register operands with immediate shifts.
- Register-specified shifts, including shifter carry propagation into flag-setting ALU operations.
- ARM branch and branch-with-link.
- ARM branch-and-exchange to ARM-state and Thumb-state targets.
- Initial Thumb execution: immediate shifts, immediate `MOV`, `CMP`, `ADD`,
  `SUB`, unconditional branch, and `BX`.
- ARM multiply and multiply-accumulate, including N/Z flag updates for `MULS`.
- ARM long multiply `UMULL`, `UMLAL`, `SMULL`, and `SMLAL`.
- ARM halfword transfer group: `LDRH`, `STRH`, `LDRSB`, and `LDRSH`, including immediate/register offsets and base writeback.
- ARM PSR transfers: `MRS Rd, CPSR/SPSR` and register/immediate-form `MSR CPSR/SPSR_fields` byte-mask writes.
- ARM swap transfers: `SWP` and `SWPB`.
- ARM block data transfer foundation: increment/decrement after/before `LDM`/`STM`, with optional writeback when `Rn` is not in the register list.
- ARM empty-list block transfer behavior, modeled as an `r15` transfer over a 64-byte base span.
- ARM block load to `PC`, including `LDM ... {pc}^` CPSR restore from SPSR.
- ARM privileged block-transfer user-bank forms: `LDM/STM ...^` without `PC`.
- ARM single data transfer foundation: immediate and scaled-register pre/post-indexed up/down word/byte `LDR`/`STR`, post-indexed `LDRT`/`STRT` and `LDRBT`/`STRBT`, PC-relative load/store forms without writeback, load/store writeback, word `LDR` to `PC`, and unaligned word-load rotation.
- ARM SWI exception entry to the SVC vector with LR/SPSR save.
- ARM undefined-instruction exception entry to the UND vector for undefined and coprocessor instruction classes.
- ARM IRQ and FIQ exception entry, with mask-bit checks and FIQ priority over IRQ.
- ARM prefetch-abort exception entry from the bus abort signal.
- ARM data-abort exception entry from the bus abort signal for data-memory, swap, and block-transfer transactions.
- Data-processing exception return through `Rd == r15` and `S == 1`, restoring CPSR from SPSR.
- Register banking foundation for FIQ, IRQ, SVC, ABT, and UND modes.
- Bus request fields for address, read/write, transfer size, and cycle class.
- Optional cycle-timing mode with visible internal cycles, early-termination-style multiply timing, and sequential cycle marking for multi-beat block and swap transfers.
- Initial processor-level co-simulation harness: generic RTL retire trace bench, JSON trace compare script, and scripted MAME trace render/normalization flow.

## Explicit Gaps

- Most Thumb decode and execution groups.
- Remaining block transfer edge cases and load/store edge cases.
- Precise abort restart and external-memory side-effect behavior beyond the current bus-abort smoke coverage.
- JTAG/EmbeddedICE/debug behavior.
- Full ARM7TDMI cycle-accurate timing coverage across all instruction classes and exception paths.
- GBA-specific wait-state and prefetch behavior.

The next sensible step is to add a small self-checking Verilator testbench around
`arm7tdmi_alu`, `arm7tdmi_shifter`, and the core fetch path before expanding the
instruction decoder.
