#!/usr/bin/env python3
"""
run_bench.py — Parse Kavacha + PicoRV32 benchmark logs and emit
               single-core or side-by-side comparison reports.

Modes:
  Single-core (legacy):
    python3 run_bench.py --results-dir results/ --iterations 1000 --scale 100

  Comparison:
    python3 run_bench.py --kavacha-dir results/kavacha/ \
                         --picorv-dir  results/picorv/  \
                         --results-dir results/          \
                         --iterations 1000 --scale 100  \
                         --compare

Output:
    results/report.md      — Markdown report
    results/report.csv     — CSV for further analysis
"""

import argparse
import re
import sys
from pathlib import Path
from datetime import datetime

# ---------------------------------------------------------------------------
EMBENCH_NAMES = [
    "aha-mont64", "crc32", "cubic", "edn", "huffbench",
    "matmult-int", "minver", "nbody", "nettle-aes", "nettle-sha256",
    "nsichneu", "picojpeg", "primecount", "qrduino", "sglib-combined",
    "slre", "st", "tarfind", "ud", "wikisort",
]
REDUCED_SCALE = {"picojpeg", "nsichneu", "qrduino", "wikisort"}


def parse_log(log_path: Path):
    if not log_path.exists():
        return {"name": log_path.stem, "status": "MISSING",
                "sim_cycles": None, "bench_cycles": None}
    text = log_path.read_text()
    r = {"name": log_path.stem, "status": "MISSING",
         "sim_cycles": None, "bench_cycles": None}

    m = re.search(
        r'\[BENCH\]\s+(\S+)\s+sim_cycles=(\d+)'
        r'(?:\s+bench_cycles=(\d+))?'
        r'\s+(PASS|FAIL\S*)', text)
    if m:
        r["name"]         = m.group(1)
        r["sim_cycles"]   = int(m.group(2))
        r["bench_cycles"] = int(m.group(3)) if m.group(3) else None
        r["status"]       = m.group(4)
    elif "TIMEOUT" in text:
        r["status"] = "TIMEOUT"
        sc = re.search(r'sim_cycles=(\d+)', text)
        if sc: r["sim_cycles"] = int(sc.group(1))
    return r


def fmt(n, sep=True):
    if n is None: return "—"
    return f"{n:,}" if sep else str(n)


def ratio_str(a, b):
    """Return 'a/b' as a ×N.NN string. <1 means a is faster."""
    if not a or not b: return "—"
    r = a / b
    arrow = "🟢" if r < 1.0 else ("🔴" if r > 1.0 else "⚪")
    return f"{arrow} {r:.3f}×"


def winner(a_cycles, b_cycles, a_name="Kavacha", b_name="PicoRV32"):
    if not a_cycles or not b_cycles: return "—"
    if a_cycles < b_cycles: return f"**{a_name}**"
    if b_cycles < a_cycles: return f"**{b_name}**"
    return "Tie"


