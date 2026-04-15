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
- `make test`

## Implemented So Far

- Reset to supervisor mode with IRQ/FIQ masked.
- ARM condition evaluation.
- ARM data-processing ALU operation set.
- Immediate operands and register operands with immediate shifts.
- ARM branch and branch-with-link.
- Register banking foundation for FIQ, IRQ, SVC, ABT, and UND modes.
- Bus request fields for address, read/write, transfer size, and cycle class.

## Explicit Gaps

- Thumb decode and execution.
- Load/store, block transfer, multiply, swap, coprocessor, and PSR transfer.
- Register-specified shifts.
- Exceptions, aborts, IRQ/FIQ entry, and return-from-exception paths.
- JTAG/EmbeddedICE/debug behavior.
- Cycle-accurate instruction timing.
- GBA-specific wait-state and prefetch behavior.

The next sensible step is to add a small self-checking Verilator testbench around
`arm7tdmi_alu`, `arm7tdmi_shifter`, and the core fetch path before expanding the
instruction decoder.
