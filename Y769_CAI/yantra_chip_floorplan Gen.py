#!/usr/bin/env python3
"""
YANTRA CHIP FLOORPLAN GENERATOR
================================
Complete implementation for generating chip layout based on Sri Yantra geometry.
Outputs GDS-compatible coordinates for physical chip design.

Author: Division Zero Research
Based on: Sri Yantra mathematical analysis (Huet, 2002)
"""

import numpy as np
import json
from dataclasses import dataclass
from typing import List, Tuple, Dict

# =============================================================================
# CONSTANTS - SRI YANTRA MATHEMATICAL SPECIFICATIONS
# =============================================================================

# Golden Ratio
PHI = (1 + np.sqrt(5)) / 2  # 1.6180339887...
SQRT_PHI = np.sqrt(PHI)      # 1.2720196495...

# Sri Yantra Y-coordinates (normalized to unit circle)
# These are from peer-reviewed mathematical analysis
YANTRA_Y_COORDS = {
    'YL': 0.165,   # Lowest horizontal
    'YA': 0.265,   # Second layer
    'YJ': 0.398,   # Third layer
    'YP': 0.463,   # Fourth layer
    'YM': 0.603,   # Fifth layer (center region)
    'YF': 0.668,   # Sixth layer
    'YG': 0.769,   # Seventh layer
    'YV': 0.887,   # Eighth layer
}

# Sri Yantra X-coordinates
YANTRA_X_COORDS = {
    'XF': 0.126,   # Inner triangle extent
    'XA': 0.187,   # Secondary extent
}

# Great Pyramid angle (same as Sri Yantra largest triangles)
PYRAMID_ANGLE = 51.8  # degrees

# =============================================================================
# DATA STRUCTURES
# =============================================================================

@dataclass
class ChipLayer:
    """Represents a single layer in the Yantra chip architecture."""
    name: str
    inner_radius_mm: float
    outer_radius_mm: float
    function: str
    metal_layer: int
    power_budget_w: float

@dataclass
class MarmaSthana:
    """Critical routing intersection point (18 total in Sri Yantra)."""
    id: int
    x_mm: float
    y_mm: float
    connected_layers: List[str]
    routing_priority: int

@dataclass
class RadialChannel:
    """Thermal/power channel radiating from center."""
    angle_deg: float
    start_radius_mm: float
    end_radius_mm: float
    width_mm: float
    channel_type: str  # 'thermal', 'power', 'signal'

# =============================================================================
# YANTRA CHIP LAYOUT CLASS
# =============================================================================

