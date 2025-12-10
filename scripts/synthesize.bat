@echo off
REM ============================================================================
REM YANTRA769 - SYNTHESIZE SPU WITH YOSYS
REM ============================================================================
REM Synthesizes the Sri-Processing Unit to gate-level netlist
REM ============================================================================

echo ============================================================
echo      YANTRA769 - SPU Synthesis (Yosys)
echo ============================================================

cd /d "%~dp0\.."

REM Check if yosys is installed
where yosys >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Yosys not found!
    echo Please download OSS CAD Suite:
    echo https://github.com/YosysHQ/oss-cad-suite-build/releases
    pause
    exit /b 1
)

echo [1/3] Creating synthesis script...

REM Create Yosys script
echo # Yantra769 Yosys Synthesis > synthesis\synth.ys
echo read_verilog rtl/vedic_multiplier.v >> synthesis\synth.ys
echo read_verilog rtl/yantra_alu.v >> synthesis\synth.ys
echo read_verilog rtl/navya_nyaya_logic.v >> synthesis\synth.ys
echo read_verilog rtl/sri_noc.v >> synthesis\synth.ys
echo read_verilog rtl/sri_yantra_cache.v >> synthesis\synth.ys
echo read_verilog rtl/phononic_thermal.v >> synthesis\synth.ys
echo read_verilog rtl/spu_top.v >> synthesis\synth.ys
echo hierarchy -check -top spu_top >> synthesis\synth.ys
echo synth -top spu_top >> synthesis\synth.ys
echo opt >> synthesis\synth.ys
echo stat >> synthesis\synth.ys
echo write_verilog synthesis/output/spu_netlist.v >> synthesis\synth.ys
echo write_json synthesis/output/spu_netlist.json >> synthesis\synth.ys

echo [2/3] Running Yosys synthesis...
mkdir synthesis\output 2>nul
yosys -s synthesis\synth.ys

echo [3/3] Synthesis complete!
echo.
echo Gate-level netlist: synthesis/output/spu_netlist.v
echo JSON output: synthesis/output/spu_netlist.json
echo.

pause
