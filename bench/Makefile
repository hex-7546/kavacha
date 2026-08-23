###############################################################################
# bench/Makefile — Kavacha + PicoRV32 benchmark suite (CoreMark + EMBench-IoT)
#
# ---- Kavacha targets --------------------------------------------------------
#   make verilator-kavacha    — build Kavacha Verilator model
#   make run-kavacha          — run all benchmarks on Kavacha
#
# ---- PicoRV32 targets -------------------------------------------------------
#   make fetch-picorv         — clone PicoRV32 RTL
#   make verilator-picorv     — build PicoRV32 Verilator model
#   make run-picorv           — run all benchmarks on PicoRV32
#
# ---- Gandiva targets --------------------------------------------------------
#   make verilator-gandiva    — build Gandiva Verilator model
#   make run-gandiva          — run all benchmarks on Gandiva
#
# ---- Firmware targets (shared hex files used by BOTH cores) -----------------
#   make coremark             — compile CoreMark
#   make embench              — compile all 20 EMBench-IoT benchmarks
#
# ---- Comparison -------------------------------------------------------------
#   make compare              — run both cores, emit side-by-side report
#   make all                  — everything
#
# ---- Other ------------------------------------------------------------------
#   make fetch                — clone CoreMark + EMBench-IoT + PicoRV32
#   make report               — generate results/report.md + report.csv
#   make clean / distclean
#
# Variables:
#   RISCV_GCC, ITERATIONS, SCALE, VERILATOR, CXX
###############################################################################

SHELL := /bin/bash
.DEFAULT_GOAL := all

# ---- Directories ------------------------------------------------------------
BENCH_DIR   := .
ROOT_DIR    := ..
RTL_DIR     := $(ROOT_DIR)/rtl
RTL_COMMON  := $(RTL_DIR)/common

BUILD_DIR   := $(BENCH_DIR)/build
V_BUILD_DIR := /tmp/kavacha_sim_$(USER)
WORKSPACE_LINK := /tmp/kavacha_workspace
SIM_DIR     := $(ROOT_DIR)/sim
RESULTS_DIR := $(BENCH_DIR)/results

COREMARK_SRC := $(BENCH_DIR)/coremark/upstream
EMBENCH_SRC  := $(BENCH_DIR)/embench/upstream

# ---- Toolchain detection ----------------------------------------------------
VERILATOR ?= verilator
CXX       ?= g++

# Try to find a RISC-V GCC
ifeq ($(RISCV_GCC),)
  RISCV_GCC := $(firstword \
    $(wildcard $(RISCV_TC)/riscv-none-elf-gcc) \
    $(shell command -v riscv64-unknown-elf-gcc 2>/dev/null) \
    $(shell command -v riscv32-unknown-elf-gcc 2>/dev/null) \
    $(shell command -v riscv64-elf-gcc         2>/dev/null) \
    $(shell command -v riscv32-elf-gcc         2>/dev/null) \
    $(shell command -v riscv-none-elf-gcc      2>/dev/null) \
    NOTFOUND)
endif

ifneq ($(filter-out NOTFOUND,$(RISCV_GCC)),)
  GCC_PREFIX := $(patsubst %gcc,%,$(RISCV_GCC))
  OBJCOPY    := $(GCC_PREFIX)objcopy
  OBJDUMP    := $(GCC_PREFIX)objdump
  SIZE       := $(GCC_PREFIX)size
else
  $(error No RISC-V GCC found. Set RISCV_GCC= or add riscv64-unknown-elf-gcc to PATH)
endif

# ---- Compiler flags ---------------------------------------------------------
ARCH_FLAGS  := -march=rv32imc_zicsr -mabi=ilp32
COMMON_CFLAGS := $(ARCH_FLAGS) \
                 -O2 \
                 -ffreestanding \
                 -ffunction-sections \
                 -fdata-sections \
                 -fno-builtin \
                 -fno-common \
                 -Wall \
                 -nostdlib \
                 -nostartfiles

LDFLAGS     := -T $(BENCH_DIR)/common/bench.ld \
               -Wl,--gc-sections \
               -Wl,-Map=$(@:.elf=.map)

COMMON_SRCS := $(BENCH_DIR)/common/syscalls.c \
               $(BENCH_DIR)/common/printf.c

COMMON_INC  := -I$(BENCH_DIR)/common

# Default startup file
CRT0 := $(BENCH_DIR)/common/crt0.S

ITERATIONS  ?= 1000
SCALE       ?= 100

# ---- Benchmark iteration counts (EMBench benchmarks that need tuning) ------
# Most run fine at scale=100. Memory-heavy ones (picojpeg, nsichneu) use 10.
SCALE_picojpeg    := 10
SCALE_nsichneu    := 10
SCALE_qrduino     := 10
SCALE_wikisort    := 10

