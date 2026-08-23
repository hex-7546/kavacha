#!/bin/bash
set -euo pipefail

echo "==================================================="
echo " EMBench-IoT Hardware-in-the-Loop (FPGA) PicoRV32  "
echo "==================================================="

# Move to repo root
cd "$(dirname "$0")/.."

echo ""
echo "[1/2] Building EMBench HIL firmware images for PicoRV32..."
echo "---------------------------------------------------"
export PICORV32=1
./sw/build_hil_bench.sh all

echo ""
echo "[2/2] Running EMBench suite on Arty A7-100T (PicoRV32)..."
echo "---------------------------------------------------"
echo "WARNING: Since the firmware is loaded into Block RAM via synthesis,"
echo "Vivado must re-synthesize the bitstream for each benchmark."
echo "This will take approximately 5 minutes per benchmark (19 benchmarks = ~1.5 hours)."
echo "Sit back and relax!"
echo ""

# Run the python HIL runner script for all EMBench tests
python3 sw/run_hil_bench.py --port /dev/ttyUSB1 --freq 50 --bench embench --bit fpga/arty_a7/build_picorv32/picorv32_arty_a7.bit