class YantraChipLayout:
    """
    Complete chip floorplan generator based on Sri Yantra geometry.
    
    Generates:
    - Layer boundaries (concentric rings)
    - Marma Sthana routing nodes
    - Radial channels (thermal, power, signal)
    - GDS-compatible output coordinates
    """
    
    def __init__(self, die_size_mm: float = 20.0, process_node_nm: int = 7):
        """
        Initialize Yantra chip layout.
        
        Args:
            die_size_mm: Die size in millimeters (default 20mm = typical large chip)
            process_node_nm: Process technology node in nanometers
        """
        self.die_size = die_size_mm
        self.die_radius = die_size_mm / 2
        self.center = (die_size_mm / 2, die_size_mm / 2)
        self.process_node = process_node_nm
        
        # Generate all layout components
        self.layers = self._generate_layers()
        self.marma_sthanas = self._generate_marma_sthanas()
        self.radial_channels = self._generate_radial_channels()
        
    def _generate_layers(self) -> List[ChipLayer]:
        """Generate chip layers based on Sri Yantra radii."""
        
        layer_specs = [
            ('bindu_core',    0.000, 0.165, 'ALU/FPU Core',           1,  50),
            ('l1_cache',      0.165, 0.265, 'L1 Cache (32KB)',        2,  15),
            ('l2_cache',      0.265, 0.398, 'L2 Cache (256KB)',       3,  20),
            ('l3_cache',      0.398, 0.463, 'L3 Cache (shared)',      4,  25),
            ('memory_ctrl',   0.463, 0.603, 'Memory Controller',      5,  30),
            ('hbm_interface', 0.603, 0.668, 'HBM PHY Interface',      6,  40),
            ('io_ring',       0.668, 0.769, 'I/O Ring + SerDes',      7,  35),
            ('pdn_ring',      0.769, 0.887, 'Power Delivery Network', 8,  20),
            ('esd_boundary',  0.887, 1.000, 'ESD + Seal Ring',        9,   5),
        ]
        
        layers = []
        for name, r_inner, r_outer, func, metal, power in layer_specs:
            layers.append(ChipLayer(
                name=name,
                inner_radius_mm=r_inner * self.die_radius,
                outer_radius_mm=r_outer * self.die_radius,
                function=func,
                metal_layer=metal,
                power_budget_w=power
            ))
        
        return layers
    
    def _generate_marma_sthanas(self) -> List[MarmaSthana]:
        """
        Generate 18 Marma Sthana routing nodes.
        
        In Sri Yantra, Marma Sthanas are points where exactly 3 lines intersect.
        In chip design, these become critical routing junctions.
        """
        marma_points = []
        
        # Inner ring (6 points) - L1/L2 cache boundary
        for i in range(6):
            angle = i * 60 + 30  # Offset by 30 degrees
            r = 0.22 * self.die_radius  # Between YL and YA
            x = self.center[0] + r * np.cos(np.radians(angle))
            y = self.center[1] + r * np.sin(np.radians(angle))
            marma_points.append(MarmaSthana(
                id=i+1,
                x_mm=x,
                y_mm=y,
                connected_layers=['l1_cache', 'l2_cache'],
                routing_priority=1
            ))
        
        # Middle ring (6 points) - Memory controller region
        for i in range(6):
            angle = i * 60  # No offset
            r = 0.53 * self.die_radius  # YP to YM region
            x = self.center[0] + r * np.cos(np.radians(angle))
            y = self.center[1] + r * np.sin(np.radians(angle))
            marma_points.append(MarmaSthana(
                id=i+7,
                x_mm=x,
                y_mm=y,
                connected_layers=['l3_cache', 'memory_ctrl', 'hbm_interface'],
                routing_priority=2
            ))
        
        # Outer ring (6 points) - I/O region
        for i in range(6):
            angle = i * 60 + 30  # Offset by 30 degrees
            r = 0.72 * self.die_radius  # YG region
            x = self.center[0] + r * np.cos(np.radians(angle))
            y = self.center[1] + r * np.sin(np.radians(angle))
            marma_points.append(MarmaSthana(
                id=i+13,
                x_mm=x,
                y_mm=y,
                connected_layers=['io_ring', 'pdn_ring'],
                routing_priority=3
            ))
        
        return marma_points
    
    def _generate_radial_channels(self) -> List[RadialChannel]:
        """
        Generate radial channels based on lotus petal pattern.
        
        Sri Yantra has:
        - 8-petal inner lotus (power delivery)
        - 16-petal outer lotus (thermal channels)
        """
        channels = []
        
        # 8 primary power delivery channels (inner lotus)
        for i in range(8):
            angle = i * 45
            channels.append(RadialChannel(
                angle_deg=angle,
                start_radius_mm=0.1 * self.die_radius,
                end_radius_mm=0.6 * self.die_radius,
                width_mm=0.3,
                channel_type='power'
            ))
        
        # 16 thermal dissipation channels (outer lotus)
        for i in range(16):
            angle = i * 22.5
            channels.append(RadialChannel(
                angle_deg=angle,
                start_radius_mm=0.5 * self.die_radius,
                end_radius_mm=0.95 * self.die_radius,
                width_mm=0.2,
                channel_type='thermal'
            ))
        
        # 8 high-speed signal channels (alternating with power)
        for i in range(8):
            angle = i * 45 + 22.5  # Offset from power channels
            channels.append(RadialChannel(
                angle_deg=angle,
                start_radius_mm=0.2 * self.die_radius,
                end_radius_mm=0.8 * self.die_radius,
                width_mm=0.15,
                channel_type='signal'
            ))
        
        return channels
    
    def get_layer_area_mm2(self, layer_name: str) -> float:
        """Calculate area of a specific layer in mm²."""
        for layer in self.layers:
            if layer.name == layer_name:
                return np.pi * (layer.outer_radius_mm**2 - layer.inner_radius_mm**2)
        return 0.0
    
    def get_total_core_area_mm2(self) -> float:
        """Calculate total active area (excluding ESD boundary)."""
        inner_layers = [l for l in self.layers if l.name != 'esd_boundary']
        if inner_layers:
            max_radius = max(l.outer_radius_mm for l in inner_layers)
            return np.pi * max_radius**2
        return 0.0
    
    def export_gds_coordinates(self) -> Dict:
        """
        Export all coordinates in GDS-compatible format.
        
        Returns dict with:
        - layers: List of layer boundaries (circles)
        - marma_sthanas: List of critical routing points
        - channels: List of radial channel paths
        """
        
        gds_data = {
            'die_info': {
                'size_mm': self.die_size,
                'size_um': self.die_size * 1000,
                'center_mm': self.center,
                'center_um': (self.center[0] * 1000, self.center[1] * 1000),
                'process_node_nm': self.process_node,
            },
            'layers': [],
            'marma_sthanas': [],
            'channels': [],
            'golden_ratio_verification': {
                'phi': PHI,
                'layer_ratios': {}
            }
        }
        
        # Export layers
        for layer in self.layers:
            gds_data['layers'].append({
                'name': layer.name,
                'inner_radius_um': layer.inner_radius_mm * 1000,
                'outer_radius_um': layer.outer_radius_mm * 1000,
                'center_um': (self.center[0] * 1000, self.center[1] * 1000),
                'area_mm2': self.get_layer_area_mm2(layer.name),
                'function': layer.function,
                'metal_layer': layer.metal_layer,
                'power_budget_w': layer.power_budget_w
            })
        
        # Export Marma Sthanas
        for ms in self.marma_sthanas:
            gds_data['marma_sthanas'].append({
                'id': ms.id,
                'x_um': ms.x_mm * 1000,
                'y_um': ms.y_mm * 1000,
                'connected_layers': ms.connected_layers,
                'routing_priority': ms.routing_priority
            })
        
        # Export channels
        for ch in self.radial_channels:
            start_x = self.center[0] + ch.start_radius_mm * np.cos(np.radians(ch.angle_deg))
            start_y = self.center[1] + ch.start_radius_mm * np.sin(np.radians(ch.angle_deg))
            end_x = self.center[0] + ch.end_radius_mm * np.cos(np.radians(ch.angle_deg))
            end_y = self.center[1] + ch.end_radius_mm * np.sin(np.radians(ch.angle_deg))
            
            gds_data['channels'].append({
                'type': ch.channel_type,
                'angle_deg': ch.angle_deg,
                'start_um': (start_x * 1000, start_y * 1000),
                'end_um': (end_x * 1000, end_y * 1000),
                'width_um': ch.width_mm * 1000
            })
        
        # Verify golden ratio relationships
        radii = [l.outer_radius_mm for l in self.layers[:-1]]  # Exclude boundary
        for i in range(len(radii) - 1):
            ratio = radii[i+1] / radii[i] if radii[i] > 0 else 0
            gds_data['golden_ratio_verification']['layer_ratios'][
                f'{self.layers[i].name}_to_{self.layers[i+1].name}'
            ] = round(ratio, 4)
        
        return gds_data
    
    def generate_def_file(self) -> str:
        """Generate DEF (Design Exchange Format) compatible output."""
        
        def_content = f"""# YANTRA CHIP FLOORPLAN - DEF FORMAT
# Generated by Division Zero Yantra Layout Generator
# Die Size: {self.die_size}mm x {self.die_size}mm
# Process: {self.process_node}nm

VERSION 5.8 ;
DIVIDERCHAR "/" ;
BUSBITCHARS "[]" ;
DESIGN yantra_chip ;
UNITS DISTANCE MICRONS 1000 ;

DIEAREA ( 0 0 ) ( {int(self.die_size * 1000000)} {int(self.die_size * 1000000)} ) ;

# LAYER DEFINITIONS (Concentric Rings)
"""
        
        for layer in self.layers:
            def_content += f"""
# {layer.name.upper()} - {layer.function}
# Inner Radius: {layer.inner_radius_mm:.3f}mm, Outer Radius: {layer.outer_radius_mm:.3f}mm
# Metal Layer: M{layer.metal_layer}, Power Budget: {layer.power_budget_w}W
"""
        
        def_content += f"""
# MARMA STHANA ROUTING NODES (18 Critical Intersections)
"""
        
        for ms in self.marma_sthanas:
            def_content += f"""
COMPONENT marma_{ms.id:02d} PLACED ( {int(ms.x_mm * 1000000)} {int(ms.y_mm * 1000000)} ) N ;
  # Connected to: {', '.join(ms.connected_layers)}
  # Priority: {ms.routing_priority}
"""
        
        def_content += """
END DESIGN
"""
        
        return def_content
    
    def print_summary(self):
        """Print human-readable layout summary."""
        
        print("=" * 70)
        print("YANTRA CHIP LAYOUT SUMMARY")
        print("=" * 70)
        print(f"\nDie Size: {self.die_size}mm × {self.die_size}mm")
        print(f"Total Area: {self.die_size**2:.1f}mm²")
        print(f"Active Area: {self.get_total_core_area_mm2():.1f}mm²")
        print(f"Process Node: {self.process_node}nm")
        
        print("\n" + "-" * 70)
        print("LAYER BREAKDOWN (Based on Sri Yantra Radii)")
        print("-" * 70)
        print(f"{'Layer':<18} {'Inner(mm)':<10} {'Outer(mm)':<10} {'Area(mm²)':<10} {'Function':<20}")
        print("-" * 70)
        
        total_power = 0
        for layer in self.layers:
            area = self.get_layer_area_mm2(layer.name)
            print(f"{layer.name:<18} {layer.inner_radius_mm:<10.3f} {layer.outer_radius_mm:<10.3f} {area:<10.2f} {layer.function:<20}")
            total_power += layer.power_budget_w
        
        print("-" * 70)
        print(f"Total Power Budget: {total_power}W")
        
        print("\n" + "-" * 70)
        print("MARMA STHANA ROUTING NODES")
        print("-" * 70)
        print(f"Total Critical Nodes: {len(self.marma_sthanas)}")
        print(f"  Inner Ring (L1/L2): 6 nodes")
        print(f"  Middle Ring (Memory): 6 nodes")
        print(f"  Outer Ring (I/O): 6 nodes")
        
        print("\n" + "-" * 70)
        print("RADIAL CHANNEL SUMMARY")
        print("-" * 70)
        power_ch = len([c for c in self.radial_channels if c.channel_type == 'power'])
        thermal_ch = len([c for c in self.radial_channels if c.channel_type == 'thermal'])
        signal_ch = len([c for c in self.radial_channels if c.channel_type == 'signal'])
        print(f"  Power Delivery Channels: {power_ch} (8-petal inner lotus)")
        print(f"  Thermal Channels: {thermal_ch} (16-petal outer lotus)")
        print(f"  Signal Channels: {signal_ch}")
        
        print("\n" + "=" * 70)


