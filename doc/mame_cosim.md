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
  Wraps script render, optional MAME launch, MAME trace normalization, and
  RTL-vs-MAME compare.
- `scripts/cosim/prepare_mame_rom_set.py`
  Converts a byte-per-line `.memh` image into a disposable MAME ROM set
  directory for an existing driver.
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

## Candidate MAME Smoke Target

The current best existing MAME target for early ARM7TDMI smoke runs is
`cm2005` from `ref/mame/src/mame/skeleton/dyna_d0404.cpp`:

- CPU: `ARM7`
- reset vector in ROM at `0x00000000`
- program ROM region size: `0x100000`
- main ROM filename expected by MAME: `a29800uv.11b`

That gives a practical bridge from the repository smoke program into a real MAME
machine without writing a custom driver first.

Prepare a disposable ROM set for that machine:

```sh
make cosim-mame-cm2005-smoke-rom
```

which writes:

```text
/tmp/arm7tdmi_mame_roms/cm2005/a29800uv.11b
```

from the repository smoke image.
The prep flow also emits zero-filled placeholder companion ROMs for the `gfx`
and `pld` regions so `cm2005` will pass MAME's required-file presence checks.

Prepare both the ROM set and debugger script together:

```sh
make cosim-mame-cm2005-smoke-prepare
```

Run the complete RTL Thumb/interwork smoke on the RTL side:

```sh
make tb-core-cosim-thumb-smoke
```

Run the Thumb immediate load/store retire-trace smoke on the RTL side:

```sh
make tb-core-cosim-thumb-ls-smoke
```

Run the Thumb `BL`/return retire-trace smoke on the RTL side:

```sh
make tb-core-cosim-thumb-bl-smoke
```

Run the Thumb PC-relative `LDR` retire-trace smoke on the RTL side:

```sh
make tb-core-cosim-thumb-ldr-pc-smoke
```

Run the Thumb conditional-branch retire-trace smoke on the RTL side:

```sh
make tb-core-cosim-thumb-condbranch-smoke
```

Run the Thumb IRQ-entry retire-trace smoke on the RTL side:

```sh
make tb-core-cosim-thumb-interrupt-smoke
```

Run the Thumb prefetch-abort retire-trace smoke on the RTL side:

```sh
make tb-core-cosim-thumb-prefetch-abort-smoke
```

Run the Thumb ALU-opcode retire-trace smoke on the RTL side:

```sh
make tb-core-cosim-thumb-alu-smoke
```

Run the Thumb high-register retire-trace smoke on the RTL side:

```sh
make tb-core-cosim-thumb-hireg-smoke
```

Run the Thumb immediate-shift retire-trace smoke on the RTL side:

```sh
make tb-core-cosim-thumb-shift-smoke
```

Run the Thumb add/sub retire-trace smoke on the RTL side:

```sh
make tb-core-cosim-thumb-addsub-smoke
```

Run the Thumb stack retire-trace smoke on the RTL side:

```sh
make tb-core-cosim-thumb-stack-smoke
```

Run the Thumb register-offset load/store retire-trace smoke on the RTL side:

```sh
make tb-core-cosim-thumb-ls-reg-smoke
```

Run the Thumb SP-relative load/store retire-trace smoke on the RTL side:

```sh
make tb-core-cosim-thumb-ls-sp-smoke
```

Run the Thumb SP-adjust retire-trace smoke on the RTL side:

```sh
make tb-core-cosim-thumb-sp-adjust-smoke
```

Run the Thumb PC/SP address-add retire-trace smoke on the RTL side:

```sh
make tb-core-cosim-thumb-add-addr-smoke
```

Run the ARM `SWI` retire-trace smoke on the RTL side:

```sh
make tb-core-cosim-arm-swi-smoke
```

Run the Thumb `SWI` retire-trace smoke on the RTL side:

```sh
make tb-core-cosim-thumb-swi-smoke
```

Run the Thumb undefined-instruction retire-trace smoke on the RTL side:

```sh
make tb-core-cosim-thumb-undefined-smoke
```

Run the Thumb unsupported-pattern retire-trace smoke on the RTL side:

```sh
make tb-core-cosim-thumb-unsupported-smoke
```

Run the ARM undefined-instruction retire-trace smoke on the RTL side:

```sh
make tb-core-cosim-arm-undefined-smoke
```

Run the ARM branch/call retire-trace smoke on the RTL side:

