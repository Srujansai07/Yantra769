# SIVAA PDN Configuration for Sky130
# Radial Power Delivery Network inspired by Yantra

set ::env(PDN_CFG) $::env(DESIGN_DIR)/config/pdn.tcl

# Power nets
set ::env(VDD_NETS) {VPWR}
set ::env(GND_NETS) {VGND}

# PDN configuration 
set ::env(FP_PDN_CORE_RING) 1
set ::env(FP_PDN_CORE_RING_VWIDTH) 3.1
set ::env(FP_PDN_CORE_RING_HWIDTH) 3.1
set ::env(FP_PDN_CORE_RING_VOFFSET) 14
set ::env(FP_PDN_CORE_RING_HOFFSET) 14
set ::env(FP_PDN_CORE_RING_VSPACING) 1.7
set ::env(FP_PDN_CORE_RING_HSPACING) 1.7

# Straps - Yantra-inspired radial pattern simulation using grid
set ::env(FP_PDN_VWIDTH) 1.6
set ::env(FP_PDN_HWIDTH) 1.6
set ::env(FP_PDN_VSPACING) 15.5
set ::env(FP_PDN_HSPACING) 15.5
set ::env(FP_PDN_VPITCH) 50
set ::env(FP_PDN_HPITCH) 50

# Rails
set ::env(FP_PDN_RAIL_WIDTH) 0.48
set ::env(FP_PDN_RAIL_OFFSET) 0
set ::env(FP_PDN_HORIZONTAL_HALO) 10
set ::env(FP_PDN_VERTICAL_HALO) 10

# Multi-voltage domain support for Yantra layers
set ::env(FP_PDN_ENABLE_GLOBAL_CONNECTIONS) 1
set ::env(FP_PDN_ENABLE_MACROS_GRID) 1

# IR drop targets (tight for high-performance)
set ::env(FP_PDN_IRDROP) 25
