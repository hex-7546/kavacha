// ============================================================================
// kavacha_zcu102.sv — Xilinx ZCU102 (xczu9eg-ffvb1156-2-e) PL top for Kavacha.
//
// TEMPLATE — verify pins/clocking against your ZCU102 board revision (UG1182 /
// the board master XDC) before building. Two board-specific choices you must
// finalise:
//   * Clock: the ZCU102 PL has no convenient fixed single-ended oscillator.
//     Drive `pl_clk` from a Clocking Wizard output (fed by the USER_SI570
//     differential clock) or from the PS `pl_clk0`. Set CLK_HZ to match.
//   * UART: the on-board USB-UART (CP2108) is wired to the PS MIO, not the PL.
//     Route uart_tx/uart_rx to a PMOD (e.g. PMOD0) for a PL-only console.
//
// The RTL itself is board-agnostic: feed it one clock + one reset and it runs.
// ============================================================================
`default_nettype none

module kavacha_zcu102 (
  input  wire       pl_clk,        // from Clocking Wizard / PS pl_clk0 (set CLK_HZ)
  input  wire       rst,           // active-high reset (GPIO push-button)
  output wire [7:0] led,           // 8 PL user LEDs (GPIO_LED_0..7)
  input  wire       uart_rx,       // host -> FPGA (PMOD)
  output wire       uart_tx,       // FPGA -> host (PMOD), 115200-8N1
  // RISC-V Debug (JTAG) on a PMOD — attach OpenOCD
  input  wire       jtag_tck,
  input  wire       jtag_tms,
  input  wire       jtag_tdi,
  output wire       jtag_tdo
);
  wire sys_rst;
  common_reset_sync #(.DEPTH(3), .ACTIVE_HIGH(1'b1)) u_rst (
      .clk(pl_clk), .async_rst_in(rst), .sync_rst_out(sys_rst));

  wire [7:0] soc_leds;
  kavacha_fpga #(.CLK_HZ(100_000_000), .UART_BAUD(115_200),
                 .MEM_WORDS(4096), .MEMFILE("firmware.mem")) u_soc (
      .clk(pl_clk), .rst(sys_rst),
      .tck(jtag_tck), .tms(jtag_tms), .tdi(jtag_tdi), .tdo(jtag_tdo),
      .leds(soc_leds), .serial_tx(uart_tx), .serial_rx(uart_rx),
      .tohost(), .tohost_we()
  );

  assign led = soc_leds;          // firmware walking-1 pattern across all 8 LEDs
endmodule

`default_nettype wire
