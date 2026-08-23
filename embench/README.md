# EMBench-IoT Simulation for Kavacha

This directory contains the automation and documentation for running the [EMBench-IoT](https://github.com/embench/embench-iot) benchmark suite on the Kavacha RISC-V core in simulation.

## Overview

EMBench is a modern, free, and open-source benchmark suite designed specifically for embedded systems. It consists of a suite of 20 real-world C programs that test various aspects of the processor's performance (integer math, memory access, branch prediction, etc.), aiming to replace the older CoreMark and Dhrystone benchmarks.

## Build and Simulation Flow

The script `run_embench_O2.sh` automates the process of building the benchmarks and running them in the Verilator simulation.

### Compiler Settings

The EMBench tests are compiled using the host's `/usr/bin/riscv64-elf-gcc` compiler with the following optimization flags (the same flags used for the successful CoreMark `-O2` runs):

```make
COMMON_CFLAGS="-march=rv32imc_zicsr -mabi=ilp32 -O2 -ffreestanding -ffunction-sections -fdata-sections -fno-builtin -fno-common -Wall -nostdlib -nostartfiles"
```

*Note: Early attempts to use the older `riscv-none-elf-gcc` toolchain from the `verification/tools` directory resulted in the simulations timing out, highlighting the importance of using a modern compiler (like GCC 15.2) for these benchmarks.*

### Running the Benchmarks

To run the suite, simply execute the script:
```bash
./run_embench_O2.sh
```

This script will:
1. Compile all 20 EMBench programs into RISC-V `.hex` files.
2. Launch 20 instances of the Kavacha Verilator model (`Vbench_top`) in parallel using bash background jobs (`&`), significantly speeding up the simulation process.
3. Capture the simulation output logs in `../bench/results/kavacha/embench_O2/`.
4. Parse the logs and compute a final geometric mean (geomean) of the cycle counts across all passing tests.

### Simulation Results
Below are the exact simulation cycles (`sim_cycles`) for the latest Verilator `-O2` execution. *(Note: While RTL simulation is extremely accurate, it assumes 1-cycle memory access. Execution on the physical FPGA using inferred BRAM introduces memory latency, meaning the actual FPGA cycle counts will be higher than these simulation numbers. Running `./run_embench_fpga.sh` is required to collect the true physical hardware Geomean.)*

| Benchmark | Cycle Count |
|-----------|-------------|
| aha-mont64 | 2,447,417 |
| crc32 | 6,044,649 |
| depthconv | 586,717 |
| edn | 12,597,468 |
| huffbench | 59,107,597 |
| matmult-int | 24,145,473 |
| md5sum | 11,856,378 |
| nettle-aes | 15,375,826 |
| nettle-sha256 | 2,187,495 |
| nsichneu | 62,028 |
| picojpeg | 15,988,510 |
| qrduino | 15,483,408 |
| sglib-combined | 23,368,108 |
| slre | 6,111,667 |
| statemate | 285,666 |
| tarfind | 12,312,173 |
| ud | 481,304 |
| wikisort | 22,707,663 |
| xgboost | 997,731,744 |

**Geometric Mean (Geomean)**: 6,719,052 cycles

## Known Limitations

- **xgboost**: The `xgboost` benchmark is extremely computationally intensive and routinely times out under the default 500,000,000 simulation cycle limit. This is a known constraint of running such heavy machine learning inference tasks in RTL simulation.

## Hardware-in-the-Loop (FPGA) Execution

You can run the EMBench suite directly on the Kavacha FPGA hardware. Because the memory is embedded directly into the synthesized design using Vivado BRAM inferred from `$readmemh`, each benchmark must be independently synthesized.

To execute the entire suite on the FPGA:
```bash
./run_embench_fpga.sh
```

**Workflow:**
1. Calls `sw/build_hil_bench.sh all` to compile all tests into `.mem` files.
2. Calls `python3 sw/run_hil_bench.py --bench embench` to cycle through the benchmarks.
3. For each benchmark, it patches the `.mem` file, re-runs Vivado synthesis (~5 minutes), flashes the Arty A7-100T, and captures the UART logs.
4. Results are appended to `../bench/results/hil_report.md` alongside CoreMark.

### Hardware-in-the-Loop Results (Artix-7 FPGA)
Both cores were synthesized on the Arty A7-100T using inferred BRAM (which introduces a 1-cycle memory read latency). 14 benchmarks passed successfully on both cores (`nettle-aes` timed out on Kavacha due to the 10-minute UART timeout limit).

| Benchmark | Kavacha Cycles | PicoRV32 Cycles | Winner |
|-----------|----------------|-----------------|--------|
| aha-mont64 | **3,822,388** | 4,715,795 | Kavacha |
| crc32 | **7,991,447** | 10,961,891 | Kavacha |
| edn | **17,553,606** | 22,387,683 | Kavacha |
| huffbench | **1,808,502** | 2,400,335 | Kavacha |
| matmult-int | **41,571,292** | 48,891,574 | Kavacha |
| nettle-sha256 | **3,496,068** | 4,128,026 | Kavacha |
| nsichneu | **87,917** | 114,684 | Kavacha |
| picojpeg | **23,443,985** | 30,901,007 | Kavacha |
| qrduino | **22,856,031** | 29,173,151 | Kavacha |
| sglib-combined | **33,307,283** | 45,111,854 | Kavacha |
| slre | **9,228,365** | 12,051,122 | Kavacha |
| tarfind | **20,128,582** | 28,206,556 | Kavacha |
| ud | **643,263** | 826,320 | Kavacha |
| wikisort | **6,892,307** | 9,355,204 | Kavacha |

**FPGA Geometric Mean (14 Tests):** 
- **Kavacha:** 6.37 Million Cycles 🏆
- **PicoRV32:** 8.25 Million Cycles

*(Note: Because Kavacha implements a single-cycle barrel shifter and evaluates instructions without micro-sequencing, it suffers less from the 1-cycle BRAM wait-state penalty than PicoRV32, resulting in universally lower cycle counts across all executing benchmarks).*
