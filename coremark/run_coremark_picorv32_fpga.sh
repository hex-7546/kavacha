#!/bin/bash
set -euo pipefail

echo "==================================================="
echo " PicoRV32 CoreMark Hardware-in-the-Loop Runner     "
echo "==================================================="

# Move to repo root
cd "$(dirname "$0")/.."

echo ""
echo "[1/4] Building CoreMark firmware image..."
echo "---------------------------------------------------"
export PICORV32=1
./sw/build_hil_bench.sh coremark
cp sw/hil_build/coremark.mem sw/firmware.mem

echo ""
echo "[2/4] Running Vivado Synthesis for PicoRV32..."
echo "---------------------------------------------------"
echo "Baking firmware.mem into PicoRV32 bitstream."
source /home/yash/Vivado/Vivado/2023.2/settings64.sh
cd fpga/arty_a7
vivado -mode batch -source picorv32_arty_a7.tcl
cd ../..

echo ""
echo "[3/4] Flashing Arty A7-100T..."
echo "---------------------------------------------------"
openFPGALoader -b arty_a7_100t fpga/arty_a7/build_picorv32/picorv32_arty_a7.bit
sleep 2

echo ""
echo "[4/4] Capturing UART output..."
echo "---------------------------------------------------"
python3 sw/run_hil_bench.py --port /dev/ttyUSB1 --freq 50 --bench coremark --no-flash

echo "Done! Check bench/results/hil_report.md for the new PicoRV32 CoreMark numbers."
