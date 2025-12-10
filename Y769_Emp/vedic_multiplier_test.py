#!/usr/bin/env python3
"""
VEDIC MULTIPLIER VALIDATION SCRIPT
===================================
Tests the Urdhva Tiryagbhyam (vertically and crosswise) algorithm
for 8x8 bit multiplication as used in SIVAA architecture.
"""

def vedic_2x2(a, b):
    """2-bit Vedic multiplier"""
    pp0 = (a & 1) * (b & 1)
    pp1 = ((a >> 1) & 1) * (b & 1)
    pp2 = (a & 1) * ((b >> 1) & 1)
    pp3 = ((a >> 1) & 1) * ((b >> 1) & 1)
    return pp0 + ((pp1 + pp2) << 1) + (pp3 << 2)

def vedic_4x4(a, b):
    """4-bit Vedic multiplier using 2x2 blocks"""
    q0 = vedic_2x2(a & 0x3, b & 0x3)
    q1 = vedic_2x2((a >> 2) & 0x3, b & 0x3)
    q2 = vedic_2x2(a & 0x3, (b >> 2) & 0x3)
    q3 = vedic_2x2((a >> 2) & 0x3, (b >> 2) & 0x3)
    return q0 + (q1 << 2) + (q2 << 2) + (q3 << 4)

def vedic_8x8(a, b):
    """8-bit Vedic multiplier using 4x4 blocks"""
    q0 = vedic_4x4(a & 0xF, b & 0xF)
    q1 = vedic_4x4((a >> 4) & 0xF, b & 0xF)
    q2 = vedic_4x4(a & 0xF, (b >> 4) & 0xF)
    q3 = vedic_4x4((a >> 4) & 0xF, (b >> 4) & 0xF)
    return q0 + (q1 << 4) + (q2 << 4) + (q3 << 8)

def run_tests():
    """Run comprehensive test suite"""
    tests = [
        (0, 0), (1, 1), (2, 3), (15, 15), (127, 127), (255, 255),
        (123, 45), (200, 150), (77, 88), (255, 1), (128, 128)
    ]
    
    passed = 0
    for a, b in tests:
        result = vedic_8x8(a, b)
        expected = a * b
        if result == expected:
            passed += 1
            print(f"  PASS: {a} x {b} = {result}")
        else:
            print(f"  FAIL: {a} x {b} = {result} (expected {expected})")
    
    print(f"\nResult: {passed}/{len(tests)} tests passed")
    return passed == len(tests)

if __name__ == "__main__":
    print("="*60)
    print("VEDIC MULTIPLIER (Urdhva Tiryagbhyam) VALIDATION")
    print("="*60)
    success = run_tests()
    print("="*60)
    print("VERDICT:", "ALL TESTS PASSED" if success else "SOME TESTS FAILED")
    print("="*60)
