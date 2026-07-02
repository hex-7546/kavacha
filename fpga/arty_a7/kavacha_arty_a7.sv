// ============================================================================
// kavacha_arty_a7.sv — Digilent Arty A7-100T top for the Kavacha SoC.
// Device: xc7a100tcsg324-1.  Runs the SoC directly at the board 100 MHz
// oscillator (no MMCM needed — these cores close timing easily at 100 MHz;
// add a Clocking Wizard if you want a different frequency).
//
//   CLK100        E3   100 MHz oscillator
//   ck_rst        C2   reset push-button (ACTIVE-LOW on Arty)
//   led[3:0]      H5 J5 T9 T10   (firmware walking-1 pattern = CPU is alive)
//   uart_txd_in   A9   host -> FPGA (our RX)
//   uart_rxd_out  D10  FPGA -> host (our TX), 115200-8N1
//   jtag_*        PMOD JA  RISC-V Debug — attach OpenOCD (verify JA pins/rev)
//
// Provide sw/firmware.mem to the Vivado project as "firmware.mem" (see README).
// ============================================================================
`default_nettype none

module kavacha_arty_a7 (
  input  wire       CLK100,
  input  wire       ck_rst,        // active-low
  output wire [3:0] led,
  input  wire       uart_txd_in,   // RX
  output wire       uart_rxd_out,  // TX
  // RISC-V Debug (JTAG) on PMOD JA
  input  wire       jtag_tck,
  input  wire       jtag_tms,
  input  wire       jtag_tdi,
  output wire       jtag_tdo
);
  // async-assert / sync-deassert reset (button active-low)
  wire sys_rst;
  common_reset_sync #(.DEPTH(3), .ACTIVE_HIGH(1'b1)) u_rst (
      .clk(CLK100), .async_rst_in(~ck_rst), .sync_rst_out(sys_rst));

  wire [7:0] soc_leds;
  kavacha_fpga #(.CLK_HZ(100_000_000), .UART_BAUD(115_200),
                 .MEM_WORDS(4096), .MEMFILE("firmware.mem")) u_soc (
      .clk(CLK100), .rst(sys_rst),
      .tck(jtag_tck), .tms(jtag_tms), .tdi(jtag_tdi), .tdo(jtag_tdo),
      .leds(soc_leds), .serial_tx(uart_rxd_out), .serial_rx(uart_txd_in),
      .tohost(), .tohost_we()
  );

  assign led = soc_leds[3:0];   // firmware walking-1 pattern
endmodule

`default_nettype wire
