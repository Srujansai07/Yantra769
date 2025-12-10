#!/usr/bin/env python3
"""
============================================================================
OPENLANE SYNTHESIS SCRIPT - Yantra769 Vedic Chip
============================================================================

This script runs OpenLane (open-source ASIC flow) to synthesize 
the Yantra Vedic ALU for SkyWater 130nm fabrication.

Prerequisites:
1. Install Docker: https://docs.docker.com/get-docker/
2. Install OpenLane: https://openlane.readthedocs.io/

Run with:
$ python synthesis/run_openlane.py

============================================================================
"""

import os
import subprocess
import shutil
from pathlib import Path

# Project configuration
PROJECT_NAME = "yantra769"
TOP_MODULE = "yantra_alu"
CLOCK_PERIOD = 20  # 50 MHz = 20ns period

# Paths
SCRIPT_DIR = Path(__file__).parent
PROJECT_ROOT = SCRIPT_DIR.parent
RTL_DIR = PROJECT_ROOT / "rtl"
OUTPUT_DIR = PROJECT_ROOT / "synthesis" / "output"

# OpenLane configuration
OPENLANE_CONFIG = f"""
# Yantra769 OpenLane Configuration
# For SkyWater 130nm Open PDK

set ::env(DESIGN_NAME) "{TOP_MODULE}"
set ::env(VERILOG_FILES) [glob {RTL_DIR}/*.v]
set ::env(CLOCK_PORT) "clk"
set ::env(CLOCK_PERIOD) "{CLOCK_PERIOD}"

# Synthesis tuning
set ::env(SYNTH_STRATEGY) "DELAY 1"
set ::env(SYNTH_MAX_FANOUT) 6

# Floor planning
set ::env(FP_SIZING) "absolute"
set ::env(DIE_AREA) "0 0 500 500"
set ::env(FP_CORE_UTIL) 40

# Placement
set ::env(PL_TARGET_DENSITY) 0.45
set ::env(PL_RANDOM_GLB_PLACEMENT) 0

# Routing
set ::env(ROUTING_CORES) 4
set ::env(GLB_RT_ADJUSTMENT) 0.1

# Power
set ::env(VDD_NETS) "vccd1"
set ::env(GND_NETS) "vssd1"

# DRC/LVS
set ::env(RUN_DRC) 1
set ::env(RUN_LVS) 1

# Output
set ::env(DESIGN_DIR) "{OUTPUT_DIR}"
"""

def check_prerequisites():
    """Check if required tools are installed"""
    print("=" * 60)
    print("YANTRA769 SYNTHESIS - Checking prerequisites...")
    print("=" * 60)
    
    # Check Docker
    try:
        result = subprocess.run(["docker", "--version"], capture_output=True, text=True)
        print(f"✓ Docker: {result.stdout.strip()}")
    except FileNotFoundError:
        print("✗ Docker not found. Install from: https://docs.docker.com/get-docker/")
        return False
    
    return True

def write_config():
    """Write OpenLane configuration file"""
    config_path = PROJECT_ROOT / "synthesis" / "config.tcl"
    config_path.parent.mkdir(parents=True, exist_ok=True)
    
    with open(config_path, 'w') as f:
        f.write(OPENLANE_CONFIG)
    
    print(f"✓ Configuration written to: {config_path}")
    return config_path