# ---------------------------------------------------------------------------
def write_comparison(kav_dir: Path, prv_dir: Path, out_dir: Path,
                     iterations: int, scale: int):
    now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    # ---- CoreMark -----------------------------------------------------------
    km = parse_log(kav_dir / "coremark.log")
    pm = parse_log(prv_dir / "coremark.log")

    kav_cpi = km["sim_cycles"] / iterations if km["sim_cycles"] else None
    prv_cpi = pm["sim_cycles"] / iterations if pm["sim_cycles"] else None

    # ---- EMBench ------------------------------------------------------------
    eb_kav = []
    eb_prv = []
    for name in EMBENCH_NAMES:
        sc = 10 if name in REDUCED_SCALE else scale
        kr = parse_log(kav_dir / f"{name}.log"); kr["scale"] = sc
        pr = parse_log(prv_dir / f"{name}.log"); pr["scale"] = sc
        eb_kav.append(kr)
        eb_prv.append(pr)

    # ---- Markdown -----------------------------------------------------------
    md = [
        "# Kavacha vs PicoRV32 — Benchmark Comparison",
        "",
        f"Generated: {now}  ",
        "Simulator: **Verilator** (cycle-accurate)  ",
        "Compiler: `-O2 -march=rv32imc_zicsr -mabi=ilp32`  ",
        "Same firmware hex loaded into both simulators.",
        "",
        "## Core Configurations",
        "",
        "| | Kavacha | PicoRV32 |",
        "|---|---|---|",
        "| ISA | RV32IMC | RV32IMC |",
        "| Microarchitecture | Multi-cycle FSM | In-order, non-pipelined |",
        "| Multiply | 2-cycle | PCPI fast_mul (3-cycle) |",
        "| Divide | 34-cycle iterative | 32-cycle iterative |",
        "| Shifts | Single-cycle | Barrel (1-cycle) |",
        "| Memory interface | Separate IMEM/DMEM | Single unified bus (1-cycle latency) |",
        "| CSR 0xC00 (cycle) | ✅ | ✅ |",
        "",
        "---",
        "",
        "## CoreMark",
        f"",
        f"ITERATIONS = {iterations}",
        "",
        "| Metric | Kavacha | PicoRV32 | Ratio (Kavacha/PicoRV32) |",
        "|--------|---------|----------|--------------------------|",
    ]

    k_st = "✅ PASS" if km["status"] == "PASS" else f"❌ {km['status']}"
    p_st = "✅ PASS" if pm["status"] == "PASS" else f"❌ {pm['status']}"
    md += [
        f"| Status | {k_st} | {p_st} | — |",
        f"| Total sim cycles | {fmt(km['sim_cycles'])} | {fmt(pm['sim_cycles'])} | {ratio_str(km['sim_cycles'], pm['sim_cycles'])} |",
        f"| Cycles/iteration | {f'{kav_cpi:,.1f}' if kav_cpi else '—'} | {f'{prv_cpi:,.1f}' if prv_cpi else '—'} | {ratio_str(kav_cpi, prv_cpi)} |",
        f"| Winner | {winner(km['sim_cycles'], pm['sim_cycles'])} | | |",
    ]
    if kav_cpi and prv_cpi:
        md += [
            "",
            "> **CoreMark/MHz** = 1 000 000 / cycles_per_iter × target_clock_MHz",
            f"> Kavacha @ 50 MHz ≈ **{1e6/kav_cpi*50:.2f} CoreMark/MHz**",
            f"> PicoRV32 @ 50 MHz ≈ **{1e6/prv_cpi*50:.2f} CoreMark/MHz**",
        ]

    # ---- EMBench table ------------------------------------------------------
    md += [
        "",
        "---",
        "",
        "## EMBench-IoT",
        "",
        f"LOCAL_SCALE_FACTOR = {scale} (×10 for picojpeg, nsichneu, qrduino, wikisort)  ",
        "bench_cycles = firmware-measured mcycle delta across all repetitions.",
        "",
        ("| Benchmark | Scale | Kavacha cycles | PicoRV32 cycles"
         " | Ratio (K/P) | Winner |"),
        ("|-----------|-------|----------------|------------------"
         "|-------------|--------|"),
    ]

    kav_wins = prv_wins = ties = 0
    for kr, pr in zip(eb_kav, eb_prv):
        name = kr["name"]
        sc   = kr["scale"]
        kc   = kr["bench_cycles"] or kr["sim_cycles"]
        pc   = pr["bench_cycles"] or pr["sim_cycles"]
        rat  = ratio_str(kc, pc)
        w    = winner(kc, pc)
        if kc and pc:
            if kc < pc:  kav_wins += 1
            elif pc < kc: prv_wins += 1
            else:          ties += 1
        md.append(
            f"| {name:<20} | {sc:>5} | {fmt(kc):>16} "
            f"| {fmt(pc):>18} | {rat:>11} | {w} |"
        )

    kav_pass = sum(1 for r in eb_kav if r["status"] == "PASS")
    prv_pass = sum(1 for r in eb_prv if r["status"] == "PASS")
    n = len(EMBENCH_NAMES)

    md += [
        "",
        f"**EMBench PASS: Kavacha {kav_pass}/{n}  |  PicoRV32 {prv_pass}/{n}**",
        "",
        "---",
        "",
        "## Summary",
        "",
        "| | Kavacha | PicoRV32 |",
        "|---|---|---|",
        f"| CoreMark status | {km['status']} | {pm['status']} |",
        f"| CoreMark cycles/iter | {f'{kav_cpi:,.0f}' if kav_cpi else '—'} | {f'{prv_cpi:,.0f}' if prv_cpi else '—'} |",
        f"| EMBench PASS | {kav_pass}/{n} | {prv_pass}/{n} |",
        f"| EMBench wins (lower cycles) | {kav_wins} | {prv_wins} |",
        "",
        "> 🟢 ratio < 1.0 = Kavacha is faster  |  🔴 ratio > 1.0 = PicoRV32 is faster",
        "",
    ]

    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / "report.md").write_text("\n".join(md))
    print(f"[REPORT] Written: {out_dir / 'report.md'}")

    # ---- CSV ----------------------------------------------------------------
    csv = ["benchmark,kavacha_sim,kavacha_bench,picorv_sim,picorv_bench,"
           "kavacha_per_rep,picorv_per_rep,ratio_k_p,scale"]
    # CoreMark
    csv.append(
        f"coremark,{km['sim_cycles'] or ''},,{pm['sim_cycles'] or ''},"
        f",{f'{kav_cpi:.0f}' if kav_cpi else ''},"
        f"{f'{prv_cpi:.0f}' if prv_cpi else ''},{iterations}")
    for kr, pr in zip(eb_kav, eb_prv):
        sc = kr["scale"]
        kc = kr["bench_cycles"] or kr["sim_cycles"] or ""
        pc = pr["bench_cycles"] or pr["sim_cycles"] or ""
        kcr = f"{int(kc)/sc:.0f}" if kc else ""
        pcr = f"{int(pc)/sc:.0f}" if pc else ""
        rat = f"{int(kc)/int(pc):.4f}" if kc and pc else ""
        csv.append(f"{kr['name']},{kr['sim_cycles'] or ''},{kr['bench_cycles'] or ''},"
                   f"{pr['sim_cycles'] or ''},{pr['bench_cycles'] or ''},"
                   f"{kcr},{pcr},{rat},{sc}")
    (out_dir / "report.csv").write_text("\n".join(csv) + "\n")
    print(f"[REPORT] Written: {out_dir / 'report.csv'}")

    # ---- Console summary ----------------------------------------------------
    print()
    print("=" * 70)
    print("  KAVACHA vs PICORV32 — BENCHMARK SUMMARY")
    print("=" * 70)
    if kav_cpi and prv_cpi:
        faster = "Kavacha" if kav_cpi < prv_cpi else "PicoRV32"
        print(f"  CoreMark cycles/iter:  Kavacha={kav_cpi:,.0f}  PicoRV32={prv_cpi:,.0f}")
        print(f"  CoreMark winner:       {faster}")
    print(f"  EMBench PASS:          Kavacha={kav_pass}/{n}  PicoRV32={prv_pass}/{n}")
    print(f"  EMBench wins:          Kavacha={kav_wins}  PicoRV32={prv_wins}  Ties={ties}")
    print("=" * 70)
    print()


