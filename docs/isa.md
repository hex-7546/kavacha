# Instruction Set

Kavacha implements **RV32IMC** with the `Zicsr` extension. `misa` reports the
base as 32-bit with the `I`, `M`, and `C` extension bits set.

## Supported extensions

| Extension | Description |
|-----------|-------------|
| **RV32I** | base 32-bit integer instruction set — arithmetic, logic, shifts, loads/stores, branches, jumps, `LUI`/`AUIPC` |
| **M** | integer multiply and divide (`MUL`, `MULH`, `MULHSU`, `MULHU`, `DIV`, `DIVU`, `REM`, `REMU`), computed by an iterative unit |
| **C** | 16-bit compressed instructions, expanded to their 32-bit equivalents before decode |
| **Zicsr** | atomic CSR read/modify/write instructions (`CSRRW`, `CSRRS`, `CSRRC`, and immediate forms) |

## Privileged instructions

- `ECALL` — environment call (traps to Machine mode)
- `EBREAK` — breakpoint (traps, or enters Debug mode when a debugger is attached)
- `MRET` — return from a machine-mode trap
- `WFI` — wait for interrupt (implemented as a no-op / resumable hint)
- `FENCE` / `FENCE.I` — memory and instruction-fetch ordering

## Addressing and alignment

- **Instruction fetch** honours compressed (`C`) code: the PC advances by 2 for
  a compressed instruction and by 4 otherwise.
- **Misaligned loads and stores** are supported in hardware. An access that
  crosses a 32-bit word boundary is split into two memory beats and recombined
  transparently, so no misaligned-access trap is required.

## Instruction timing

Because Kavacha is multi-cycle, instructions take a small, predictable number of
clock cycles rather than one:

| Instruction class | Cycles (zero-latency memory) |
|-------------------|------------------------------|
| ALU, logic, shift, `LUI`, `AUIPC` | fetch + execute |
| Branches, jumps | fetch + execute |
| CSR and system instructions | fetch + execute |
| Stores | fetch + execute |
| Loads | fetch + execute + load beat |
| Multiply / divide | fetch + execute + iterative completion |

Aligned single-beat instructions dominate; loads and multiply/divide add one
state. External memory latency adds cycles through the `mem_stall` handshake.
This timing is fully deterministic, which is convenient for control loops and
worst-case execution-time analysis.

## Traps on illegal instructions

Any instruction that does not decode to a supported operation raises an
illegal-instruction exception, recording the offending instruction word in
`mtval`. See **[Traps & Interrupts](traps-and-interrupts.md)**.
