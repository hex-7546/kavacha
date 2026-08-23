#!/usr/bin/env python3
"""
run_bench_unified.py — Parse Gandiva, VexRiscv, Ibex, Kavacha, and PicoRV32 benchmark logs.
"""
import argparse
import re
import sys
from pathlib import Path
from datetime import datetime

EMBENCH_NAMES = [
    "aha-mont64", "crc32", "depthconv", "edn", "huffbench",
    "matmult-int", "md5sum", "nettle-aes", "nettle-sha256", "nsichneu",
    "picojpeg", "qrduino", "sglib-combined", "slre", "statemate",
    "tarfind", "ud", "wikisort", "xgboost",
]
REDUCED_SCALE = {"picojpeg", "nsichneu", "qrduino", "wikisort"}

def parse_log(log_path: Path):
    if not log_path.exists():
        return {"name": log_path.stem, "status": "MISSING", "sim_cycles": None, "bench_cycles": None}
    
    text = log_path.read_text()
    r = {"name": log_path.stem, "status": "MISSING", "sim_cycles": None, "bench_cycles": None}

    # Standard Vbench output parser
    m = re.search(r'\[BENCH\]\s+(\S+)\s+sim_cycles=(\d+)(?:\s+bench_cycles=(\d+))?\s+(PASS|FAIL\S*)', text)
    if m:
        r["name"] = m.group(1)
        r["sim_cycles"] = int(m.group(2))
        r["bench_cycles"] = int(m.group(3)) if m.group(3) else None
        r["status"] = m.group(4)
        return r

    # VexRiscv and Ibex output parsers
    if "Cycles:" in text: # Ibex specific log parser
        cycles_match = re.search(r'Cycles:\s+(\d+)', text)
        if cycles_match:
            r["sim_cycles"] = int(cycles_match.group(1))
            r["bench_cycles"] = r["sim_cycles"]
            r["status"] = "PASS"
            return r
            
    if "Finished: cycle count =" in text: # VexRiscv parser fallback
        cycles_match = re.search(r'Finished: cycle count =\s+(\d+)', text)
        if cycles_match:
            r["sim_cycles"] = int(cycles_match.group(1))
            r["bench_cycles"] = r["sim_cycles"]
            r["status"] = "PASS"
            return r

    if "TIMEOUT" in text:
        r["status"] = "TIMEOUT"
    return r

def fmt(n):
    return f"{n:,}" if n else "—"

def write_comparison(dirs, out_dir: Path, iterations: int, scale: int):
    now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    
    core_names = ["Gandiva", "VexRiscv", "Ibex", "Vega"]
    dir_paths = [dirs["gandiva"], dirs["vexriscv"], dirs["ibex"], dirs.get("vega", Path("/dev/null"))]
    
    # ---- CoreMark -----------------------------------------------------------
    cm_logs = [parse_log(d / "coremark.log") for d in dir_paths]
    cm_cpis = [log["sim_cycles"] / iterations if log["sim_cycles"] else None for log in cm_logs]

    # ---- EMBench ------------------------------------------------------------
    eb_logs = {core: [] for core in core_names}
    for name in EMBENCH_NAMES:
        sc = 10 if name in REDUCED_SCALE else scale
        for core, d in zip(core_names, dir_paths):
            res = parse_log(d / f"{name}.log")
            res["scale"] = sc
            eb_logs[core].append(res)

    # ---- Markdown -----------------------------------------------------------
    md = [
        "# Industry Benchmarking: Gandiva vs VexRiscv vs Ibex vs Vega",
        "",
        f"Generated: {now}  ",
        "Simulator: **Verilator** (cycle-accurate)  ",
        "Compiler: `-O2 -march=rv32imc_zicsr -mabi=ilp32`  ",
        "",
        "## CoreMark",
        f"ITERATIONS = {iterations}",
        "",
        "| Metric | " + " | ".join(core_names) + " |",
        "|--------|" + "|".join(["---"] * len(core_names)) + "|",
        "| Status | " + " | ".join(["✅ PASS" if l["status"] == "PASS" else f"❌ {l['status']}" for l in cm_logs]) + " |",
        "| Cycles | " + " | ".join([fmt(l["sim_cycles"]) for l in cm_logs]) + " |",
        "| Cycles/Iter | " + " | ".join([f"{cpi:,.1f}" if cpi else "—" for cpi in cm_cpis]) + " |",
        "| CoreMark/MHz (@50MHz) | " + " | ".join([f"{1e6/cpi*50:.2f}" if cpi else "—" for cpi in cm_cpis]) + " |",
        "",
        "---",
        "",
        "## EMBench-IoT",
        f"LOCAL_SCALE_FACTOR = {scale} (×10 for picojpeg, nsichneu, qrduino, wikisort)",
        "",
        "| Benchmark | " + " | ".join(core_names) + " |",
        "|-----------|" + "|".join(["---"] * len(core_names)) + "|"
    ]

    for i, name in enumerate(EMBENCH_NAMES):
        cycles = []
        for core in core_names:
            kr = eb_logs[core][i]
            kc = kr["bench_cycles"] or kr["sim_cycles"]
            cycles.append(fmt(kc))
        md.append(f"| {name:<20} | " + " | ".join(cycles) + " |")

    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / "report_unified.md").write_text("\n".join(md))
    print(f"[REPORT] Written: {out_dir / 'report_unified.md'}")

    # ---- CSV ----------------------------------------------------------------
    csv = ["benchmark," + ",".join(core_names)]
    csv.append("coremark," + ",".join([str(l["sim_cycles"] or "") for l in cm_logs]))
    for i, name in enumerate(EMBENCH_NAMES):
        row = [name]
        for core in core_names:
            kr = eb_logs[core][i]
            kc = kr["bench_cycles"] or kr["sim_cycles"]
            row.append(str(kc or ""))
        csv.append(",".join(row))
        
    (out_dir / "report_unified.csv").write_text("\n".join(csv) + "\n")
    print(f"[REPORT] Written: {out_dir / 'report_unified.csv'}")


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--results-dir",  default="results")
    p.add_argument("--gandiva-dir",  required=True)
    p.add_argument("--vexriscv-dir", required=True)
    p.add_argument("--ibex-dir",     required=True)
    p.add_argument("--vega-dir",     default=None)
    p.add_argument("--iterations",   type=int, default=1000)
    p.add_argument("--scale",        type=int, default=100)
    p.add_argument("--compare",      action="store_true")
    args = p.parse_args()

    dirs = {
        "gandiva": Path(args.gandiva_dir),
        "vexriscv": Path(args.vexriscv_dir),
        "ibex": Path(args.ibex_dir),
        "vega": Path(args.vega_dir) if args.vega_dir else Path("/dev/null")
    }

    if args.compare:
        write_comparison(dirs, Path(args.results_dir), args.iterations, args.scale)


if __name__ == "__main__":
    main()
