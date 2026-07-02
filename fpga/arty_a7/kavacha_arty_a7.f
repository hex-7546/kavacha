# Kavacha-on-Arty-A7-100T source list (Vivado read_verilog -sv / iverilog).
# Order: shared leaf cells, core, debug module, UART, FPGA SoC, reset sync, top.
# -I include dir: ../../rtl/common  (kavacha_pkg.sv)
../../rtl/common/kavacha_pkg.sv
../../rtl/common/kavacha_alu.sv
../../rtl/common/kavacha_regfile.sv
../../rtl/common/kavacha_muldiv.sv
../../rtl/common/kavacha_csr.sv
../../rtl/common/kavacha_rvc.sv
../../rtl/common/kavacha_immgen.sv
../../rtl/common/kavacha_branch.sv
../../rtl/common/kavacha_decode.sv
../../rtl/common/kavacha_pmp.sv
../../rtl/kavacha_core.sv
../../rtl/kavacha_debug.sv
../common/kavacha_uart.sv
../kavacha_fpga.sv
../common/common_reset_sync.sv
kavacha_arty_a7.sv