```sh
make tb-core-cosim-arm-branch-smoke
```

Run the ARM single-transfer retire-trace smoke on the RTL side:

```sh
make tb-core-cosim-arm-mem-smoke
```

Run the ARM halfword/signed-transfer retire-trace smoke on the RTL side:

```sh
make tb-core-cosim-arm-halfword-smoke
```

Run the ARM `SWP`/`SWPB` retire-trace smoke on the RTL side:

```sh
make tb-core-cosim-arm-swap-smoke
```

Run the ARM block-transfer retire-trace smoke on the RTL side:

```sh
make tb-core-cosim-arm-block-smoke
```

Run the ARM empty-register-list block-transfer smoke on the RTL side:

```sh
make tb-core-cosim-arm-block-empty-smoke
```

Run the ARM user-bank `^` block-transfer smoke on the RTL side:

```sh
make tb-core-cosim-arm-block-user-smoke
```

Run the ARM block-transfer `{pc}` smoke on the RTL side:

```sh
make tb-core-cosim-arm-block-pc-smoke
```

Run the ARM block-transfer `{pc}^` restore smoke on the RTL side:

```sh
make tb-core-cosim-arm-block-pc-restore-smoke
```

Prepare a `cm2005` ROM set from that Thumb load/store smoke image:

```sh
make cosim-mame-cm2005-thumb-ls-smoke-rom
```

Prepare a `cm2005` ROM set from the Thumb `BL` smoke image:

```sh
make cosim-mame-cm2005-thumb-bl-smoke-rom
```

Prepare a `cm2005` ROM set from the Thumb PC-relative `LDR` smoke image:

```sh
make cosim-mame-cm2005-thumb-ldr-pc-smoke-rom
```

Prepare a `cm2005` ROM set from the Thumb conditional-branch smoke image:

```sh
make cosim-mame-cm2005-thumb-condbranch-smoke-rom
```

Prepare a `cm2005` ROM set from the Thumb IRQ-entry smoke image:

```sh
make cosim-mame-cm2005-thumb-interrupt-smoke-rom
```

Prepare a `cm2005` ROM set from the Thumb prefetch-abort smoke image:

```sh
make cosim-mame-cm2005-thumb-prefetch-abort-smoke-rom
```

Prepare a `cm2005` ROM set from the Thumb ALU-opcode smoke image:

```sh
make cosim-mame-cm2005-thumb-alu-smoke-rom
```

Prepare a `cm2005` ROM set from the Thumb high-register smoke image:

```sh
make cosim-mame-cm2005-thumb-hireg-smoke-rom
```

Prepare a `cm2005` ROM set from the Thumb immediate-shift smoke image:

```sh
make cosim-mame-cm2005-thumb-shift-smoke-rom
```

Prepare a `cm2005` ROM set from the Thumb add/sub smoke image:

```sh
make cosim-mame-cm2005-thumb-addsub-smoke-rom
```

Prepare a `cm2005` ROM set from the Thumb stack smoke image:

```sh
make cosim-mame-cm2005-thumb-stack-smoke-rom
```

Prepare a `cm2005` ROM set from the Thumb register-offset load/store smoke image:

```sh
make cosim-mame-cm2005-thumb-ls-reg-smoke-rom
```

Prepare a `cm2005` ROM set from the Thumb SP-relative load/store smoke image:

```sh
make cosim-mame-cm2005-thumb-ls-sp-smoke-rom
```

Prepare a `cm2005` ROM set from the Thumb SP-adjust smoke image:

```sh
make cosim-mame-cm2005-thumb-sp-adjust-smoke-rom
```

Prepare a `cm2005` ROM set from the Thumb PC/SP address-add smoke image:

```sh
make cosim-mame-cm2005-thumb-add-addr-smoke-rom
```

Prepare a `cm2005` ROM set from the ARM `SWI` smoke image:

```sh
make cosim-mame-cm2005-arm-swi-smoke-rom
```

Prepare a `cm2005` ROM set from the Thumb `SWI` smoke image:

```sh
make cosim-mame-cm2005-thumb-swi-smoke-rom
```

Prepare a `cm2005` ROM set from the Thumb undefined smoke image:

```sh
make cosim-mame-cm2005-thumb-undefined-smoke-rom
```

Prepare a `cm2005` ROM set from the Thumb unsupported smoke image:

```sh
make cosim-mame-cm2005-thumb-unsupported-smoke-rom
```

