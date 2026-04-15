# Additional ARM7TDMI Reference Notes

The following Arm document IDs were identified as relevant, but I did not find a
direct static PDF URL for them during this pass. Official document pages often
exist under `https://developer.arm.com/documentation/<doc-id>/<issue>/`.

Where the material overlaps the downloaded TRMs, the notes below summarize the
important implementation takeaways instead of copying inaccessible documents.

## Application Notes

| ID | Title | Why It Matters |
| --- | --- | --- |
| `DAI0028A` | The ARM7TDMI Debug Architecture | Background for JTAG scan chains, EmbeddedICE concepts, breakpoints, watchpoints, and debug entry. |
| `DAI0029A` | Interfacing a Memory System to the ARM7TDMI Without Using AMBA | Useful when building a direct memory controller instead of an AMBA wrapper. Focus areas are cycle classification, wait states, data width, and sequential access handling. |
| `DAI0031C` | Using EmbeddedICE | Practical debug usage model for EmbeddedICE-style registers and debug monitor flows. |
| `DAI0038B` | Using the ARM7TDMI Debug Comms Channel | Explains the DCC path used by debugger-host communication. Relevant only if debug compatibility is in scope. |
| `DAI0099C` | Core Type & Revision Identification | Useful for matching ID codes and revision-visible behavior. |
| `DUI0126B` | Integrator/CM7TDMI User Guide | Board-level integration reference for an ARM7TDMI core module. Useful for reset, clock, debug, and bus wiring examples. |
| `DVI0027B` | ARM7TDMI Rev 3 Core Processor Product Overview | Concise product-level overview and instruction speed summary; most detailed content is superseded by the TRMs. |

## Practical Details To Carry Forward

- If debug is out of scope, isolate JTAG/EmbeddedICE-facing signals behind stubs
  so they can be implemented later without disturbing the core pipeline.
- If memory is modeled directly, preserve the distinction between sequential and
  nonsequential accesses. Many systems use it to choose wait states.
- Keep abort signaling precise enough that prefetch aborts and data aborts enter
  the correct exception mode with the correct return behavior.
- Treat core revision as a parameter where practical. Rev 3 and Rev 4 manuals
  differ in integration and debug details even though the broad ARMv4T programmer
  model is the same.
- For product-identification behavior, avoid hardcoding IDs until a target
  revision is chosen.

## Official Document Page Patterns

- ARM7TDMI TRM: https://developer.arm.com/documentation/ddi0210/c
- ARM7TDMI-S TRM: https://developer.arm.com/documentation/ddi0234/b
- ARM7TDMI Rev 3 TRM: https://developer.arm.com/documentation/ddi0029/g
- ARM7TDMI-S Rev 3 TRM: https://developer.arm.com/documentation/ddi0084/f
- AMBA ARM7TDMI Interface: https://developer.arm.com/documentation/ddi0045/d
- ARM Architecture Reference Manual: https://developer.arm.com/documentation/ddi0100/i
- ARM7TDMI Debug Architecture: https://developer.arm.com/documentation/dai0028/a
- ARM7TDMI memory-system interfacing without AMBA: https://developer.arm.com/documentation/dai0029/a
- Using EmbeddedICE: https://developer.arm.com/documentation/dai0031/c
- ARM7TDMI Debug Comms Channel: https://developer.arm.com/documentation/dai0038/b
- Core type and revision identification: https://developer.arm.com/documentation/dai0099/c
- ARM7TDMI product overview: https://developer.arm.com/documentation/dvi0027/b
