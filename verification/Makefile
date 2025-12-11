# Project Vajra Makefile for cocotb Simulation
# =============================================
# 
# Usage:
#   make              - Run all tests
#   make sim          - Run simulation with Icarus Verilog
#   make clean        - Clean build files
#
# Requirements:
#   - Icarus Verilog (iverilog)
#   - cocotb: pip install cocotb
#   - cocotb-test: pip install cocotb-test

# Simulator
SIM ?= icarus
TOPLEVEL_LANG ?= verilog

# Source files
VERILOG_SOURCES = $(PWD)/../rtl/vajra_fractal_core.v

# Top-level module
TOPLEVEL = vajra_fractal_core

# Test module (Python)
MODULE = test_vajra_core

# Include cocotb's makefile
include $(shell cocotb-config --makefiles)/Makefile.sim

# Custom targets
.PHONY: all sim clean report

all: sim

sim:
	@echo "=== Running Vajra Fractal Core Simulation ==="
	$(MAKE) MODULE=$(MODULE) TOPLEVEL=$(TOPLEVEL)

report:
	@echo "=== Vajra Simulation Report ==="
	@cat results.xml 2>/dev/null || echo "No results found. Run 'make sim' first."

clean::
	@rm -rf __pycache__ results.xml sim_build *.vcd *.fst
	@echo "Cleaned build files"