# =============================================================================
# MAIN EXECUTION
# =============================================================================

def main():
    """Generate complete Yantra chip layout and export files."""
    
    print("\n" + "=" * 70)
    print("YANTRA CHIP FLOORPLAN GENERATOR")
    print("Division Zero Research Initiative")
    print("=" * 70)
    
    # Create layout for a 20mm die at 7nm process
    layout = YantraChipLayout(die_size_mm=20.0, process_node_nm=7)
    
    # Print summary
    layout.print_summary()
    
    # Export GDS coordinates
    gds_data = layout.export_gds_coordinates()
    
    # Save to JSON
    with open('yantra_chip_coordinates.json', 'w') as f:
        json.dump(gds_data, f, indent=2)
    print(f"\nGDS coordinates saved to: yantra_chip_coordinates.json")
    
    # Generate DEF file
    def_content = layout.generate_def_file()
    with open('yantra_chip.def', 'w') as f:
        f.write(def_content)
    print(f"DEF file saved to: yantra_chip.def")
    
    # Print golden ratio verification
    print("\n" + "-" * 70)
    print("GOLDEN RATIO VERIFICATION")
    print("-" * 70)
    print(f"φ (Golden Ratio) = {PHI:.6f}")
    print(f"√φ = {SQRT_PHI:.6f}")
    print("\nLayer Radius Ratios:")
    for ratio_name, ratio_value in gds_data['golden_ratio_verification']['layer_ratios'].items():
        phi_match = "≈ φ" if 1.5 < ratio_value < 1.7 else "≈ √φ" if 1.2 < ratio_value < 1.35 else ""
        print(f"  {ratio_name}: {ratio_value} {phi_match}")
    
    print("\n" + "=" * 70)
    print("GENERATION COMPLETE")
    print("=" * 70)
    
    return layout, gds_data


if __name__ == "__main__":
    layout, gds_data = main()
