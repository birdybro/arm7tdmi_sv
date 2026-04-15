# ARM7TDMI Implementation Notes

These notes summarize implementation-relevant details from the downloaded Arm
manuals. They are not a substitute for the PDFs in this directory.

## Core Identity

- ARM7TDMI implements ARM architecture v4T: 32-bit ARM instructions plus 16-bit
  Thumb instructions.
- The core is a simple three-stage pipeline: fetch, decode, execute.
- It has a unified memory interface. Instruction and data accesses share the
  external bus; there is no Harvard split at the core boundary.
- The name suffixes are useful reminders:
  - `T`: Thumb instruction support.
  - `D`: JTAG debug support.
  - `M`: long multiply support.
  - `I`: EmbeddedICE debug logic.

## Programmer Model

- Visible general-purpose state is based around registers `r0` through `r15`.
- `r13` is conventionally stack pointer, `r14` link register, and `r15` program
  counter.
- The CPSR holds condition flags, interrupt mask bits, Thumb/ARM state, and mode.
- Privileged exception modes bank some registers. The important banks for an RTL
  model are:
  - FIQ banks `r8` through `r14`.
  - IRQ, supervisor, abort, undefined, and system/user behavior for `r13`/`r14`.
  - SPSR exists for exception modes that must restore prior CPSR state.
- ARM state uses word-aligned 32-bit instruction fetches. Thumb state uses
  halfword-aligned 16-bit instruction fetches.

## Exceptions

- Exception entry forces ARM state, even if the interrupted code was running in
  Thumb state.
- Standard vector addresses are at the low vector table starting at `0x00000000`.
- Common vectors:
  - Reset: `0x00`
  - Undefined instruction: `0x04`
  - Software interrupt: `0x08`
  - Prefetch abort: `0x0C`
  - Data abort: `0x10`
  - IRQ: `0x18`
  - FIQ: `0x1C`
- Exception entry saves return state in the relevant banked link register and
  saves CPSR into the mode SPSR when applicable.
- IRQ and FIQ masking is controlled by CPSR bits. FIQ has higher priority than IRQ.

## Instruction Behavior

- ARM instructions are generally conditionally executed using the top condition
  field, except for encodings that repurpose that space in later architectures.
- Data processing operations can use immediate values or shifted register
  operands.
- The shifter is part of the operand path. Correct carry-out behavior from shifts
  matters because many instructions update CPSR `C`.
- Load/store behavior must match ARMv4T alignment and rotation rules. Check the
  architecture manual and the ARM7TDMI TRM before simplifying unaligned access.
- `BX` is the key interworking instruction. Bit 0 of the branch target selects
  Thumb or ARM state.
- Long multiply and multiply-accumulate instructions are part of the TDMI profile.

## Memory Interface

- ARM7TDMI distinguishes nonsequential, sequential, internal, and coprocessor
  cycles. These cycle classifications affect bus timing and wait-state behavior.
- The core presents pipelined addresses: instruction fetch addresses can be ahead
  of the instruction currently executing.
- External memory systems must handle byte, halfword, and word transfers.
- For hardware timing, the TRM timing chapters and signal appendices are more
  authoritative than emulator code.
- The AMBA ARM7TDMI interface document describes a wrapper-style AMBA integration,
  useful if this project grows a bus adapter around a raw core.

## Debug / JTAG

- ARM7TDMI includes JTAG TAP and EmbeddedICE-style debug support.
- Debug entry can occur through breakpoint/watchpoint mechanisms or external
  debug requests, depending on integration.
- The Debug Communications Channel is a mechanism for transferring data between
  the processor and debugger.
- The TRMs include scan chains, debug registers, and TAP behavior. These are
  useful if the SystemVerilog model aims to include hardware debug compatibility;
  they can otherwise be stubbed behind a clean boundary.

## Timing Model

- For a cycle-accurate RTL core, use the TRM instruction cycle timing tables, not
  a GBA emulator's approximate timings.
- For a functional core, prioritize architecturally visible state first:
  registers, CPSR/SPSR, exception return addresses, memory access size/address,
  ARM/Thumb decode, and abort behavior.
- If targeting Game Boy Advance compatibility, combine the core rules here with
  GBA bus and wait-state timing references. The ARM7TDMI manuals describe the
  CPU, not the whole GBA memory system.

## Recommended Reading Order

1. `ARM_DDI_0210C_ARM7TDMI_r4p1_TRM.pdf`
2. `ARM_DDI_0100I_ARM_Architecture_Reference_Manual.pdf`
3. `ARM_DDI_0234B_ARM7TDMI-S_r4p3_TRM.pdf` if modeling the synthesizable `-S` core.
4. `ARM_DDI_0045D_AMBA_ARM7TDMI_Interface_Datasheet.pdf` if adding AMBA wrapping.
5. The quick-reference PDFs for decode-table sanity checks only.