scale_for = $(if $(SCALE_$(1)),$(SCALE_$(1)),$(SCALE))

# ---- EMBench benchmark list (all 20 from embench-iot) ----------------------
EMBENCH_BENCHMARKS := \
    aha-mont64   crc32      depthconv  edn        huffbench  \
    matmult-int  md5sum     nettle-aes nettle-sha256 nsichneu \
    picojpeg     qrduino    sglib-combined slre   statemate \
    tarfind      ud         wikisort   xgboost

###############################################################################
# fetch — clone upstream sources
###############################################################################
.PHONY: fetch
fetch: fetch-coremark fetch-embench fetch-picorv

.PHONY: fetch-coremark
fetch-coremark: $(COREMARK_SRC)/.git

$(COREMARK_SRC)/.git:
	@echo "[FETCH] Cloning CoreMark..."
	git clone --depth=1 https://github.com/eembc/coremark $(COREMARK_SRC)

.PHONY: fetch-embench
fetch-embench: $(EMBENCH_SRC)/.git

$(EMBENCH_SRC)/.git:
	@echo "[FETCH] Cloning EMBench-IoT..."
	git clone --depth=1 https://github.com/embench/embench-iot $(EMBENCH_SRC)

###############################################################################
# verilator — build simulation model
###############################################################################
# VERILATOR_FLAGS moved to bench/verilator/kavacha.f

VERILATOR_SV := \
    rtl/common/kavacha_pkg.sv \
    rtl/common/kavacha_alu.sv \
    rtl/common/kavacha_regfile.sv \
    rtl/common/kavacha_muldiv.sv \
    rtl/common/kavacha_csr.sv \
    rtl/common/kavacha_rvc.sv \
    rtl/common/kavacha_immgen.sv \
    rtl/common/kavacha_branch.sv \
    rtl/common/kavacha_decode.sv \
    rtl/common/kavacha_pmp.sv \
    rtl/kavacha_core.sv \
    rtl/kavacha_debug.sv \
    bench/verilator/bench_top.sv

VERILATOR_CPP := bench/verilator/main.cpp

SIM_BIN := $(V_BUILD_DIR)/Vbench_obj/Vbench_top

.PHONY: verilator
verilator: $(SIM_BIN)

$(SIM_BIN): $(VERILATOR_SV:%=$(ROOT_DIR)/%) $(ROOT_DIR)/$(VERILATOR_CPP) | $(SIM_DIR)
	@echo "[VERILATOR] Creating workspace symlink to bypass space-in-path limits..."
	ln -sfn "$(realpath $(ROOT_DIR))" $(WORKSPACE_LINK)
	@echo "[VERILATOR] Building simulation model in safe temp directory..."
	mkdir -p $(V_BUILD_DIR)/Vbench_obj
	$(VERILATOR) --Mdir "$(V_BUILD_DIR)/Vbench_obj" -o Vbench_top \
	    -f $(WORKSPACE_LINK)/bench/verilator/kavacha.f \
	    $(VERILATOR_SV:%=$(WORKSPACE_LINK)/%) \
	    $(WORKSPACE_LINK)/$(VERILATOR_CPP)
	@echo "[VERILATOR] Build complete: $@"

$(SIM_DIR):
	mkdir -p $@

###############################################################################
# gandiva verilator — build simulation model
###############################################################################
GANDIVA_SV := \
    ../gandiva/rtl/common/gandiva_pkg.sv \
    ../gandiva/rtl/common/gandiva_alu.sv \
    ../gandiva/rtl/common/gandiva_regfile.sv \
    ../gandiva/rtl/common/gandiva_muldiv.sv \
    ../gandiva/rtl/common/gandiva_csr.sv \
    ../gandiva/rtl/common/gandiva_rvc.sv \
    ../gandiva/rtl/common/gandiva_immgen.sv \
    ../gandiva/rtl/common/gandiva_branch.sv \
    ../gandiva/rtl/common/gandiva_decode.sv \
    ../gandiva/rtl/common/gandiva_pmp.sv \
    ../gandiva/rtl/gandiva_core.sv \
    bench/verilator/gandiva_bench_top.sv

GANDIVA_CPP := bench/verilator/gandiva_main.cpp

GANDIVA_SIM := $(V_BUILD_DIR)/Vgandiva_obj/Vgandiva_bench_top

.PHONY: verilator-gandiva
verilator-gandiva: $(GANDIVA_SIM)