Prepare a `cm2005` ROM set from the ARM undefined smoke image:

```sh
make cosim-mame-cm2005-arm-undefined-smoke-rom
```

Prepare a `cm2005` ROM set from the ARM branch smoke image:

```sh
make cosim-mame-cm2005-arm-branch-smoke-rom
```

Prepare a `cm2005` ROM set from the ARM memory smoke image:

```sh
make cosim-mame-cm2005-arm-mem-smoke-rom
```

Prepare a `cm2005` ROM set from the ARM halfword smoke image:

```sh
make cosim-mame-cm2005-arm-halfword-smoke-rom
```

Prepare a `cm2005` ROM set from the ARM swap smoke image:

```sh
make cosim-mame-cm2005-arm-swap-smoke-rom
```

Prepare a `cm2005` ROM set from the ARM block-transfer smoke image:

```sh
make cosim-mame-cm2005-arm-block-smoke-rom
```

Prepare a `cm2005` ROM set from the ARM block `{pc}` smoke image:

```sh
make cosim-mame-cm2005-arm-block-pc-smoke-rom
```

Prepare a `cm2005` ROM set from the ARM block `{pc}^` restore smoke image:

```sh
make cosim-mame-cm2005-arm-block-pc-restore-smoke-rom
```

Prepare a `cm2005` ROM set from the ARM empty block-transfer smoke image:

```sh
make cosim-mame-cm2005-arm-block-empty-smoke-rom
```

Prepare a `cm2005` ROM set from the ARM user-bank block-transfer smoke image:

```sh
make cosim-mame-cm2005-arm-block-user-smoke-rom
```

The generic trace bench also supports optional interrupt driving for exception-return and exception-entry programs:

```sh
+irq_initial=1
+irq_raise_cycle=1
+irq_clear_on_reg_addr=14
+irq_clear_on_reg_data=10
```

It also supports a simple fetch-abort hook for exception-entry traces:

```sh
+abort_on_fetch_addr=2a
```

Prepare a `cm2005` ROM set from the ARM empty block-transfer smoke image:

```sh
make cosim-mame-cm2005-arm-block-empty-smoke-rom
```

Prepare a `cm2005` ROM set from the ARM user-bank block-transfer smoke image:

```sh
make cosim-mame-cm2005-arm-block-user-smoke-rom
```

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
mame cm2005 \
  -rompath /tmp/arm7tdmi_mame_roms \
  -debug \
  -debugscript /tmp/mame_cosim.cmd
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
  --machine cm2005 \
  --cpu :maincpu \
  --stop 0x10 \
  --rtl-trace /tmp/rtl_trace.jsonl \
  --raw-trace /tmp/mame_raw.trace \
  --norm-trace /tmp/mame_norm.jsonl \
  --debug-script /tmp/mame_cosim.cmd \
  --mame-env=SDL_VIDEODRIVER=dummy \
  --mame-env=SDL_AUDIODRIVER=dummy \
  --mame-arg=-rompath \
  --mame-arg=/tmp/arm7tdmi_mame_roms \
  --allow-mame-failure-if-trace
```

If you already have a raw trace, omit `--machine` or pass `--skip-mame`.
If your local MAME build exits nonzero after already writing a useful raw trace,
pass `--allow-mame-failure-if-trace`. The wrapper only accepts a trace freshly
generated by the current launch; it will not reuse a stale old file.

## Current Limits

This is intentionally a first-pass harness:

- It is functional-only, not timing-aware.
- The default compare set is register/CPSR state per retirement.
- It is best suited to ARM ALU, branch, single-transfer, and early Thumb
  completion work.
- Multi-write instructions like block transfers are logged but not yet compared
  as rich write lists.
- The wrapper can launch MAME directly, but machine arguments and stop
  conditions are still driver-specific.
- The `cm2005` path is intended for simple ARM-state smoke programs that stay
  within the ROM/RAM region already mapped by that skeleton driver.
- Some headless environments still need SDL/audio environment overrides like
  `SDL_VIDEODRIVER=dummy` and `SDL_AUDIODRIVER=dummy`.
- The repository does not currently expose a checked-in `make` regression target
  for the actual MAME launch because host runtime behavior is still environment-
  dependent.
- A dedicated minimal MAME machine/driver for running arbitrary flat ARM7TDMI
  programs is still the next step if fully automated MAME trace generation is
  desired.
