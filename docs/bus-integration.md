# Bus Integration

Kavacha can be integrated two ways: through its **native memory port** for
tightly-coupled memories, or through the **AXI4-Lite** wrapper for standard SoC
fabrics.

## Native memory port

The core exposes a simple synchronous memory interface:

| Signal | Direction | Purpose |
|--------|-----------|---------|
| `imem_addr` | out | instruction fetch address |
| `imem_rdata` | in | fetched instruction word |
| `dmem_addr` | out | data access address |
| `dmem_re` / `dmem_we` | out | read / write strobe |
| `dmem_be[3:0]` | out | byte enables for sub-word stores |
| `dmem_wdata` | out | store data |
| `dmem_rdata` | in | load data |
| `mem_stall` | in | hold the core for multi-cycle latency |
| `mem_req` | out | a fetch/load/store is in progress |

Drive `mem_stall` from your memory or bridge to insert wait states; tie it low
for zero-latency memory. The retire interface (`retire_valid`, `retire_pc`,
`retire_instr`, and the write-back fields) is available for tracing and
verification.

## AXI4-Lite wrapper

`kavacha_axil.sv` provides a standard-bus integration in three modules:

| Module | Role |
|--------|------|
| `kavacha_axil_master` | wraps the core and turns its fetch/load/store requests into AXI4-Lite read/write transactions, driving `mem_stall` from the AXI handshake |
| `axil_bram_slave` | an AXI4-Lite slave with unified IMEM/DRAM plus a `tohost` control word |
| `kavacha_axil_soc` | connects master and slave over real AXI4-Lite wires |

The master issues one outstanding transaction at a time — matching the core's
one-instruction-in-flight model — and stalls the core until each read or write
handshake completes. This lets Kavacha drop into any AXI4-Lite fabric and share
a bus with other masters and peripherals.

```mermaid
flowchart LR
    CORE[kavacha_core] --> M[kavacha_axil_master]
    M -->|AXI4-Lite| S[axil_bram_slave]
    S --> MEM[(IMEM / DRAM / tohost)]
```

## Choosing an interface

- Use the **native port** for the smallest, lowest-latency setup with
  on-chip tightly-coupled memory.
- Use the **AXI4-Lite wrapper** when integrating into an existing SoC, sharing
  memory with other masters, or attaching memory-mapped peripherals.