$(GANDIVA_SIM): $(GANDIVA_SV:%=$(ROOT_DIR)/%) $(ROOT_DIR)/$(GANDIVA_CPP) | $(SIM_DIR)
	@echo "[VERILATOR] Creating workspace symlink to bypass space-in-path limits..."
	ln -sfn "$(realpath $(ROOT_DIR))" $(WORKSPACE_LINK)
	ln -sfn "$(realpath $(ROOT_DIR)/../gandiva)" /tmp/gandiva_workspace
	@echo "[VERILATOR] Building Gandiva simulation model in safe temp directory..."
	mkdir -p $(V_BUILD_DIR)/Vgandiva_obj
	$(VERILATOR) --Mdir "$(V_BUILD_DIR)/Vgandiva_obj" -o Vgandiva_bench_top \
	    -f $(WORKSPACE_LINK)/bench/verilator/gandiva.f \
	    $(GANDIVA_SV:%=$(WORKSPACE_LINK)/%) \
	    $(WORKSPACE_LINK)/$(GANDIVA_CPP)
	@echo "[VERILATOR] Gandiva build complete: $@"

###############################################################################
# coremark — compile CoreMark
###############################################################################
COREMARK_HEX := $(BUILD_DIR)/coremark.hex
COREMARK_ELF := $(BUILD_DIR)/coremark.elf

COREMARK_SRCS_UPSTREAM := \
    $(COREMARK_SRC)/core_list_join.c \
    $(COREMARK_SRC)/core_main.c \
    $(COREMARK_SRC)/core_matrix.c \
    $(COREMARK_SRC)/core_state.c \
    $(COREMARK_SRC)/core_util.c

COREMARK_PORT := \
    $(BENCH_DIR)/coremark/port/core_portme.c

COREMARK_ALL_SRCS := \
    $(COMMON_SRCS) \
    $(COREMARK_SRCS_UPSTREAM) \
    $(COREMARK_PORT)

COREMARK_CFLAGS := $(COMMON_CFLAGS) \
    $(COMMON_INC) \
    -I$(COREMARK_SRC) \
    -I$(BENCH_DIR)/coremark/port \
    -DITERATIONS=$(ITERATIONS) \
    -DMEM_METHOD=MEM_STATIC \
    -DMULTITHREAD=1 \
    -DUSE_FORK=0 \
    -DUSE_PTHREAD=0 \
    -DHAS_FLOAT=0 \
    -DHAS_TIME_H=0 \
    -DUSE_CLOCK=0 \
    -DHAS_STDIO=0 \
    -DHAS_PRINTF=1 \
    -DCOMPILER_FLAGS='"$(ARCH_FLAGS) -O2"' \
    -DCOMPILER_VERSION='"$(shell $(RISCV_GCC) --version | head -1)"' \
    -DPERFORMANCE_RUN=1

.PHONY: coremark
coremark: fetch-coremark $(COREMARK_HEX)

$(COREMARK_HEX): $(COREMARK_ELF) | $(BUILD_DIR)
	$(OBJCOPY) -O binary $< $(BUILD_DIR)/coremark.bin
	python3 $(ROOT_DIR)/sw/bin2hex.py $(BUILD_DIR)/coremark.bin $@
	$(SIZE) $<
	@echo "[COREMARK] Hex: $@"

$(COREMARK_ELF): $(COREMARK_ALL_SRCS) $(CRT0) | $(BUILD_DIR) $(COREMARK_SRC)/.git
	@echo "[COREMARK] Compiling (ITERATIONS=$(ITERATIONS))..."
	$(RISCV_GCC) $(COREMARK_CFLAGS) $(LDFLAGS) \
	    -Wl,-Map=$(BUILD_DIR)/coremark.map \
	    -o $@ $(filter %.c %.S,$^)

# ---- VexRiscv CoreMark Firmware ----
# VexRiscv uses its own linker script (code at 0x80000000) and start.S
VEX_LDFLAGS := -T ../../../Core_Benchmarking/coremark/riscv32_target/link_vexriscv.ld -Wl,--gc-sections
VEX_START   := ../../../Core_Benchmarking/coremark/riscv32_target/start.S
VEX_CFLAGS  := $(subst rv32imc_zicsr,rv32im_zicsr,$(COREMARK_CFLAGS))

$(BUILD_DIR)/vex_coremark.elf: $(COREMARK_ALL_SRCS) $(VEX_START) | $(BUILD_DIR)
	@echo "[COREMARK] Compiling for VexRiscv..."
	$(RISCV_GCC) $(VEX_CFLAGS) -DVEXRISCV $(VEX_LDFLAGS) -o $@ $(filter %.c %.S,$^)
$(BUILD_DIR)/vex_coremark.hex: $(BUILD_DIR)/vex_coremark.elf
	$(OBJCOPY) -O binary $< $(BUILD_DIR)/vex_coremark.bin
	python3 $(ROOT_DIR)/sw/bin2hex.py $(BUILD_DIR)/vex_coremark.bin $@

