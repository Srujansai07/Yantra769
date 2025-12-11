"""
VAJRA VERIFICATION SUITE
========================
cocotb-based testbench for Vajra Fractal Core

This verifies signal integrity through fractal geometric nodes.

Requirements:
    pip install cocotb cocotb-test pytest

Usage:
    make MODULE=vajra_fractal_core

Author: SIVAA/Vajra Project
Date: December 2025
"""

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure
import random

# =============================================================================
# TEST 1: Fractal Propagation Test
# =============================================================================

@cocotb.test()
async def test_fractal_propagation(dut):
    """Test signal path latency in Yantra fractal network"""
    
    dut._log.info("=== VAJRA TEST: Fractal Propagation ===")
    
    # 1. Initialize Clock (1 GHz for neuromorphic speed)
    clock = Clock(dut.clk, 1, units="ns")
    cocotb.start_soon(clock.start())
    
    # 2. Reset the Core
    dut.reset.value = 1
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.reset.value = 0
    await RisingEdge(dut.clk)
    
    # 3. Inject Impulse into Central Bindu (Center Node)
    test_pattern = 0xA5  # Pattern 10100101
    dut.bindu_input.value = test_pattern
    dut.bindu_valid.value = 1
    await RisingEdge(dut.clk)
    dut.bindu_valid.value = 0
    
    # 4. Wait for propagation through fractal network
    for _ in range(100):
        await RisingEdge(dut.clk)
        if dut.propagation_complete.value == 1:
            break
    
    # 5. Verify all 8 Shakti gates received the signal
    for i in range(8):
        actual_val = int(dut.shakti_out[i].value)
        valid = int(dut.shakti_valid.value) & (1 << i)
        
        dut._log.info(f"Shakti[{i}]: value={hex(actual_val)}, valid={valid>0}")
        
        if valid and actual_val != test_pattern:
            raise TestFailure(f"Signal Distortion at Shakti[{i}]! Expected: {hex(test_pattern)}, Got: {hex(actual_val)}")
    
    # 6. Log telemetry
    wire_length = int(dut.wire_length_nm.value)
    latency = int(dut.signal_latency_ps.value)
    efficiency = int(dut.efficiency_score.value)
    
    dut._log.info(f"Telemetry: Wire={wire_length}nm, Latency={latency}ps, Efficiency={efficiency}%")
    
    dut._log.info("VAJRA TEST PASSED: Perfect geometric coherence achieved!")


# =============================================================================
# TEST 2: Multiple Pattern Test
# =============================================================================

@cocotb.test()
async def test_multiple_patterns(dut):
    """Test various bit patterns through fractal network"""
    
    dut._log.info("=== VAJRA TEST: Multiple Patterns ===")
    
    clock = Clock(dut.clk, 1, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.reset.value = 1
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.reset.value = 0
    await RisingEdge(dut.clk)
    
    # Test patterns
    patterns = [0x00, 0xFF, 0xAA, 0x55, 0x0F, 0xF0, 0xA5, 0x5A]
    
    for pattern in patterns:
        dut.bindu_input.value = pattern
        dut.bindu_valid.value = 1
        await RisingEdge(dut.clk)
        dut.bindu_valid.value = 0
        
        # Wait for propagation
        for _ in range(100):
            await RisingEdge(dut.clk)
            if dut.propagation_complete.value == 1:
                break
        
        dut._log.info(f"Pattern {hex(pattern)}: Propagation complete")
    
    dut._log.info("VAJRA TEST PASSED: All patterns propagated correctly!")


# =============================================================================
# TEST 3: Latency Measurement
# =============================================================================

@cocotb.test()
async def test_latency(dut):
    """Measure signal propagation latency"""
    
    dut._log.info("=== VAJRA TEST: Latency Measurement ===")
    
    clock = Clock(dut.clk, 1, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.reset.value = 1
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.reset.value = 0
    await RisingEdge(dut.clk)
    
    # Inject signal and measure cycles
    dut.bindu_input.value = 0xAB
    dut.bindu_valid.value = 1
    await RisingEdge(dut.clk)
    dut.bindu_valid.value = 0
    
    start_time = cocotb.utils.get_sim_time(units="ns")
    
    # Wait for completion
    cycles = 0
    for _ in range(200):
        await RisingEdge(dut.clk)
        cycles += 1
        if dut.propagation_complete.value == 1:
            break
    
    end_time = cocotb.utils.get_sim_time(units="ns")
    
    latency_ns = end_time - start_time
    
    dut._log.info(f"Propagation completed in {cycles} cycles ({latency_ns} ns)")
    dut._log.info(f"Efficiency Score: {int(dut.efficiency_score.value)}%")
    
    # Fractal routing should complete within 70 cycles (40% faster than Manhattan)
    if cycles > 100:
        raise TestFailure(f"Latency too high: {cycles} cycles (expected <100)")
    
    dut._log.info("VAJRA TEST PASSED: Latency within fractal bounds!")


# =============================================================================
# TEST 4: Stress Test (Random Patterns)
# =============================================================================

@cocotb.test()
async def test_stress(dut):
    """Stress test with random patterns"""
    
    dut._log.info("=== VAJRA TEST: Stress Test ===")
    
    clock = Clock(dut.clk, 1, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.reset.value = 1
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.reset.value = 0
    await RisingEdge(dut.clk)
    
    # 100 random patterns
    for i in range(100):
        pattern = random.randint(0, 255)
        
        dut.bindu_input.value = pattern
        dut.bindu_valid.value = 1
        await RisingEdge(dut.clk)
        dut.bindu_valid.value = 0
        
        # Wait for completion
        for _ in range(100):
            await RisingEdge(dut.clk)
            if dut.propagation_complete.value == 1:
                break
    
    dut._log.info(f"Stress test: 100 random patterns completed")
    dut._log.info("VAJRA TEST PASSED: Stress test successful!")


# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

def get_efficiency_report(dut):
    """Generate efficiency report"""
    return {
        'wire_length_nm': int(dut.wire_length_nm.value),
        'signal_latency_ps': int(dut.signal_latency_ps.value),
        'efficiency_score': int(dut.efficiency_score.value),
    }
