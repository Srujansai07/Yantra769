@echo off
REM ============================================================================
REM YANTRA769 - ZERO BUDGET CHIP PIPELINE SETUP
REM ============================================================================
REM This script helps install FREE EDA tools needed for chip design
REM 
REM Tools covered:
REM   - Icarus Verilog (simulation)
REM   - Yosys (synthesis)
REM   - GTKWave (waveform viewer)
REM   - Verilator (fast simulation)
REM ============================================================================

echo ============================================================
echo      YANTRA769 - Sri-Processing Unit (SPU)
echo      Free EDA Tools Installation Guide
echo ============================================================
echo.

echo This script will guide you to install FREE tools for chip design.
echo.

echo === STEP 1: ICARUS VERILOG (Simulation) ===
echo Download from: https://bleyer.org/icarus/
echo Or use: winget install IcarusVerilog.IcarusVerilog
echo.

echo === STEP 2: YOSYS (Synthesis) ===  
echo Download from: https://github.com/YosysHQ/oss-cad-suite-build/releases
echo This includes Yosys, GTKWave, and more!
echo.

echo === STEP 3: After Installation ===
echo Run: simulate.bat to test your SPU design
echo Run: synthesize.bat to get gate counts
echo.

echo === ALTERNATIVE: Online Tools (No Install) ===
echo EDA Playground: https://www.edaplayground.com/
echo   - Free online Verilog simulation
echo   - Supports Icarus Verilog
echo   - No installation required!
echo.

pause