# ---- Ibex CoreMark Firmware ----
# Ibex uses the SAME bench.ld/crt0.S as Gandiva (code@0x0, DRAM@0x80000000,
# tohost@0x20000000) because our ibex_bench_top.sv mirrors that memory map.
$(BUILD_DIR)/ibex_coremark.elf: $(COREMARK_ALL_SRCS) $(CRT0) | $(BUILD_DIR)
	@echo "[COREMARK] Compiling for Ibex..."
	$(RISCV_GCC) $(COREMARK_CFLAGS) -DIBEX $(LDFLAGS) -o $@ $(filter %.c %.S,$^)
$(BUILD_DIR)/ibex_coremark.hex: $(BUILD_DIR)/ibex_coremark.elf
	$(OBJCOPY) -O binary $< $(BUILD_DIR)/ibex_coremark.bin
	python3 $(ROOT_DIR)/sw/bin2hex.py $(BUILD_DIR)/ibex_coremark.bin $@

$(BUILD_DIR):
	mkdir -p $@

###############################################################################
# embench — compile all 20 EMBench-IoT benchmarks
###############################################################################
.PHONY: embench
embench: fetch-embench \
    $(foreach b,$(EMBENCH_BENCHMARKS),$(BUILD_DIR)/$(b).hex) \
    $(foreach b,$(EMBENCH_BENCHMARKS),$(BUILD_DIR)/vex_$(b).hex) \
    $(foreach b,$(EMBENCH_BENCHMARKS),$(BUILD_DIR)/ibex_$(b).hex)

