#!/usr/bin/env python3
"""
plot_benchmarks.py
Generates performance comparison graphs:
1. CoreMark/MHz (including standard industry cores for context)
2. EMBench-IoT Geometric Mean of execution cycles
3. Resource Utilization (LUTs and FFs)
"""

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
from pathlib import Path
import os

# Set plotting style
sns.set_theme(style="darkgrid")
plt.rcParams['font.family'] = 'serif'
plt.rcParams['font.size'] = 11

def main():
    # Setup paths
    base_dir = Path(__file__).parent
    report_csv = base_dir / 'results' / 'report.csv'
    
    if not report_csv.exists():
        print(f"Error: {report_csv} not found.")
        return

    # 1. Load Data
    df = pd.read_csv(report_csv)

    # CoreMark Data
    cm_row = df[df['benchmark'] == 'coremark'].iloc[0]
    kavacha_cpi = cm_row['kavacha_per_rep']
    picorv_cpi = cm_row['picorv_per_rep']

    # We scale Kavacha relative to PicoRV32's known ~0.40 CoreMark/MHz baseline
    # (since the simulation iteration count might differ from standard 1.0M cycle iter)
    picorv_cm_mhz_baseline = 0.40
    kavacha_cm_mhz = picorv_cm_mhz_baseline * (picorv_cpi / kavacha_cpi)

    # 2. Embench Geometric Mean (Cycles per rep)
    eb_df = df[(df['benchmark'] != 'coremark')].copy()
    eb_df = eb_df.dropna(subset=['kavacha_per_rep', 'picorv_per_rep'])
    
    # Geometric mean of the per-repetition cycles
    geomean_kavacha = np.exp(np.mean(np.log(eb_df['kavacha_per_rep'])))
    geomean_picorv = np.exp(np.mean(np.log(eb_df['picorv_per_rep'])))

    # 3. Compile Data for Plots
    
    cm_cores = ['PicoRV32', 'Kavacha']
    cm_scores = [picorv_cm_mhz_baseline, kavacha_cm_mhz]

    # Resource Utilization Data (from synthesis reports)
    res_data = pd.DataFrame({
        'Core': ['Kavacha', 'Kavacha', 'Kavacha', 'PicoRV32', 'PicoRV32', 'PicoRV32'],
        'Resource': ['LUTs', 'FFs', 'DSPs', 'LUTs', 'FFs', 'DSPs'],
        'Count': [2557, 733, 12, 1740, 862, 4]
    })

    # 4. Create Plots
    fig, axes = plt.subplots(1, 3, figsize=(18, 6))

    # --- Plot 1: CoreMark/MHz ---
    # Highlight Kavacha and PicoRV32
    colors = ['#c44e52' if c == 'PicoRV32' else '#2ca02c' if c == 'Kavacha' else '#4c72b0' for c in cm_cores]
    sns.barplot(x=cm_cores, y=cm_scores, ax=axes[0], palette=colors)
    axes[0].set_ylabel('CoreMark/MHz')
    axes[0].set_title('CoreMark/MHz Comparison')
    for label in axes[0].get_xticklabels():
        label.set_rotation(90)
        
    # --- Plot 2: Embench Geometric Mean ---
    sns.barplot(x=['PicoRV32', 'Kavacha'], y=[geomean_picorv, geomean_kavacha], ax=axes[1], palette=['#c44e52', '#2ca02c'])
    axes[1].set_ylabel('Geometric Mean (Cycles / Iteration)')
    axes[1].set_title('EMBench-IoT Geometric Mean\n(Lower is Better)')

    # --- Plot 3: Resource Utilization ---
    sns.barplot(x='Core', y='Count', hue='Resource', data=res_data, ax=axes[2], palette=['#55a868', '#ccb974', '#8172b3'])
    axes[2].set_ylabel('Resource Count')
    axes[2].set_title('FPGA Resource Utilization\n(Vivado xc7a100t)')

    plt.tight_layout()
    
    out_path = base_dir / 'results' / 'benchmark_graphs.png'
    plt.savefig(out_path, dpi=300, bbox_inches='tight')
    print(f"[SUCCESS] Graphs generated at: {out_path}")
    
    # Print numerical results to console
    print("\n--- Numerical Summary ---")
    print(f"Kavacha CoreMark/MHz (scaled): {kavacha_cm_mhz:.3f}")
    print(f"PicoRV32 CoreMark/MHz:         {picorv_cm_mhz_baseline:.3f}")
    print(f"Kavacha EMBench GeoMean:       {geomean_kavacha:.0f} cycles")
    print(f"PicoRV32 EMBench GeoMean:      {geomean_picorv:.0f} cycles")
    print(f"Kavacha LUTs/FFs/DSPs:         2557 / 733 / 12")
    print(f"PicoRV32 LUTs/FFs/DSPs:        1740 / 862 / 4")

if __name__ == "__main__":
    main()
