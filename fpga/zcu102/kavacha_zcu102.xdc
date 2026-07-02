# ============================================================================
# kavacha_zcu102.xdc — ZCU102 (xczu9eg-ffvb1156-2-e) PL constraints.
#
# !!! TEMPLATE — PLACEHOLDER PINS. Verify EVERY line against the ZCU102 master
# !!! XDC (Xilinx UG1182 / board files) for YOUR board revision before build.
# The pins below are typical ZCU102 PL assignments but MUST be confirmed.
# ============================================================================

# --- PL clock -----------------------------------------------------------------
# Option A (recommended): drive pl_clk from a Clocking Wizard whose input is the
# USER_SI570 differential clock; then constrain the *generated* clock instead and
# remove the create_clock below. Option B: PS pl_clk0 (handled by the PS block).
# Placeholder: treat pl_clk as a 100 MHz clock.
create_clock -period 10.000 -name pl_clk [get_ports pl_clk]
# set_property PACKAGE_PIN <PIN> [get_ports pl_clk]   ;# set when using a direct pin
# set_property IOSTANDARD LVCMOS18 [get_ports pl_clk]

# --- reset (GPIO push-button, active-high) ------------------------------------
set_property -dict {PACKAGE_PIN AG13 IOSTANDARD LVCMOS33} [get_ports rst]    ;# VERIFY (GPIO_SW)

# --- 8 PL user LEDs (GPIO_LED_0..7) -------------------------------------------
set_property -dict {PACKAGE_PIN AG14 IOSTANDARD LVCMOS33} [get_ports {led[0]}] ;# VERIFY
set_property -dict {PACKAGE_PIN AF13 IOSTANDARD LVCMOS33} [get_ports {led[1]}] ;# VERIFY
set_property -dict {PACKAGE_PIN AE13 IOSTANDARD LVCMOS33} [get_ports {led[2]}] ;# VERIFY
set_property -dict {PACKAGE_PIN AJ14 IOSTANDARD LVCMOS33} [get_ports {led[3]}] ;# VERIFY
set_property -dict {PACKAGE_PIN AJ15 IOSTANDARD LVCMOS33} [get_ports {led[4]}] ;# VERIFY
set_property -dict {PACKAGE_PIN AH13 IOSTANDARD LVCMOS33} [get_ports {led[5]}] ;# VERIFY
set_property -dict {PACKAGE_PIN AH14 IOSTANDARD LVCMOS33} [get_ports {led[6]}] ;# VERIFY
set_property -dict {PACKAGE_PIN AL12 IOSTANDARD LVCMOS33} [get_ports {led[7]}] ;# VERIFY

# --- UART on a PMOD (PL) — VERIFY against your PMOD wiring ---------------------
set_property -dict {PACKAGE_PIN A20 IOSTANDARD LVCMOS33} [get_ports uart_rx]    ;# VERIFY (PMOD0)
set_property -dict {PACKAGE_PIN B20 IOSTANDARD LVCMOS33} [get_ports uart_tx]    ;# VERIFY (PMOD0)

# --- RISC-V Debug JTAG on a PMOD ----------------------------------------------
set_property -dict {PACKAGE_PIN C20 IOSTANDARD LVCMOS33} [get_ports jtag_tck]   ;# VERIFY
set_property -dict {PACKAGE_PIN D20 IOSTANDARD LVCMOS33} [get_ports jtag_tms]   ;# VERIFY
set_property -dict {PACKAGE_PIN E20 IOSTANDARD LVCMOS33} [get_ports jtag_tdi]   ;# VERIFY
set_property -dict {PACKAGE_PIN F20 IOSTANDARD LVCMOS33} [get_ports jtag_tdo]   ;# VERIFY
set_false_path -from [get_ports {jtag_tck jtag_tms jtag_tdi}]
set_false_path -to   [get_ports jtag_tdo]
