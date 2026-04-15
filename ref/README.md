# ARM7TDMI Reference Source Snapshots

Downloaded on 2026-04-14 as shallow source snapshots for public emulator,
simulator, and HDL/RTL projects relevant to ARM7TDMI, ARMv4T, or systems that
embed ARM7TDMI-class cores.

This is a curated public-source reference set, not a claim that proprietary ARM
IP, unavailable projects, every fork, or every closed-source emulator is present.

## Dedicated ARM7TDMI / ARMv4T Simulators

| Folder | Upstream | Commit | Notes |
| --- | --- | --- | --- |
| `uARM` | https://github.com/mellotanica/uARM.git | `fa71aa1` | ARM7TDMI machine emulator. |
| `skyeye-sourceforge` | https://git.code.sf.net/p/skyeye/code | `9e11375` | SkyEye simulator source from SourceForge. |
| `qemu` | https://github.com/qemu/qemu.git | `da6c4fe` | Maintained system emulator with ARM targets. |
| `mame` | https://github.com/MAMEDev/mame.git | `56657220` | Includes ARM7 CPU devices and disassembler code. |
| `unicorn` | https://github.com/unicorn-engine/unicorn.git | `7c5db94` | CPU emulation framework derived from QEMU. |

## GBA / DS / Console Emulators With ARM7TDMI Cores

| Folder | Upstream | Commit | Notes |
| --- | --- | --- | --- |
| `mgba` | https://github.com/mgba-emu/mgba.git | `79fa503` | GBA emulator with ARM/Thumb core. |
| `visualboyadvance-m` | https://github.com/visualboyadvance-m/visualboyadvance-m.git | `d617b1b` | GBA emulator with ARM7TDMI emulation. |
| `NanoBoyAdvance` | https://github.com/nba-emu/NanoBoyAdvance.git | `a5fbaed` | GBA emulator with ARM7TDMI core. |
| `gbajs` | https://github.com/endrift/gbajs.git | `0cf0ac7` | JavaScript GBA emulator. |
| `rustboyadvance-ng` | https://github.com/michelhe/rustboyadvance-ng.git | `7358d08` | Rust GBA emulator with separate `arm7tdmi` crate. |
| `jgenesis` | https://github.com/jsgroth/jgenesis.git | `7a6a64b` | Includes ARM7TDMI emulation for GBA/coprocessors. |
| `melonDS` | https://github.com/melonDS-emu/melonDS.git | `94f9bf5` | Nintendo DS emulator with ARM7-side emulation. |
| `desmume` | https://github.com/TASEmulators/desmume.git | `e96b11f` | Nintendo DS emulator with ARM7-side code. |
| `NooDS` | https://github.com/Hydr8gon/NooDS.git | `b1fcf87` | Nintendo DS emulator. |
| `higan` | https://github.com/higan-emu/higan.git | `8f4df01` | Includes `component/processor/arm7tdmi`. |
| `ares` | https://github.com/ares-emulator/ares.git | `ad98f53` | Includes `component/processor/arm7tdmi` and tests. |
| `Gopher2600` | https://github.com/JetSetIlly/Gopher2600.git | `184aea4` | Includes ARM7TDMI timing/model code for cartridge coprocessors. |

## HDL / RTL Models

| Folder | Upstream | Commit | Notes |
| --- | --- | --- | --- |
| `ARM7-verilog-chsasank` | https://github.com/chsasank/ARM7.git | `d8aa43d` | Pipelined ARM7TDMI processor in Verilog. |
| `processi-vhdl-adamaq01` | https://github.com/adamaq01/processi.git | `6198995` | ARM7TDMI CPU implementation in VHDL. |
| `ARM9-compatible-soft-CPU-core` | https://github.com/risclite/ARM9-compatible-soft-CPU-core.git | `fc17416` | ARMv4-compatible synthesizable Verilog soft CPU; adjacent reference rather than exact TDMI. |
| `GBA_MiSTer` | https://github.com/MiSTer-devel/GBA_MiSTer.git | `2cfe0d1` | FPGA GBA core with ARM7TDMI-class CPU integration in `rtl/gba_cpu.vhd`. |

## Download Notes

- Repositories were cloned with `--depth 1`.
- Submodules were not initialized. Several projects have submodules, but the
  ARM7TDMI-relevant source files are present in the checked out trees.
- The stale GitHub candidate `skyeyeproject/skyeye` was unavailable; the
  SourceForge SkyEye repository was cloned instead.
- `DOWNLOAD_FAILURES.txt` is empty for the completed batch.
