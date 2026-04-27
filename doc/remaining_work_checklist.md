# ARM7TDMI Remaining Work Checklist

This checklist is the working completion plan for turning the current core from
"broad functional model with growing timing coverage" into a drop-in-quality
hardware reimplementation.

Status labels:
- `[ ]` not started
- `[~]` in progress / partially covered
- `[x]` done

## 1. ISA Completeness

### 1.1 ARM instruction families
- `[x]` Data-processing ALU instructions
- `[x]` Branch / `BL` / `BX`
- `[x]` Multiply / multiply-accumulate / long multiply
- `[x]` Single data transfer foundation
- `[x]` Halfword and signed transfer group
- `[x]` `MRS` / `MSR`
- `[x]` `SWP` / `SWPB`
- `[x]` Block transfers foundation
- `[x]` `SWI`
- `[x]` Undefined-instruction exception path
- `[x]` Coprocessor execution path (`CDP/MCR/MRC/LDC/STC`)

### 1.2 Thumb instruction families
- `[x]` Shift/immediate ALU groups
- `[x]` Register ALU / high-register ops / `BX`
- `[x]` PC-relative load
- `[x]` Immediate/register/SP-relative load-store groups
- `[x]` Address-generation and SP-adjust groups
- `[x]` Block transfer / stack / `SWI` / `BL`
- `[x]` Exception entry coverage foundation

### 1.3 ISA edge cases still to audit and close
- `[ ]` Build a machine-readable ARM encoding checklist from the ARM7TDMI TRM/ARM ARM
- `[ ]` Build a machine-readable Thumb encoding checklist from the ARM7TDMI TRM/ARM ARM
- `[~]` Audit remaining ARM load/store edge cases
- `[~]` Audit remaining ARM block-transfer edge cases
- `[~]` Audit Thumb edge-case semantics across all currently implemented groups
- `[~]` Audit undefined/unsupported decoding behavior for architecturally invalid encodings

## 2. Timing Completeness

### 2.1 ARM cycle-timing coverage
- `[x]` Base ARM timing smoke
- `[x]` Memory load/store timing smoke
- `[x]` Halfword timing smoke
- `[x]` Swap timing smoke
- `[x]` Swap wait timing smoke
- `[x]` Block timing smoke
- `[x]` Block wait timing smoke
- `[x]` Exception / abort / interrupt timing smokes
- `[x]` Coprocessor timing / wait / abort / undefined timing smokes

### 2.2 Thumb cycle-timing coverage
- `[x]` Base Thumb timing smoke
- `[x]` Interwork timing smoke
- `[x]` `BL` timing smoke
- `[x]` Exception / abort / interrupt timing smokes
- `[x]` Immediate load/store wait timing smoke
- `[x]` Block wait timing smoke
- `[x]` Stack timing smoke
- `[x]` PC-relative load timing smoke
- `[x]` Conditional branch timing smoke
- `[x]` Register-offset load/store timing smoke
- `[x]` SP-relative load/store timing smoke
- `[x]` Address-generation timing smoke
- `[x]` SP-adjust timing smoke

### 2.3 Timing signoff work
- `[ ]` Build instruction-family timing matrix with expected fetch spacing / internal cycles / writeback timing
- `[~]` Add explicit checks for sequential vs non-sequential bus transitions where still missing
- `[ ]` Expand wait-state timing coverage for stalled fetch and stalled exception redirects
- `[~]` Review multiply timing against ARM7TDMI reference behavior for edge multiplier values

## 3. Abort / Restart / External Side Effects

- `[~]` ARM single-transfer data abort behavior
- `[~]` ARM swap abort behavior
- `[~]` ARM block abort behavior
- `[~]` Thumb data-abort behavior
- `[~]` Coprocessor abort behavior
- `[ ]` Precise restart/side-effect audit against ARM7TDMI external bus expectations
- `[ ]` Partial-transfer side-effect audit for all multi-beat sequences

## 4. Co-simulation Coverage

- `[x]` ARM branch/memory/block/swap/halfword/multiply/PSR/interrupt/coproc smokes
- `[x]` Broad Thumb functional/co-sim smoke surface
- `[x]` Unsupported/undefined trace handling foundation
- `[ ]` Expand ARM retire-trace coverage toward instruction-family completeness
- `[ ]` Expand Thumb retire-trace coverage toward instruction-family completeness
- `[ ]` Add targeted co-sim coverage for remaining edge-case and exception-restart paths

## 5. Debug / System Features

- `[ ]` Define project stance on JTAG/EmbeddedICE/debug support
- `[ ]` Implement debug/JTAG/EmbeddedICE if required for drop-in equivalence
- `[ ]` Formalize external coprocessor contract and latency/abort rules
- `[ ]` Document external bus assumptions, reset behavior, and vector behavior

## 6. FPGA / Hardware Signoff

- `[ ]` Add recurring synthesis checks for the intended FPGA target
- `[ ]` Review lint results after major RTL changes
- `[ ]` Review CDC/reset structure for hardware integration
- `[ ]` Check timing closure / critical paths / resource mapping on target FPGA
- `[ ]` Add at least one hardware-oriented regression or integration gate beyond Verilator

## 7. Current Execution Order

Near-term highest-value path:
1. Fill the remaining Thumb cycle-timing gaps that already have functional benches.
2. Convert the stale README gap list into a current-state summary once the timing matrix is broader.
3. Build the machine-readable ISA/timing checklist so remaining work is measurable.
4. Push into abort/restart precision and system-level equivalence.
5. Decide whether JTAG/EmbeddedICE is in scope for "drop-in".

## 8. Next Item

Current next item:
- `[~]` Expand explicit fetch cycle-class checks across remaining ARM/Thumb timing benches and compare multiply timing against ARM7TDMI reference behavior