# Generic rule: $(BUILD_DIR)/<name>.hex
# EMBench source layout:  embench-iot/src/<name>/*.c  (and *.h)
define EMBENCH_RULE
EMBENCH_SRCS_$(1) := $$(wildcard $$(EMBENCH_SRC)/src/$(1)/*.c)
EMBENCH_ELF_$(1)  := $$(BUILD_DIR)/$(1).elf
EMBENCH_HEX_$(1)  := $$(BUILD_DIR)/$(1).hex

EMBENCH_CFLAGS_$(1) := $$(COMMON_CFLAGS) \
    $$(COMMON_INC) \
    -I$$(BENCH_DIR)/embench/support \
    -I$$(EMBENCH_SRC)/support \
    -I$$(EMBENCH_SRC)/src/$(1) \
    -DLOCAL_SCALE_FACTOR=$$(call scale_for,$(1)) \
    -DGLOBAL_SCALE_FACTOR=1 \
    -DBENCHMARK_NAME='"$(1)"'

$$(EMBENCH_ELF_$(1)): $$(COMMON_SRCS) $$(CRT0) \
                       $$(BENCH_DIR)/embench/bench_main.c \
                       $$(BENCH_DIR)/embench/support/support.c \
                       $$(EMBENCH_SRC)/support/beebsc.c \
                       $$(EMBENCH_SRCS_$(1)) \
                       | $$(BUILD_DIR) $$(EMBENCH_SRC)/.git
	@echo "[EMBENCH] Compiling $(1) (scale=$$(call scale_for,$(1)))..."
	$$(RISCV_GCC) $$(EMBENCH_CFLAGS_$(1)) $$(LDFLAGS) \
	    -Wl,-Map=$$(BUILD_DIR)/$(1).map \
	    -o $$@ $$(filter %.c %.S,$$^)

$$(BUILD_DIR)/vex_$(1).elf: $$(COMMON_SRCS) $$(VEX_START) \
                            $$(BENCH_DIR)/embench/bench_main.c \
                            $$(BENCH_DIR)/embench/support/support.c \
                            $$(EMBENCH_SRC)/support/beebsc.c \
                            $$(EMBENCH_SRCS_$(1))
	@echo "[EMBENCH/VexRiscv] Compiling $(1)..."
	$$(RISCV_GCC) $$(subst rv32imc_zicsr,rv32im_zicsr,$$(EMBENCH_CFLAGS_$(1))) -DVEXRISCV $$(VEX_LDFLAGS) -o $$@ $$(filter %.c %.S,$$^)

$$(BUILD_DIR)/vex_$(1).hex: $$(BUILD_DIR)/vex_$(1).elf
	$$(OBJCOPY) -O binary $$< $$(BUILD_DIR)/vex_$(1).bin
	python3 $$(ROOT_DIR)/sw/bin2hex.py $$(BUILD_DIR)/vex_$(1).bin $$@

$$(BUILD_DIR)/ibex_$(1).elf: $$(COMMON_SRCS) $$(CRT0) \
                             $$(BENCH_DIR)/embench/bench_main.c \
                             $$(BENCH_DIR)/embench/support/support.c \
                             $$(EMBENCH_SRC)/support/beebsc.c \
                             $$(EMBENCH_SRCS_$(1))
	@echo "[EMBENCH/Ibex] Compiling $(1)..."
	$$(RISCV_GCC) $$(EMBENCH_CFLAGS_$(1)) -DIBEX $$(LDFLAGS) -o $$@ $$(filter %.c %.S,$$^)

$$(BUILD_DIR)/ibex_$(1).hex: $$(BUILD_DIR)/ibex_$(1).elf
	$$(OBJCOPY) -O binary $$< $$(BUILD_DIR)/ibex_$(1).bin
	python3 $$(ROOT_DIR)/sw/bin2hex.py $$(BUILD_DIR)/ibex_$(1).bin $$@

$$(EMBENCH_HEX_$(1)): $$(EMBENCH_ELF_$(1))
	$$(OBJCOPY) -O binary $$< $$(BUILD_DIR)/$(1).bin
	python3 $$(ROOT_DIR)/sw/bin2hex.py $$(BUILD_DIR)/$(1).bin $$@
	@echo "[EMBENCH] Hex: $$@"
endef

$(foreach b,$(EMBENCH_BENCHMARKS),$(eval $(call EMBENCH_RULE,$(b))))

###############################################################################
# run targets
###############################################################################
TIMEOUT_CYCLES ?= 50000000  # 50 M cycles (fast benchmark mode)

.PHONY: run-coremark
run-coremark: $(SIM_BIN) $(COREMARK_HEX) | $(RESULTS_DIR)
	@echo "[RUN] CoreMark (ITERATIONS=$(ITERATIONS))..."
	$(SIM_BIN) --hex $(COREMARK_HEX) --name coremark \
	    --max-cycles $(TIMEOUT_CYCLES) \
	    | tee $(RESULTS_DIR)/coremark.log

.PHONY: run-embench
run-embench: $(SIM_BIN) embench | $(RESULTS_DIR)
	@for b in $(EMBENCH_BENCHMARKS); do \
	    echo "[RUN] $$b..."; \
	    $(SIM_BIN) --hex $(BUILD_DIR)/$$b.hex --name $$b \
	        --max-cycles $(TIMEOUT_CYCLES) \
	        | tee $(RESULTS_DIR)/$$b.log; \
	done

.PHONY: run-all
run-all: run-coremark run-embench

$(RESULTS_DIR):
	mkdir -p $@

###############################################################################
# verilator-kavacha — alias for the existing verilator target
###############################################################################
.PHONY: verilator-kavacha
verilator-kavacha: $(SIM_BIN)

###############################################################################
# PicoRV32 — fetch, build, run
###############################################################################
PICORV_SRC    := $(BENCH_DIR)/picorv/upstream
PICORV_SIM    := $(V_BUILD_DIR)/Vpicorv_obj/Vpicorv_soc

.PHONY: fetch-picorv
fetch-picorv:
	@if [ ! -d "$(PICORV_SRC)/.git" ]; then \
	    echo "[FETCH] Cloning PicoRV32..."; \
	    git clone --depth=1 https://github.com/YosysHQ/picorv32 $(PICORV_SRC); \
	else \
	    echo "[FETCH] PicoRV32 already present ($(PICORV_SRC))"; \
	fi

# PICORV_VFLAGS moved to bench/picorv/picorv.f

PICORV_SV := \
    bench/picorv/upstream/picorv32.v \
    bench/picorv/picorv_soc.sv

PICORV_CPP := bench/picorv/main.cpp

.PHONY: verilator-picorv
verilator-picorv: $(PICORV_SIM)

$(PICORV_SIM): $(PICORV_SV:%=$(ROOT_DIR)/%) $(ROOT_DIR)/$(PICORV_CPP) fetch-picorv | $(SIM_DIR)
	@echo "[VERILATOR] Creating workspace symlink to bypass space-in-path limits..."
	ln -sfn "$(realpath $(ROOT_DIR))" $(WORKSPACE_LINK)
	@echo "[VERILATOR] Building PicoRV32 simulation model in safe temp directory..."
	mkdir -p $(V_BUILD_DIR)/Vpicorv_obj
	$(VERILATOR) --Mdir "$(V_BUILD_DIR)/Vpicorv_obj" -o Vpicorv_soc \
	    -f $(WORKSPACE_LINK)/bench/picorv/picorv.f \
	    $(PICORV_SV:%=$(WORKSPACE_LINK)/%) \
	    $(WORKSPACE_LINK)/$(PICORV_CPP)
	@echo "[VERILATOR] PicoRV32 build complete: $@"

# ---- PicoRV32 run targets ---------------------------------------------------
PICORV_RESULTS := $(RESULTS_DIR)/picorv

.PHONY: run-picorv-coremark
run-picorv-coremark: $(PICORV_SIM) $(COREMARK_HEX) | $(PICORV_RESULTS)
	@echo "[RUN/PicoRV32] CoreMark..."
	$(PICORV_SIM) --hex $(COREMARK_HEX) --name coremark \
	    --max-cycles $(TIMEOUT_CYCLES) \
	    | tee $(PICORV_RESULTS)/coremark.log

.PHONY: run-picorv-embench
run-picorv-embench: $(PICORV_SIM) embench | $(PICORV_RESULTS)
	@for b in $(EMBENCH_BENCHMARKS); do \
	    echo "[RUN/PicoRV32] $$b..."; \
	    $(PICORV_SIM) --hex $(BUILD_DIR)/$$b.hex --name $$b \
	        --max-cycles $(TIMEOUT_CYCLES) \
	        | tee $(PICORV_RESULTS)/$$b.log; \
	done

.PHONY: run-picorv
run-picorv: run-picorv-coremark run-picorv-embench

$(PICORV_RESULTS):
	mkdir -p $@

# ---- Kavacha run target (result goes to results/kavacha/) -------------------
KAVACHA_RESULTS := $(RESULTS_DIR)/kavacha

.PHONY: run-kavacha-coremark
run-kavacha-coremark: $(SIM_BIN) $(COREMARK_HEX) | $(KAVACHA_RESULTS)
	@echo "[RUN/Kavacha] CoreMark..."
	$(SIM_BIN) --hex $(COREMARK_HEX) --name coremark \
	    --max-cycles $(TIMEOUT_CYCLES) \
	    | tee $(KAVACHA_RESULTS)/coremark.log

.PHONY: run-kavacha-embench
run-kavacha-embench: $(SIM_BIN) embench | $(KAVACHA_RESULTS)
	@for b in $(EMBENCH_BENCHMARKS); do \
	    echo "[RUN/Kavacha] $$b..."; \
	    $(SIM_BIN) --hex $(BUILD_DIR)/$$b.hex --name $$b \
	        --max-cycles $(TIMEOUT_CYCLES) \
	        | tee $(KAVACHA_RESULTS)/$$b.log; \
	done

.PHONY: run-kavacha
run-kavacha: run-kavacha-coremark run-kavacha-embench

$(KAVACHA_RESULTS):
	mkdir -p $@

# ---- Gandiva run target (result goes to results/gandiva/) -------------------
GANDIVA_RESULTS := $(RESULTS_DIR)/gandiva

.PHONY: run-gandiva-coremark
run-gandiva-coremark: $(GANDIVA_SIM) $(COREMARK_HEX) | $(GANDIVA_RESULTS)
	@echo "[RUN/Gandiva] CoreMark..."
	$(GANDIVA_SIM) --hex $(COREMARK_HEX) --name coremark \
	    --max-cycles $(TIMEOUT_CYCLES) \
	    | tee $(GANDIVA_RESULTS)/coremark.log

.PHONY: run-gandiva-embench
run-gandiva-embench: $(GANDIVA_SIM) embench | $(GANDIVA_RESULTS)
	@for b in $(EMBENCH_BENCHMARKS); do \
	    echo "[RUN/Gandiva] $$b..."; \
	    $(GANDIVA_SIM) --hex $(BUILD_DIR)/$$b.hex --name $$b \
	        --max-cycles $(TIMEOUT_CYCLES) \
	        | tee $(GANDIVA_RESULTS)/$$b.log; \
	done

.PHONY: run-gandiva
run-gandiva: run-gandiva-coremark run-gandiva-embench

$(GANDIVA_RESULTS):
	mkdir -p $@

# ---- VexRiscv Verilator build + run -------------------------------------------
VEX_RESULTS   := $(RESULTS_DIR)/vexriscv
VEX_SIM_SRC   := ../../../Core_Benchmarking/vexriscv_sim
VEX_SIM       := $(V_BUILD_DIR)/Vvex_obj/Vtb_vexriscv
CORE_BENCH_LINK := /tmp/core_bench_link

.PHONY: verilator-vexriscv
verilator-vexriscv: $(VEX_SIM)

$(VEX_SIM): $(VEX_SIM_SRC)/tb_vexriscv.sv $(VEX_SIM_SRC)/VexRiscv.v $(VEX_SIM_SRC)/main.cpp
	@echo "[VERILATOR] Creating symlink to bypass space-in-path limits..."
	ln -sfn "$(realpath ../../../Core_Benchmarking)" $(CORE_BENCH_LINK)
	@echo "[VERILATOR] Building VexRiscv simulation model..."
	mkdir -p $(V_BUILD_DIR)/Vvex_obj
	$(VERILATOR) --cc --exe --build --timing -O2 \
	    -CFLAGS "-O2 -std=c++17" \
	    --top-module tb_vexriscv \
	    -Wno-lint -Wno-UNOPTFLAT -Wno-fatal -Wno-TIMESCALEMOD \
	    -Wno-DECLFILENAME -Wno-UNUSED -Wno-UNDRIVEN -Wno-MULTIDRIVEN -Wno-PINCONNECTEMPTY \
	    --Mdir $(V_BUILD_DIR)/Vvex_obj -o Vtb_vexriscv \
	    $(CORE_BENCH_LINK)/vexriscv_sim/VexRiscv.v \
	    $(CORE_BENCH_LINK)/vexriscv_sim/tb_vexriscv.sv \
	    $(CORE_BENCH_LINK)/vexriscv_sim/main.cpp
	@echo "[VERILATOR] VexRiscv build complete: $@"

.PHONY: run-vexriscv-coremark
run-vexriscv-coremark: $(VEX_SIM) $(BUILD_DIR)/vex_coremark.hex | $(VEX_RESULTS)
	@echo "[RUN/VexRiscv] CoreMark..."
	$(VEX_SIM) "+IMEM=$(BUILD_DIR)/vex_coremark.hex" "+NAME=coremark" \
	    | tee $(VEX_RESULTS)/coremark.log

.PHONY: run-vexriscv-embench
run-vexriscv-embench: $(VEX_SIM) embench | $(VEX_RESULTS)
	@for b in $(EMBENCH_BENCHMARKS); do \
	    echo "[RUN/VexRiscv] $$b..."; \
	    $(VEX_SIM) "+IMEM=$(BUILD_DIR)/vex_$$b.hex" "+NAME=$$b" \
	        | tee $(VEX_RESULTS)/$$b.log; \
	done

.PHONY: run-vexriscv
run-vexriscv: run-vexriscv-coremark run-vexriscv-embench

$(VEX_RESULTS):
	mkdir -p $@

# ---- Ibex Verilator build + run -----------------------------------------------
IBEX_RESULTS  := $(RESULTS_DIR)/ibex
IBEX_RTL_DIR  := ../../../Core_Benchmarking/ibex_repo/rtl
IBEX_SIM      := $(V_BUILD_DIR)/Vibex_obj/Vibex_bench_top

IBEX_RTL_SV := \
    $(IBEX_RTL_DIR)/ibex_pkg.sv \
    $(IBEX_RTL_DIR)/ibex_alu.sv \
    $(IBEX_RTL_DIR)/ibex_compressed_decoder.sv \
    $(IBEX_RTL_DIR)/ibex_controller.sv \
    $(IBEX_RTL_DIR)/ibex_counter.sv \
    $(IBEX_RTL_DIR)/ibex_cs_registers.sv \
    $(IBEX_RTL_DIR)/ibex_csr.sv \
    $(IBEX_RTL_DIR)/ibex_decoder.sv \
    $(IBEX_RTL_DIR)/ibex_dummy_instr.sv \
    $(IBEX_RTL_DIR)/ibex_ex_block.sv \
    $(IBEX_RTL_DIR)/ibex_fetch_fifo.sv \
    $(IBEX_RTL_DIR)/ibex_id_stage.sv \
    $(IBEX_RTL_DIR)/ibex_if_stage.sv \
    $(IBEX_RTL_DIR)/ibex_load_store_unit.sv \
    $(IBEX_RTL_DIR)/ibex_multdiv_fast.sv \
    $(IBEX_RTL_DIR)/ibex_multdiv_slow.sv \
    $(IBEX_RTL_DIR)/ibex_pmp.sv \
    $(IBEX_RTL_DIR)/ibex_prefetch_buffer.sv \
    $(IBEX_RTL_DIR)/ibex_register_file_ff.sv \
    $(IBEX_RTL_DIR)/ibex_branch_predict.sv \
    $(IBEX_RTL_DIR)/ibex_core.sv

.PHONY: verilator-ibex
verilator-ibex: $(IBEX_SIM)

$(IBEX_SIM): $(BENCH_DIR)/verilator/ibex_bench_top.sv $(BENCH_DIR)/verilator/ibex_main.cpp $(IBEX_RTL_SV)
	@echo "[VERILATOR] Creating symlinks to bypass space-in-path limits..."
	ln -sfn "$(realpath ../../../Core_Benchmarking)" $(CORE_BENCH_LINK)
	ln -sfn "$(realpath $(ROOT_DIR))" $(WORKSPACE_LINK)
	@echo "[VERILATOR] Building Ibex simulation model..."
	mkdir -p $(V_BUILD_DIR)/Vibex_obj
	$(VERILATOR) --cc --exe --build --timing -O2 \
	    --public-flat-rw \
	    -CFLAGS "-O2 -std=c++17" \
	    --top-module ibex_bench_top \
	    +incdir+$(CORE_BENCH_LINK)/ibex_repo/rtl \
	    -Wno-lint -Wno-UNOPTFLAT -Wno-fatal -Wno-TIMESCALEMOD \
	    -Wno-DECLFILENAME -Wno-UNUSED -Wno-UNDRIVEN -Wno-MULTIDRIVEN \
	    -Wno-PINCONNECTEMPTY -Wno-WIDTHTRUNC -Wno-WIDTHEXPAND \
	    -Wno-CASEINCOMPLETE -Wno-UNSIGNED -Wno-IMPLICIT -Wno-ENUMVALUE \
	    --Mdir $(V_BUILD_DIR)/Vibex_obj -o Vibex_bench_top \
	    $(IBEX_RTL_SV:../../../Core_Benchmarking/%=$(CORE_BENCH_LINK)/%) \
	    $(WORKSPACE_LINK)/bench/verilator/ibex_bench_top.sv \
	    $(WORKSPACE_LINK)/bench/verilator/ibex_main.cpp
	@echo "[VERILATOR] Ibex build complete: $@"

.PHONY: run-ibex-coremark
run-ibex-coremark: $(IBEX_SIM) $(BUILD_DIR)/ibex_coremark.hex | $(IBEX_RESULTS)
	@echo "[RUN/Ibex] CoreMark..."
	$(IBEX_SIM) --hex $(BUILD_DIR)/ibex_coremark.hex --name coremark \
	    --max-cycles $(TIMEOUT_CYCLES) \
	    | tee $(IBEX_RESULTS)/coremark.log

.PHONY: run-ibex-embench
run-ibex-embench: $(IBEX_SIM) embench | $(IBEX_RESULTS)
	@for b in $(EMBENCH_BENCHMARKS); do \
	    echo "[RUN/Ibex] $$b..."; \
	    $(IBEX_SIM) --hex $(BUILD_DIR)/ibex_$$b.hex --name $$b \
	        --max-cycles $(TIMEOUT_CYCLES) \
	        | tee $(IBEX_RESULTS)/$$b.log; \
	done

.PHONY: run-ibex
run-ibex: run-ibex-coremark run-ibex-embench

$(IBEX_RESULTS):
	mkdir -p $@

###############################################################################
# compare-industry — run Gandiva, VexRiscv, Ibex, and generate unified report
###############################################################################
.PHONY: compare-industry
compare-industry: run-gandiva run-vexriscv run-ibex
	python3 $(BENCH_DIR)/run_bench_unified.py \
	    --gandiva-dir  $(GANDIVA_RESULTS) \
	    --vexriscv-dir $(VEX_RESULTS) \
	    --ibex-dir     $(IBEX_RESULTS) \
	    --results-dir  $(RESULTS_DIR) \
	    --iterations   $(ITERATIONS) \
	    --scale        $(SCALE) \
	    --compare

###############################################################################
# report — single-core report (Kavacha only, legacy target)
###############################################################################
.PHONY: report
report: run-all | $(RESULTS_DIR)
	python3 $(BENCH_DIR)/run_bench.py \
	    --results-dir $(RESULTS_DIR) \
	    --iterations $(ITERATIONS) \
	    --scale $(SCALE)

###############################################################################
# all
###############################################################################
.PHONY: all
all: fetch verilator-kavacha verilator-picorv coremark embench compare

###############################################################################
# run-all (Kavacha only, kept for backwards compatibility)
###############################################################################
run-all: run-coremark run-embench

###############################################################################
# clean
###############################################################################
.PHONY: clean
clean:
	rm -rf $(BUILD_DIR) $(RESULTS_DIR)
	rm -rf $(V_BUILD_DIR)/Vbench_obj $(V_BUILD_DIR)/Vpicorv_obj $(V_BUILD_DIR)/Vgandiva_obj

.PHONY: distclean
distclean: clean
	rm -rf $(COREMARK_SRC) $(EMBENCH_SRC) $(PICORV_SRC)

.PHONY: help
help:
	@echo "Kavacha vs PicoRV32 Benchmark Suite"
	@echo ""
	@echo "  make compare          — full comparison: both cores, all benchmarks"
	@echo "  make all              — fetch + build + run + compare"
	@echo ""
	@echo "  make fetch            — clone CoreMark, EMBench-IoT, PicoRV32"
	@echo "  make verilator-kavacha — build Kavacha Verilator model"
	@echo "  make verilator-picorv  — build PicoRV32 Verilator model"
	@echo "  make coremark         — compile CoreMark (ITERATIONS=$(ITERATIONS))"
	@echo "  make embench          — compile all 20 EMBench benchmarks"
	@echo ""
	@echo "  make run-kavacha      — run all benchmarks on Kavacha"
	@echo "  make run-picorv       — run all benchmarks on PicoRV32"
	@echo ""
	@echo "  make clean            — remove build/ results/"
	@echo "  make distclean        — also remove fetched upstream sources"
	@echo ""
	@echo "Key variables:"
	@echo "  RISCV_GCC=$(RISCV_GCC)"
	@echo "  VERILATOR=$(VERILATOR)"
	@echo "  ITERATIONS=$(ITERATIONS)"
	@echo "  SCALE=$(SCALE)"
