# ============================================================================
# kavacha_arty_a7.xdc — Digilent Arty A7-100T (xc7a100tcsg324-1), LVCMOS33.
# ============================================================================

# 100 MHz system clock
set_property -dict {PACKAGE_PIN E3 IOSTANDARD LVCMOS33} [get_ports CLK100]
create_clock -period 10.000 -name sys_clk_pin -waveform {0.000 5.000} -add [get_ports CLK100]

# Reset push-button (active-low on Arty)
set_property -dict {PACKAGE_PIN C2 IOSTANDARD LVCMOS33} [get_ports ck_rst]

# 4 green user LEDs (LD4..LD7)
set_property -dict {PACKAGE_PIN H5  IOSTANDARD LVCMOS33} [get_ports {led[0]}]
set_property -dict {PACKAGE_PIN J5  IOSTANDARD LVCMOS33} [get_ports {led[1]}]
set_property -dict {PACKAGE_PIN T9  IOSTANDARD LVCMOS33} [get_ports {led[2]}]
set_property -dict {PACKAGE_PIN T10 IOSTANDARD LVCMOS33} [get_ports {led[3]}]

# USB-UART bridge
set_property -dict {PACKAGE_PIN A9  IOSTANDARD LVCMOS33} [get_ports uart_txd_in]
set_property -dict {PACKAGE_PIN D10 IOSTANDARD LVCMOS33} [get_ports uart_rxd_out]

# RISC-V Debug JTAG on PMOD JA (JA1..JA4). Attach an FT2232H / J-Link / OpenOCD
# bitbang adapter. Verify these pins against your Arty A7 board revision.
set_property -dict {PACKAGE_PIN G13 IOSTANDARD LVCMOS33} [get_ports jtag_tck]
set_property -dict {PACKAGE_PIN B11 IOSTANDARD LVCMOS33} [get_ports jtag_tms]
set_property -dict {PACKAGE_PIN A11 IOSTANDARD LVCMOS33} [get_ports jtag_tdi]
set_property -dict {PACKAGE_PIN D12 IOSTANDARD LVCMOS33} [get_ports jtag_tdo]

# JTAG is driven from a slow external adapter (oversampled in-core) — relax it
set_false_path -from [get_ports {jtag_tck jtag_tms jtag_tdi}]
set_false_path -to   [get_ports jtag_tdo]
