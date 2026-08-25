# Kavacha Complete Verification & Reproduction Guide

This directory contains reproduction and verification scripts to validate the **Kavacha** RV32IMC processor benchmarks and hardware implementation.

---

## 1. Quick Verification Commands

### Full Interactive Verification:
Checks for all required tools (Verilator, RISC-V GCC, Vivado), prompts to install missing package manager dependencies, and runs the audit, simulations, and FPGA synthesis:

```bash
cd /home/yash/OR5/Kavacha/kavacha/verification
./run_all_verifications.sh
```

### Python Verification Runner:
```bash
# 1. Run analytical and formula audit only:
python3 verify_results.py

# 2. Run with live Verilator cycle-accurate simulation:
python3 verify_results.py --sim

# 3. Run with live Vivado FPGA synthesis:
python3 verify_results.py --vivado

# 4. Run all (Audit + Live Sim + Live Vivado):
python3 verify_results.py --all
```

---

## 2. Tools & Installation Options

If tools are missing on your machine, the scripts will guide you with appropriate commands:

| Tool | Purpose | Arch/Omarchy (`pacman`) | Ubuntu/Debian (`apt`) |
| :--- | :--- | :--- | :--- |
| **Verilator** | Cycle-accurate simulation | `sudo pacman -S verilator` | `sudo apt install verilator` |
| **RISC-V GCC** | Firmware compilation (CoreMark, EMBench) | `sudo pacman -S riscv64-unknown-elf-gcc riscv64-unknown-elf-newlib` | `sudo apt install gcc-riscv64-unknown-elf picolibc-riscv64-unknown-elf` |
| **Vivado** | FPGA Synthesis & $F_{max}$ timing sweep | Install from AMD/Xilinx and run: `source <VIVADO_DIR>/settings64.sh` | Install from AMD/Xilinx and run: `source <VIVADO_DIR>/settings64.sh` |

---

## 3. What Gets Verified

1. **Cycle Counts & EMBench-IoT Benchmark Suite:**
   - 15 standard tests executed on cycle-accurate RTL testbench.
2. **CoreMark / MHz:**
   - Standard formula: $\text{CoreMark/MHz} = \frac{1,000,000}{\text{Cycles per Iteration}}$
   - Validates Kavacha performance metrics.
3. **Vivado Hardware Out-of-Context Synthesis:**
   - Runs `synth_cores.tcl` to generate `kavacha_util.rpt` for Artix-7 (`XC7A100T-csg324-1`).
