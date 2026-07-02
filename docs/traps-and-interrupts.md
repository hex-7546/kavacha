# Traps & Interrupts

Kavacha takes **precise** traps: because only one instruction is in flight, the
architectural state at a trap is exactly the state before the faulting or
interrupted instruction. There is no speculative work to unwind.

## Exceptions

The following synchronous exceptions are raised during execution:

| Cause | Trigger |
|-------|---------|
| Illegal instruction | an instruction word that does not decode to a supported operation (`mtval` holds the word) |
| Environment call (`ECALL`) | an `ECALL` instruction, reported per originating privilege mode |
| Breakpoint (`EBREAK`) | an `EBREAK` instruction (or a debugger breakpoint) |
| Access fault | a load, store, or fetch denied by the PMP (in the `SECURE` configuration) |

When an exception is taken, the core:

1. writes the cause to `mcause` and the associated value to `mtval`,
2. saves the current PC to `mepc`,
3. updates the interrupt-enable and previous-privilege fields of `mstatus`, and
4. jumps to the handler at `mtvec`.

`MRET` reverses these steps: it restores `mstatus` and resumes at `mepc`.

## Interrupts

Three standard machine interrupts are supported, driven by external lines and
gated by `mstatus.MIE` and the corresponding `mie` bits:

| Interrupt | `mie` / `mip` bit | Typical source |
|-----------|-------------------|----------------|
| Software | `MSIP` | inter-processor / self interrupt |
| Timer | `MTIP` | machine timer (e.g. CLINT `mtimecmp`) |
| External | `MEIP` | external controller (e.g. PLIC) |

Interrupts are sampled at instruction boundaries. When one is taken it behaves
like an exception — cause, `mepc`, `mstatus`, and vectoring through `mtvec` —
with the interrupt flag set in `mcause`. Tie any unused interrupt line low.

## Vectoring

`mtvec` holds the base of the trap handler. Handlers read `mcause` to
distinguish the trap source and `mtval` for the faulting address or instruction,
service the event, and return with `MRET`.