def run_yosys_synthesis():
    """Run Yosys for RTL synthesis (standalone, no Docker needed)"""
    print("\n" + "=" * 60)
    print("Running Yosys RTL Synthesis...")
    print("=" * 60)
    
    output_dir = PROJECT_ROOT / "synthesis" / "output"
    output_dir.mkdir(parents=True, exist_ok=True)
    
    # Yosys synthesis script
    yosys_script = f"""
# Yantra769 Yosys Synthesis Script
# Converts Verilog RTL to gate-level netlist

# Read Verilog files
read_verilog {RTL_DIR}/yantra_alu.v
read_verilog {RTL_DIR}/vedic_multiplier.v

# Elaborate design
hierarchy -check -top {TOP_MODULE}

# Synthesize
synth -top {TOP_MODULE}

# Technology mapping (generic for now)
techmap

# Optimization passes
opt
opt_clean

# Write outputs
write_verilog {output_dir}/yantra_netlist.v
write_json {output_dir}/yantra_netlist.json

# Statistics
stat
"""
    
    script_path = output_dir / "synth.ys"
    with open(script_path, 'w') as f:
        f.write(yosys_script)
    
    print(f"✓ Yosys script written to: {script_path}")
    
    # Try to run Yosys if installed
    try:
        result = subprocess.run(
            ["yosys", "-s", str(script_path)],
            capture_output=True,
            text=True,
            cwd=str(PROJECT_ROOT)
        )
        print(result.stdout)
        if result.returncode == 0:
            print("✓ Synthesis completed successfully!")
            print(f"  Netlist: {output_dir}/yantra_netlist.v")
        else:
            print(f"✗ Synthesis failed: {result.stderr}")
    except FileNotFoundError:
        print("\n" + "=" * 60)
        print("Yosys not installed locally.")
        print("To install:")
        print("  Windows: Download from https://github.com/YosysHQ/oss-cad-suite-build/releases")
        print("  Or use Docker: docker run -it --rm -v $PWD:/work efabless/openlane")
        print("=" * 60)

def create_gds_script():
    """Create script for GDS generation (final layout)"""
    gds_script = """#!/bin/bash
# Yantra769 GDS Generation Script
# Run this inside OpenLane Docker container

cd /openlane
./flow.tcl -design yantra769 -tag run_001 -overwrite

echo "GDS file generated at: designs/yantra769/runs/run_001/results/final/gds/"
"""
    
    script_path = PROJECT_ROOT / "synthesis" / "generate_gds.sh"
    with open(script_path, 'w') as f:
        f.write(gds_script)
    
    print(f"✓ GDS generation script: {script_path}")

def print_next_steps():
    """Print next steps for the user"""
    print("\n" + "=" * 60)
    print("NEXT STEPS TO FABRICATE REAL SILICON:")
    print("=" * 60)
    print("""
1. INSTALL TOOLS (free, open-source):
   - Yosys: https://github.com/YosysHQ/yosys
   - OpenLane: https://github.com/The-OpenROAD-Project/OpenLane
   - Or use Docker: docker pull efabless/openlane

2. RUN SYNTHESIS:
   cd Yantra769
   yosys -s synthesis/output/synth.ys

3. SUBMIT TO TINYTAPEOUT ($500 for real silicon):
   - Go to: https://tinytapeout.com
   - Upload tt_um_yantra769.v
   - Wait for fabrication (~6 months)
   - Receive your REAL Vedic mathematics chip!

4. ALTERNATIVE - FPGA ($200-500 for immediate hardware):
   - Buy: Digilent Basys 3 or Arty A7
   - Install: Xilinx Vivado (free WebPack edition)
   - Program with yantra_alu.v
   - Test immediately!

Files created:
- rtl/yantra_alu.v         : Complete 32-bit Vedic ALU
- rtl/tt_um_yantra769.v    : TinyTapeout-ready wrapper
- rtl/sri_yantra_cache.v   : Golden ratio cache hierarchy
- synthesis/config.tcl     : OpenLane configuration
- synthesis/output/synth.ys: Yosys synthesis script
""")

def main():
    print("\n")
    print("╔══════════════════════════════════════════════════════════╗")
    print("║        YANTRA769 - VEDIC CHIP SYNTHESIS FLOW             ║")
    print("║   Ancient Sanatana Dharma Wisdom → Modern Silicon        ║")
    print("╚══════════════════════════════════════════════════════════╝")
    print()
    
    # Setup
    check_prerequisites()
    write_config()
    run_yosys_synthesis()
    create_gds_script()
    print_next_steps()

if __name__ == "__main__":
    main()
