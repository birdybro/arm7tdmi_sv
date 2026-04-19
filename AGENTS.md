## Agent workflow

- For complex features or significant refactors, create and follow an ExecPlan as described in `.agent/PLANS.md`.
- Before changing RTL, identify the affected modules, clock domains, resets, constraints, and validation path.
- Keep edits scoped to the task; avoid unrelated refactors.
- After RTL changes, run the smallest relevant simulation or validation flow available for the touched logic.
- Review synthesis, lint, and CDC results when the change could affect timing, resets, resource inference, or clock-domain crossings.
- Do not add vendor IP, generated files, or new dependencies unless the task clearly requires it.
- If instructions conflict, follow the closest `AGENTS.md` to the files being changed.

## HDL guidance for MiSTer FPGA / DE10-Nano targets

When writing or modifying HDL for this repository, optimize for **real hardware behavior on FPGA**, not software-style sequential thinking. Treat the design as a parallel digital circuit targeting the **Intel Cyclone V on the DE10-Nano used by MiSTer**.

### Core design priorities

- Prefer **simple, explicit, hardware-native logic** over clever abstractions.
- Minimize:
  - total state/register count
  - combinational depth
  - fanout on critical signals
  - unnecessary mux trees
  - cross-domain complexity
- Maximize:
  - parallel evaluation
  - clean pipelining
  - timing closure margin
  - synthesis predictability
  - readability of real hardware intent

### Mental model

- Write HDL as a **description of concurrent hardware**, not as software steps.
- Do not model behavior as if the FPGA is “executing instructions” unless implementing an actual microcoded or sequenced machine.
- Avoid serializing naturally parallel logic into FSM-heavy code when simple combinational decode plus narrow registered stages would work better.
- Prefer dataflow-oriented structure:
  - decode in parallel
  - compute independent signals in parallel
  - register only where needed for timing, CDC, or architectural correctness

### State and control

- Use the **smallest amount of state necessary**.
- Avoid creating FSMs for logic that can be expressed as:
  - direct decode
  - counters
  - shift registers
  - handshake bits
  - simple phase toggles
- Keep FSMs small, explicit, and easy to audit.
- Do not add “bookkeeping” registers unless they serve a real hardware purpose.
- Let the tool choose FSM encoding unless measured QoR or safety data says otherwise.

### Combinational logic

- Keep combinational paths shallow and structured.
- Avoid deeply nested conditionals when decode tables or factored signals are clearer.
- Factor reused expressions into named wires.
- Prefer explicit bit logic, masks, compares, and shifts over arithmetic that synthesizes poorly.
- Be careful with wide priority chains. Favor parallel decode and final selection when possible.
- Use nonblocking assignments in sequential blocks and blocking assignments in combinational blocks.
- Give every combinational block total assignments; use defaults first and always include a `default` case.

### Arithmetic and operators

- Avoid expensive operators unless there is a clear, justified need:
  - division
  - modulus
  - arbitrary-width multiplication
  - dynamic shifts with large barrel shifters
- Do **not** use division for address mapping, scaling, timing, or derived constants when it can be replaced by:
  - shifts
  - masks
  - adds/subtracts
  - lookup tables
  - compile-time constants
- Prefer power-of-two sizing/alignment where practical.
- If multiplication is required, keep widths bounded and intentional.
- Avoid runtime `/` and `%` unless deliberate divider or remainder hardware is intended and reviewed.

### Clocking and timing

- Use a **single clock domain** where possible.
- Avoid creating derived clocks in logic unless absolutely necessary.
- Prefer **clock enables** over internally generated divided clocks.
- Treat every clock-domain crossing explicitly: single-bit control with synchronizers, multi-bit control with handshakes, and streaming data with async FIFOs.
- Reset logic should be simple and intentional. Avoid global reset dependency when initialization or local control is sufficient.
- Prefer synchronous internal resets; if async reset is unavoidable, synchronize its deassertion per clock domain.

### Registers and sequential logic

- Use sequential blocks for real state only.
- Separate combinational next-state/decode logic from sequential update logic when it improves clarity.
- Avoid mixing unrelated responsibilities in one always block.
- Prefer deterministic update structure:
  - defaults first
  - explicit enables
  - architecturally meaningful state transitions
- Do not infer latches.
- Use synthesizable SystemVerilog with `logic`, `always_ff`, and `always_comb`.

### Memory and storage inference

- Be conscious of FPGA resource mapping:
  - registers
  - LUT RAM / MLAB
  - block RAM / M10K
- Write memories in a style that synthesizes predictably to the intended resource.
- Avoid accidentally exploding small RAM structures into registers.
- Keep ROM/RAM interfaces simple and timing-friendly.
- For lookup-heavy logic, consider whether a ROM/table is cheaper and cleaner than wide logic.
- Do not reset inferred memory arrays; reset control and valid bits around them instead.
- Infer RAMs and DSPs with simple vendor-friendly templates first, then confirm inference in reports.

### MiSTer / DE10-Nano practical guidance

- Target behavior that is robust on the **Cyclone V** and friendly to Quartus synthesis/fitting.
- Prefer conservative, synthesis-friendly constructs over stylistic HDL tricks.
- Be aware that “works in simulation” is not enough. Code should also be friendly to:
  - Quartus inference
  - timing closure
  - place-and-route stability
  - limited FPGA resources
- Avoid unnecessary width growth. Constrain bit widths deliberately.
- Do not assume vendor-neutral power-up values; use an explicit reset or initialization-valid contract.
- Check synthesis, lint, and CDC reports before considering RTL complete.

### Coding style expectations

- Keep module boundaries clean and purpose-driven.
- Use descriptive signal names that reflect hardware meaning, not vague software intent.
- Prefer explicit widths and signedness.
- Use typed parameters and explicit width management; never rely on silent truncation, extension, or multi-bit truthiness.
- Comment the **hardware reason** for non-obvious logic, especially:
  - timing-sensitive behavior
  - pipeline staging
  - CDC handling
  - resource-driven tradeoffs
  - compatibility quirks

### What to avoid

- Software-like step-by-step emulation of hardware in giant procedural blocks
- Overuse of temporary variables that obscure actual hardware structure
- Division/modulo in active logic paths
- Large monolithic FSMs controlling everything
- Derived clocks made from counters in fabric
- Overengineered abstractions that hide synthesized cost
- “Cleaner” code that is materially worse for LUTs, registers, BRAM use, or timing
- Do not use `full_case`, `parallel_case`, `casex`, `#delay`, `force`, XMR, or internal tri-states for on-chip muxing.

### Preferred outcome

The generated HDL should look like it was written by someone designing a circuit, not by someone translating C into Verilog. It should be:
- synthesis-friendly
- timing-aware
- resource-efficient
- structurally parallel
- easy to reason about at the signal level
- appropriate for MiSTer FPGA and DE10-Nano implementation
