# Kavacha-on-Arty-A7-100T source list (Vivado read_verilog -sv / iverilog).
# Order: shared leaf cells, core, debug module, UART, FPGA SoC, common, top.
# -I include dirs: ../../../gandiva/rtl  (gandiva_pkg.sv) and ../../rtl.
../../../gandiva/rtl/gandiva_pkg.sv
../../../gandiva/rtl/gandiva_alu.sv
../../../gandiva/rtl/gandiva_regfile.sv
../../../gandiva/rtl/gandiva_muldiv.sv
../../../gandiva/rtl/gandiva_csr.sv
../../../gandiva/rtl/gandiva_rvc.sv
../../../gandiva/rtl/gandiva_immgen.sv
../../../gandiva/rtl/gandiva_branch.sv
../../../gandiva/rtl/gandiva_decode.sv
../../../gandiva/rtl/gandiva_pmp.sv
../../rtl/kavacha_core.sv
../../rtl/kavacha_debug.sv
../../../vajra/rtl/soc/vajra_uart.sv
../kavacha_fpga.sv
../../../../common/rtl/common_reset_sync.sv
kavacha_arty_a7.sv
