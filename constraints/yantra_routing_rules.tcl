# YANTRA GOLDEN-RATIO ROUTING CONSTRAINTS
# =========================================
# Design Rule Constraints for Golden-Ratio Signal Routing
# Based on Patent Claims 5-6: Non-90° angle routing
#
# ALLOWED ROUTING ANGLES (derived from golden ratio):
#   36°  = 360° / 10 (decagon angle)
#   51.5° = Sri Yantra / Great Pyramid angle
#   72°  = 2 × 36° (pentagon angle)
#   108° = 3 × 36° (internal pentagon)
#
# FORBIDDEN: 90° routing (creates signal reflection)

# ===========================================================================
# 1. ALLOWED ROUTING ANGLES
# ===========================================================================

set YANTRA_PRIMARY_ANGLES {0 36 72 108 144 180 216 252 288 324}
set YANTRA_SECONDARY_ANGLES {51.5 128.5 231.5 308.5}
set YANTRA_ALL_ANGLES [concat $YANTRA_PRIMARY_ANGLES $YANTRA_SECONDARY_ANGLES]

# Forbidden angles
set FORBIDDEN_ANGLES {90 270}

# ===========================================================================
# 2. DESIGN RULE CHECK (DRC) - No 90° Bends
# ===========================================================================

proc check_routing_angle {trace_angle} {
    global FORBIDDEN_ANGLES
    foreach forbidden $FORBIDDEN_ANGLES {
        if {abs($trace_angle - $forbidden) < 1.0} {
            return 0  ;# FAIL
        }
    }
    return 1  ;# PASS
}

# ===========================================================================
# 3. MARMA STHANA NODE CONSTRAINTS
# ===========================================================================

# Inner ring (IDs 1-6) - L1/L2 boundary
set MARMA_INNER_RADIUS 0.22
set MARMA_INNER_ANGLES {30 90 150 210 270 330}

# Middle ring (IDs 7-12) - Memory region
set MARMA_MIDDLE_RADIUS 0.53
set MARMA_MIDDLE_ANGLES {0 60 120 180 240 300}

# Outer ring (IDs 13-18) - I/O region
set MARMA_OUTER_RADIUS 0.72
set MARMA_OUTER_ANGLES {30 90 150 210 270 330}

# ===========================================================================
# 4. LAYER BOUNDARY CONSTRAINTS (Sri Yantra Radii)
# ===========================================================================

set YANTRA_RADII {
    bindu_l1    0.165
    l1_l2       0.265
    l2_l3       0.398
    l3_memctrl  0.463
    memctrl_hbm 0.603
    hbm_io      0.668
    io_pdn      0.769
    pdn_esd     0.887
}

# ===========================================================================
# 5. POWER CHANNEL CONSTRAINTS (8-Petal Lotus)
# ===========================================================================

set POWER_CHANNEL_ANGLES {0 45 90 135 180 225 270 315}
set POWER_CHANNEL_INNER_R 0.10
set POWER_CHANNEL_OUTER_R 0.60
set POWER_CHANNEL_WIDTH 300  ;# microns

# ===========================================================================
# 6. THERMAL CHANNEL CONSTRAINTS (16-Petal Lotus)
# ===========================================================================

set THERMAL_CHANNEL_ANGLES {0 22.5 45 67.5 90 112.5 135 157.5 180 202.5 225 247.5 270 292.5 315 337.5}
set THERMAL_CHANNEL_INNER_R 0.50
set THERMAL_CHANNEL_OUTER_R 0.95
set THERMAL_CHANNEL_WIDTH 200  ;# microns

# ===========================================================================
# 7. GOLDEN RATIO CONSTANTS
# ===========================================================================

set PHI 1.618033988749895
set SQRT_PHI 1.2720196495140689
set PYRAMID_ANGLE 51.5

# ===========================================================================
# 8. SIGNAL ROUTING RULES
# ===========================================================================

# Rule: All signal traces must use Yantra angles
# Rule: No 90° bends allowed
# Rule: Prefer 36° and 72° for high-speed signals
# Rule: Use 51.5° for crossing between layers

proc get_nearest_yantra_angle {target_angle} {
    global YANTRA_ALL_ANGLES
    set min_diff 360
    set best_angle 0
    foreach angle $YANTRA_ALL_ANGLES {
        set diff [expr {abs($target_angle - $angle)}]
        if {$diff < $min_diff} {
            set min_diff $diff
            set best_angle $angle
        }
    }
    return $best_angle
}

# ===========================================================================
# END OF CONSTRAINTS
# ===========================================================================

puts "Yantra Golden-Ratio Routing Constraints Loaded"
puts "Allowed angles: $YANTRA_ALL_ANGLES"
puts "Forbidden angles: $FORBIDDEN_ANGLES"
