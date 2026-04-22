# MAME Co-Sim Harness

This repository now has a first processor-level co-simulation path for the
ARM7TDMI core. The initial scope is functional retirement comparison, not cycle
comparison.

## What Exists

- `sim/tb/sv/tb_arm7tdmi_core_cosim_trace.sv`
  Runs the RTL against a flat memory image and emits one JSON trace line per
  retired instruction.
- `scripts/cosim/compare_arm7tdmi_traces.py`
  Compares RTL and reference JSONL traces.
- `scripts/cosim/mame_trace_to_json.py`
  Normalizes MAME debugger trace lines carrying a `COSIM` marker into JSONL.
- `scripts/cosim/mame_debug_trace_template.cmd`
  Template debugger script for MAME trace capture.
- `scripts/cosim/render_mame_debug_script.py`
  Renders a concrete debugger script from the template.
- `scripts/cosim/run_mame_trace_compare.py`
  Wraps script render, MAME trace normalization, and RTL-vs-MAME compare.
- `sim/model/arm7tdmi_cosim_smoke.memh`
  Small ARM-only smoke program.
- `sim/model/arm7tdmi_cosim_smoke_ref.jsonl`
  Expected retired-state reference for the smoke program.

## RTL Trace Format

The RTL trace bench emits one JSON object per retired instruction. The compare
script currently compares:

- `pc`
- `cpsr`
- `r0` through `r14`

Trace semantics:

- `pc` and `insn` identify the retired instruction.
- `cpsr` and `r0` through `r14` reflect architectural state after that
  retirement commits.

The RTL trace also includes:

- `thumb`
- `insn`
- `reg_write_*`
- `mem_write_*`

These extra fields are logged for later expansion, but they are not part of the
default compare set yet.

## Smoke Flow

Run the built-in smoke check:

```sh
make tb-core-cosim-smoke
```

This:

1. builds the generic RTL trace bench
2. runs the smoke memory image
3. writes an RTL JSON trace to `/tmp/arm7tdmi_cosim_smoke_rtl.jsonl`
4. compares it against the checked-in reference trace

## Generic RTL Trace Capture

You can run the trace bench directly with your own memory image:

```sh
./obj_dir/Vtb_arm7tdmi_core_cosim_trace \
  +memh=/abs/path/program.memh \
  +trace=/tmp/rtl_trace.jsonl \
  +retired_limit=100 \
  +max_cycles=5000
```

Memory images are byte-addressed hex files loaded with `$readmemh`, one byte per
entry.

## MAME Reference Trace Contract

The first MAME-side integration point is a debugger trace that emits one line
per instruction with a `COSIM` marker and architected register snapshot fields.

Expected line shape:

```text
COSIM pc=00000000 cpsr=000000d3 r0=00000001 ... r14=00000000
```

The included template file uses MAME debugger `trace` plus `tracelog` to emit
this form:

- `scripts/cosim/mame_debug_trace_template.cmd`

Render a concrete debugger script:

```sh
python3 scripts/cosim/render_mame_debug_script.py \
  --cpu :maincpu \
  --trace-output /tmp/mame_raw.trace \
  --stop 0x10 \
  --output /tmp/mame_cosim.cmd
```

or use the convenience target:

```sh
make cosim-mame-smoke-script
```

Then replace:

- `@@CPU@@` with the MAME CPU tag
- `@@TRACE@@` with the output filename
- `@@STOP@@` with a debugger stop condition or address

Run MAME with debugger tracing enabled:

```sh
mame <machine> -debug -debugscript /tmp/mame_cosim.cmd
```

Then normalize it:

```sh
python3 scripts/cosim/mame_trace_to_json.py \
  --input /tmp/mame_raw.trace \
  --output /tmp/mame_norm.jsonl
```

and compare:

```sh
python3 scripts/cosim/compare_arm7tdmi_traces.py \
  --rtl /tmp/rtl_trace.jsonl \
  --ref /tmp/mame_norm.jsonl
```

or use the wrapper:

```sh
python3 scripts/cosim/run_mame_trace_compare.py \
  --cpu :maincpu \
  --stop 0x10 \
  --rtl-trace /tmp/rtl_trace.jsonl \
  --raw-trace /tmp/mame_raw.trace \
  --norm-trace /tmp/mame_norm.jsonl \
  --debug-script /tmp/mame_cosim.cmd
```

## Current Limits

This is intentionally a first-pass harness:

- It is functional-only, not timing-aware.
- The default compare set is register/CPSR state per retirement.
- It is best suited to ARM ALU, branch, single-transfer, and early Thumb
  completion work.
- Multi-write instructions like block transfers are logged but not yet compared
  as rich write lists.
- The wrapper currently automates render/normalize/compare, but machine launch
  details are still driver-specific.
- A dedicated minimal MAME machine/driver for running arbitrary flat ARM7TDMI
  programs is still the next step if fully automated MAME trace generation is
  desired.
