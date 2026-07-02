# Control & Status Registers

Kavacha implements the machine-mode CSR set required to take and return from
traps, plus the identification and counter registers. The `SECURE`
configuration adds the user-mode and memory-protection CSRs.

## Machine information registers

| CSR | Address | Description |
|-----|---------|-------------|
| `mvendorid` | `0xF11` | vendor identifier |
| `marchid` | `0xF12` | architecture identifier |
| `mimpid` | `0xF13` | implementation identifier |
| `mhartid` | `0xF14` | hardware thread (hart) identifier |

## Machine trap setup and handling

| CSR | Address | Description |
|-----|---------|-------------|
| `mstatus` | `0x300` | global status — interrupt-enable and previous-privilege fields |
| `misa` | `0x301` | reports RV32 with the `I`, `M`, `C` extension bits |
| `mie` | `0x304` | interrupt-enable mask (timer / software / external) |
| `mtvec` | `0x305` | trap-vector base address |
| `mscratch` | `0x340` | scratch register for trap handlers |
| `mepc` | `0x341` | exception program counter (trap return address) |
| `mcause` | `0x342` | trap cause (interrupt flag + exception code) |
| `mtval` | `0x343` | trap value (faulting address or instruction word) |
| `mip` | `0x344` | interrupt-pending status |

## Counters

| CSR | Address | Description |
|-----|---------|-------------|
| `mcycle` | `0xB00` | machine cycle counter |
| `minstret` | `0xB02` | retired-instruction counter |

## Security CSRs (`SECURE` configuration)

| CSR | Address | Description |
|-----|---------|-------------|
| `mseccfg` | `0x747` | machine security configuration — enables ePMP semantics |
| `pmpcfg0…` | `0x3A0…` | PMP region configuration (mode, R/W/X, lock) |
| `pmpaddr0…` | `0x3B0…` | PMP region address registers |

See **[Privilege & Security](privilege-and-security.md)** for how the PMP and
ePMP registers govern memory access.

## Access rules

CSR instructions (`CSRRW`/`CSRRS`/`CSRRC` and their immediate forms) provide
atomic read-modify-write access. Writes to read-only CSRs and accesses to
CSRs above the current privilege level raise an illegal-instruction exception.
