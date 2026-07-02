# Memory Map

The reference SoC (`kavacha_soc.sv`) presents a simple, flat address map. The
base addresses are parameters, so you can relocate regions to suit your
platform.

| Region | Default base | Description |
|--------|--------------|-------------|
| **Instruction memory (IMEM)** | `0x0000_0000` | reset vector and program storage; loaded from a `$readmemh` image in simulation |
| **`tohost`** | `0x2000_0000` | simulation control word — a store here signals test completion / exit status |
| **Data RAM (DRAM)** | `0x8000_0000` | read/write data and stack |

## Reset behaviour

The core begins fetching from the reset PC, which defaults to `0x0000_0000` and
is exposed as the `RESET_PC` parameter on the core and SoC.

## Parameters

The SoC exposes the map as build-time parameters:

| Parameter | Default | Meaning |
|-----------|---------|---------|
| `IMEM_WORDS` | `8192` | instruction-memory depth in 32-bit words |
| `DRAM_WORDS` | `8192` | data-RAM depth in 32-bit words |
| `DRAM_BASE` | `0x8000_0000` | base address of data RAM |
| `TOHOST_ADDR` | `0x2000_0000` | address of the `tohost` control word |

## Byte order and access widths

Kavacha is **little-endian**. Loads and stores support byte, halfword, and word
widths, with signed and unsigned load variants. Byte enables on the memory port
carry the active lanes for sub-word stores; misaligned accesses are handled as
described in the **[Instruction Set](isa.md#addressing-and-alignment)**.

## Custom platforms

For a real SoC you will typically replace the reference memories with your own
IMEM/DRAM controllers and peripherals, either behind the native memory port or
behind the **[AXI4-Lite](bus-integration.md)** wrapper. Peripherals are mapped
by decoding the core's address bus in your bus fabric.
