# build.ps1 — Build & run Kavacha under Icarus Verilog 12+ on Windows.
#   .\build.ps1            # build + smoke
#   .\build.ps1 cosim      # build + smoke + golden co-simulation
#   .\build.ps1 rvfi       # RVFI (riscv-formal interface) self-check
#   .\build.ps1 debug      # JTAG / Debug-Module self-check
#   .\build.ps1 ecc        # register-file SECDED ECC unit test
#   .\build.ps1 clean
param([string]$Action = "sim")
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$IVL = if ($env:IVERILOG) { $env:IVERILOG } else { "C:\iverilog\bin\iverilog.exe" }
$VVP = if ($env:VVP)      { $env:VVP }      else { "C:\iverilog\bin\vvp.exe" }

$C = "rtl\common"
$R = "rtl"
$cells = @(
  "$C\gandiva_pkg.sv","$C\gandiva_alu.sv","$C\gandiva_regfile.sv",
  "$C\gandiva_muldiv.sv","$C\gandiva_csr.sv","$C\gandiva_rvc.sv",
  "$C\gandiva_immgen.sv","$C\gandiva_branch.sv","$C\gandiva_decode.sv","$C\gandiva_pmp.sv"
)
$core = @("$R\kavacha_core.sv","$R\kavacha_debug.sv","$R\kavacha_soc.sv")

if ($Action -eq "clean") {
    Remove-Item -Recurse -Force sim, programs\build -ErrorAction SilentlyContinue
    Get-ChildItem -Filter *.vcd -ErrorAction SilentlyContinue | Remove-Item
    Write-Host "Cleaned."; return
}
New-Item -ItemType Directory -Force sim, programs\build | Out-Null

if ($Action -eq "ecc") {
    Write-Host "Building register-file SECDED ECC unit test..."
    & $IVL -g2012 -I $C -o sim\tb_regfile_ecc "$C\gandiva_pkg.sv" "$C\gandiva_regfile_ecc.sv" tb\tb_regfile_ecc.sv
    if ($LASTEXITCODE -ne 0) { throw "iverilog failed" }
    & $VVP sim\tb_regfile_ecc; return
}

python programs\build_smoke.py
if ($LASTEXITCODE -ne 0) { throw "build_smoke.py failed" }

Write-Host "Compiling..."
& $IVL -g2012 -I $C -I $R -o sim\tb_kavacha @cells @core tb\tb_kavacha.sv
if ($LASTEXITCODE -ne 0) { throw "iverilog failed" }

Write-Host "Running smoke..."
& $VVP sim\tb_kavacha +IMEM=programs\build\smoke.hex

if ($Action -eq "cosim") {
    Write-Host "Co-simulating against the golden RV32IM ISA model..."
    $env:VVP = $VVP
    python tools\cosim.py --hex programs\build\smoke.hex --sim sim\tb_kavacha
}
if ($Action -eq "rvfi") {
    Write-Host "Building RVFI self-check..."
    & $IVL -g2012 -DRISCV_FORMAL -I $C -I $R -o sim\tb_kavacha_rvfi @cells @core tb\tb_kavacha_rvfi.sv
    if ($LASTEXITCODE -ne 0) { throw "iverilog failed" }
    & $VVP sim\tb_kavacha_rvfi +IMEM=programs\build\smoke.hex
}
if ($Action -eq "debug") {
    Write-Host "Building JTAG / Debug-Module self-check..."
    & $IVL -g2012 -I $C -I $R -o sim\tb_kavacha_debug @cells @core tb\tb_kavacha_debug.sv
    if ($LASTEXITCODE -ne 0) { throw "iverilog failed" }
    & $VVP sim\tb_kavacha_debug +IMEM=programs\build\smoke.hex
}
