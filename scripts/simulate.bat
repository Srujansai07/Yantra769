@echo off
REM ============================================================================
REM YANTRA769 - SIMULATE SPU
REM ============================================================================
REM Runs Icarus Verilog simulation of the Sri-Processing Unit
REM ============================================================================

echo ============================================================
echo      YANTRA769 - SPU Simulation
echo ============================================================

cd /d "%~dp0\.."

REM Check if iverilog is installed
where iverilog >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Icarus Verilog not found!
    echo Please install from: https://bleyer.org/icarus/
    echo Or download OSS CAD Suite: https://github.com/YosysHQ/oss-cad-suite-build/releases
    pause
    exit /b 1
)

echo [1/3] Compiling RTL files...
iverilog -o sim.out ^
    rtl/vedic_multiplier.v ^
    rtl/conventional_multiplier.v ^
    rtl/yantra_alu.v ^
    rtl/navya_nyaya_logic.v ^
    rtl/sri_noc.v ^
    rtl/sri_yantra_cache.v ^
    rtl/phononic_thermal.v ^
    rtl/spu_top.v ^
    testbench/tb_spu.v

if %ERRORLEVEL% NEQ 0 (
    echo Compilation failed! Check errors above.
    pause
    exit /b 1
)

echo [2/3] Running simulation...
vvp sim.out

echo [3/3] Simulation complete!
echo.
echo Waveform saved to: spu_tb.vcd
echo To view: gtkwave spu_tb.vcd
echo.

pause