# ---------------------------------------------------------------------------
def write_single(results_dir: Path, iterations: int, scale: int):
    """Legacy single-core (Kavacha only) report."""
    now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    cm = parse_log(results_dir / "coremark.log")
    cpi = cm["sim_cycles"] / iterations if cm["sim_cycles"] else None

    md = [f"# Kavacha Benchmark Results", f"", f"Generated: {now}", ""]
    md += ["## CoreMark", "", f"ITERATIONS = {iterations}", ""]
    if cm["status"] == "PASS" and cpi:
        md += [f"Cycles/iteration: **{cpi:,.0f}**",
               f"CoreMark/MHz @ 50 MHz: **{1e6/cpi*50:.2f}**", ""]
    else:
        md += [f"Status: {cm['status']}", ""]

    md += ["## EMBench-IoT", "",
           "| Benchmark | Status | bench_cycles |",
           "|-----------|--------|-------------|"]
    for name in EMBENCH_NAMES:
        r = parse_log(results_dir / f"{name}.log")
        icon = "✅" if r["status"] == "PASS" else "❌"
        md.append(f"| {name} | {icon} {r['status']} | {fmt(r['bench_cycles'])} |")

    results_dir.mkdir(parents=True, exist_ok=True)
    (results_dir / "report.md").write_text("\n".join(md))
    print(f"[REPORT] Written: {results_dir / 'report.md'}")


# ---------------------------------------------------------------------------
def main():
    p = argparse.ArgumentParser()
    p.add_argument("--results-dir",  default="results")
    p.add_argument("--kavacha-dir",  default=None)
    p.add_argument("--picorv-dir",   default=None)
    p.add_argument("--iterations",   type=int, default=1000)
    p.add_argument("--scale",        type=int, default=100)
    p.add_argument("--compare",      action="store_true")
    args = p.parse_args()

    out = Path(args.results_dir)

    if args.compare:
        if not args.kavacha_dir or not args.picorv_dir:
            print("ERROR: --compare requires --kavacha-dir and --picorv-dir",
                  file=sys.stderr)
            sys.exit(1)
        write_comparison(Path(args.kavacha_dir), Path(args.picorv_dir),
                         out, args.iterations, args.scale)
    else:
        write_single(out, args.iterations, args.scale)


if __name__ == "__main__":
    main()
