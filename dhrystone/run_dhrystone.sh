#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

GCC="/usr/bin/riscv64-elf-gcc"
OBJCOPY="/usr/bin/riscv64-elf-objcopy"

if ! command -v $GCC &>/dev/null; then
    echo "ERROR: GCC $GCC not found"
    exit 1
fi

echo "========================================="
echo " Building Dhrystone for Kavacha          "
echo "========================================="

cd "$SCRIPT_DIR"
mkdir -p build

COMMON_CFLAGS="-march=rv32imc_zicsr -mabi=ilp32 -O2 -ffreestanding -ffunction-sections -fdata-sections -fno-builtin -fno-common -Wall -nostdlib -nostartfiles"
INCLUDES="-I. -I../bench/common"

# Dhrystone specific defines:
# -DTIME: Use time() function
# -DRISCV: Print RISC-V specific metrics
# -Wno-implicit-int -Wno-return-type: Dhrystone 2.1 is old K&R C
DHRY_CFLAGS="-std=gnu99 -DNUM_RUNS=100000 -DTIME -DRISCV -Wno-implicit-int -Wno-return-type -Wno-implicit-function-declaration"

# Source files
SRCS=(
    "../bench/common/crt0.S"
    "../bench/common/syscalls.c"
    "../bench/common/printf.c"
    "dhrystone_support.c"
    "dhry_1.c"
    "dhry_2.c"
)

# Compile
$GCC $COMMON_CFLAGS $INCLUDES $DHRY_CFLAGS -T ../bench/common/bench.ld -Wl,--gc-sections -o build/dhrystone.elf "${SRCS[@]}"

# Convert to hex
$OBJCOPY -O binary build/dhrystone.elf build/dhrystone.bin
python3 ../sw/bin2hex.py build/dhrystone.bin build/dhrystone.hex

echo "[BUILD] Created build/dhrystone.hex"
echo ""

echo "========================================="
echo " Running Dhrystone Simulation            "
echo "========================================="

/tmp/kavacha_sim_yash/Vbench_obj/Vbench_top --hex build/dhrystone.hex --name dhrystone --max-cycles 500000000

echo "Done."
