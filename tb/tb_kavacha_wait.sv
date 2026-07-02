// tb_kavacha_wait.sv — proves Kavacha tolerates a NOT-ready (wait-stated) memory,
// the property any real bus (AXI4-Lite, etc.) requires. A periodic generator
// holds mem_stall high for WAITS cycles between each 1-cycle "ready" beat; the
// memory only commits writes on the ready beat. The smoke must still PASS.
`timescale 1ns/1ps
module tb_kavacha_wait;
  parameter int WAITS = 3;
  logic clk = 1'b0; always #5 clk = ~clk;
  logic rst;

  logic [31:0] imem [0:8191];
  logic [31:0] dram [0:8191];
  logic [31:0] imem_addr, imem_rdata, dmem_addr, dmem_wdata, dmem_rdata;
  logic        dmem_re, dmem_we; logic [3:0] dmem_be;
  logic [31:0] tohost; logic tohost_we_r;
  logic        rv; logic [31:0] rpc, rin, rval; logic rwe; logic [4:0] rrd;

  // wait-state generator: 1 ready cycle every (WAITS+1)
  logic [7:0] wcnt;
  wire mem_stall = (wcnt != WAITS);
  always_ff @(posedge clk) if (rst) wcnt <= 0; else wcnt <= (wcnt==WAITS) ? 0 : wcnt + 1;

  kavacha_core u_core (
    .clk(clk), .rst(rst), .imem_addr(imem_addr), .imem_rdata(imem_rdata),
    .dmem_addr(dmem_addr), .dmem_re(dmem_re), .dmem_we(dmem_we), .dmem_be(dmem_be),
    .dmem_wdata(dmem_wdata), .dmem_rdata(dmem_rdata),
    .irq_timer(1'b0), .irq_soft(1'b0), .irq_ext(1'b0), .mem_stall(mem_stall),
    .retire_valid(rv), .retire_pc(rpc), .retire_instr(rin),
    .retire_rd_we(rwe), .retire_rd(rrd), .retire_rd_val(rval)
  );

  assign imem_rdata = imem[imem_addr[14:2]];
  wire in_dram = (dmem_addr[31:28]==4'h8);
  wire [12:0] dramidx = dmem_addr[14:2];
  wire in_imem = (dmem_addr < 32'h8000);
  assign dmem_rdata = in_dram ? dram[dramidx] : in_imem ? imem[dmem_addr[14:2]] : 32'h0;
  wire [31:0] cur = dram[dramidx];
  wire [31:0] merged = {dmem_be[3]?dmem_wdata[31:24]:cur[31:24], dmem_be[2]?dmem_wdata[23:16]:cur[23:16],
                        dmem_be[1]?dmem_wdata[15:8]:cur[15:8], dmem_be[0]?dmem_wdata[7:0]:cur[7:0]};

  string hexf; integer i, cyc=0;
  initial begin
    if (!$value$plusargs("IMEM=%s", hexf)) begin $display("no IMEM"); $finish; end
    for (i=0;i<8192;i=i+1) begin imem[i]=32'h13; dram[i]=0; end
    $readmemh(hexf, imem);
    rst=1; repeat(4) @(posedge clk); rst=0;
    $display("[TB] wait-stated memory, WAITS=%0d", WAITS);
  end

  // writes commit only on the ready beat (mem_stall low)
  always_ff @(posedge clk) begin
    tohost_we_r <= 1'b0;
    if (!rst && dmem_we && !mem_stall) begin
      if (in_dram) dram[dramidx] <= merged;
      else if (dmem_addr==32'h20000000) begin tohost <= dmem_wdata; tohost_we_r <= 1'b1; end
    end
  end

  always @(posedge clk) begin
    if (!rst) cyc <= cyc + 1;
    if (tohost_we_r) begin
      $display("[TB] tohost=0x%08x at cycle %0d", tohost, cyc);
      if (tohost==32'd1) $display("[TB] PASS (latency-tolerant)");
      else               $display("[TB] FAIL");
      $finish;
    end
    if (cyc > 500000) begin $display("[TB] TIMEOUT"); $finish; end
  end
endmodule
