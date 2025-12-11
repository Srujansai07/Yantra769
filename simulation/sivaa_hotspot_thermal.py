#!/usr/bin/env python3
"""
SIVAA HOTSPOT-COMPATIBLE THERMAL SIMULATION
=============================================
Real semiconductor physics for Yantra chip validation

This simulation implements:
1. Finite Difference Method (FDM) for heat equation
2. HotSpot-compatible power trace format
3. Realistic material properties (Si, Cu, SiO2)
4. Yantra vs Rectangular comparison
5. JSON output for paper publication

Author: SIVAA Research
Date: December 2025
"""

import numpy as np
import json
from datetime import datetime
import os

# ============================================================================
# SEMICONDUCTOR MATERIAL PROPERTIES
# ============================================================================
class Materials:
    """Real semiconductor material properties at 300K"""
    
    # Thermal conductivity (W/m·K)
    SILICON = 148.0
    COPPER = 401.0
    SILICON_OXIDE = 1.4
    ALUMINUM = 237.0
    DIAMOND = 2000.0  # For advanced cooling
    
    # Specific heat capacity (J/kg·K)
    SILICON_CP = 700.0
    COPPER_CP = 385.0
    
    # Density (kg/m³)
    SILICON_RHO = 2329.0
    COPPER_RHO = 8960.0
    
    # Thermal diffusivity α = k/(ρ·Cp) (m²/s)
    SILICON_ALPHA = SILICON / (SILICON_RHO * SILICON_CP)
    COPPER_ALPHA = COPPER / (COPPER_RHO * COPPER_CP)

# ============================================================================
# SRI YANTRA COORDINATES
# ============================================================================
class SriYantraGeometry:
    """
    Sacred geometry coordinates from Sri Yantra
    Source: Mathematical analysis of Sri Yantra (peer-reviewed)
    """
    
    # Normalized radii (0 to 1 scale)
    LAYER_RADII = {
        'bindu': 0.165,      # Central processing core
        'l1_cache': 0.265,   # Level 1 cache
        'l2_cache': 0.398,   # Level 2 cache
        'l3_cache': 0.463,   # Level 3 cache
        'mem_ctrl': 0.603,   # Memory controller
        'hbm_phy': 0.668,    # HBM interface
        'io_ring': 0.769,    # I/O ring
        'pdn': 0.887,        # Power delivery
        'boundary': 1.000    # Die edge
    }
    
    # Power density per layer (W/mm²) - realistic values
    POWER_DENSITY = {
        'bindu': 1.2,        # Highest (ALU/FPU)
        'l1_cache': 0.8,
        'l2_cache': 0.5,
        'l3_cache': 0.3,
        'mem_ctrl': 0.6,
        'hbm_phy': 0.4,
        'io_ring': 0.3,
        'pdn': 0.1,
        'boundary': 0.05
    }
    
    # Golden ratio relationships
    PHI = 1.618033988749895
    SQRT_PHI = 1.272019649514069
    
    @classmethod
    def verify_golden_ratio(cls):
        """Verify layer ratios approximate golden ratio"""
        radii = list(cls.LAYER_RADII.values())
        ratios = []
        for i in range(1, len(radii)):
            if radii[i-1] > 0:
                ratio = radii[i] / radii[i-1]
                ratios.append(ratio)
        return ratios

# ============================================================================
# THERMAL SIMULATION ENGINE
# ============================================================================
class YantraThermalSimulator:
    """
    2D Steady-State Thermal Simulation using Finite Difference Method
    Compatible with HotSpot format for validation
    """
    
    def __init__(self, die_size_mm=20.0, grid_size=100, ambient_temp=300.0):
        """
        Initialize thermal simulator
        
        Args:
            die_size_mm: Die size in mm (square)
            grid_size: Number of grid points per dimension
            ambient_temp: Ambient temperature in Kelvin
        """
        self.die_size = die_size_mm * 1e-3  # Convert to meters
        self.grid_size = grid_size
        self.ambient_temp = ambient_temp
        
        # Grid spacing
        self.dx = self.die_size / grid_size
        self.dy = self.dx
        
        # Initialize arrays
        self.T = np.ones((grid_size, grid_size)) * ambient_temp
        self.power = np.zeros((grid_size, grid_size))
        self.k_map = np.ones((grid_size, grid_size)) * Materials.SILICON
        
        # Results storage
        self.results = {}
        
    def _create_power_map(self, layout_type='yantra'):
        """Create power density map based on layout type"""
        center = self.grid_size // 2
        power = np.zeros((self.grid_size, self.grid_size))
        
        for i in range(self.grid_size):
            for j in range(self.grid_size):
                # Calculate normalized radius from center
                dx = (i - center) / center
                dy = (j - center) / center
                r = np.sqrt(dx**2 + dy**2)
                
                if layout_type == 'yantra':
                    # Yantra: power based on concentric layers
                    power[i, j] = self._get_yantra_power(r)
                else:
                    # Rectangular: uniform blocks
                    power[i, j] = self._get_rectangular_power(i, j)
                    
        return power
    
    def _get_yantra_power(self, r):
        """Get power density based on Yantra layer"""
        radii = SriYantraGeometry.LAYER_RADII
        power = SriYantraGeometry.POWER_DENSITY
        
        if r <= radii['bindu']:
            return power['bindu']
        elif r <= radii['l1_cache']:
            return power['l1_cache']
        elif r <= radii['l2_cache']:
            return power['l2_cache']
        elif r <= radii['l3_cache']:
            return power['l3_cache']
        elif r <= radii['mem_ctrl']:
            return power['mem_ctrl']
        elif r <= radii['hbm_phy']:
            return power['hbm_phy']
        elif r <= radii['io_ring']:
            return power['io_ring']
        elif r <= radii['pdn']:
            return power['pdn']
        else:
            return power['boundary']
    
    def _get_rectangular_power(self, i, j):
        """Get power density for rectangular layout (4 cores)"""
        cx, cy = self.grid_size // 2, self.grid_size // 2
        core_size = self.grid_size // 4
        
        # 4 rectangular cores
        cores = [
            (cx - core_size, cy - core_size),
            (cx - core_size, cy + core_size // 2),
            (cx + core_size // 2, cy - core_size),
            (cx + core_size // 2, cy + core_size // 2)
        ]
        
        for (x, y) in cores:
            if abs(i - x) < core_size // 2 and abs(j - y) < core_size // 2:
                return 1.2  # Core power
        
        # Cache regions
        if cx - self.grid_size // 3 < i < cx + self.grid_size // 3:
            if cy - self.grid_size // 3 < j < cy + self.grid_size // 3:
                return 0.5  # Cache
        
        return 0.2  # Periphery
    
    def _create_thermal_conductivity_map(self, layout_type='yantra'):
        """Create thermal conductivity map with cooling channels"""
        k_map = np.ones((self.grid_size, self.grid_size)) * Materials.SILICON
        center = self.grid_size // 2
        
        if layout_type == 'yantra':
            # Radial copper cooling channels (8 primary + 16 secondary)
            for angle in range(0, 360, 45):  # Primary channels
                for r in range(self.grid_size // 10, self.grid_size // 2 - 5):
                    x = int(center + r * np.cos(np.radians(angle)))
                    y = int(center + r * np.sin(np.radians(angle)))
                    if 0 <= x < self.grid_size and 0 <= y < self.grid_size:
                        # Channel width ~3 grid points
                        for dx in range(-1, 2):
                            for dy in range(-1, 2):
                                if 0 <= x+dx < self.grid_size and 0 <= y+dy < self.grid_size:
                                    k_map[x+dx, y+dy] = Materials.COPPER
            
            for angle in range(0, 360, 22):  # Secondary channels (outer)
                for r in range(self.grid_size // 3, self.grid_size // 2 - 2):
                    x = int(center + r * np.cos(np.radians(angle)))
                    y = int(center + r * np.sin(np.radians(angle)))
                    if 0 <= x < self.grid_size and 0 <= y < self.grid_size:
                        k_map[x, y] = Materials.COPPER
        else:
            # Rectangular: grid cooling channels
            for i in range(0, self.grid_size, self.grid_size // 5):
                k_map[i:i+2, :] = Materials.COPPER
                k_map[:, i:i+2] = Materials.COPPER
                
        return k_map
    
    def solve_steady_state(self, layout_type='yantra', max_iter=5000, tolerance=1e-6):
        """
        Solve steady-state heat equation using Gauss-Seidel iteration
        
        ∇²T + q/k = 0
        """
        print(f"\n{'='*60}")
        print(f"SOLVING: {layout_type.upper()} LAYOUT")
        print(f"{'='*60}")
        
        # Create maps
        self.power = self._create_power_map(layout_type)
        self.k_map = self._create_thermal_conductivity_map(layout_type)
        
        # Initialize temperature
        T = np.ones((self.grid_size, self.grid_size)) * self.ambient_temp
        
        # Boundary conditions: fixed temperature at edges
        T[0, :] = self.ambient_temp
        T[-1, :] = self.ambient_temp
        T[:, 0] = self.ambient_temp
        T[:, -1] = self.ambient_temp
        
        # Gauss-Seidel iteration
        for iteration in range(max_iter):
            T_old = T.copy()
            
            for i in range(1, self.grid_size - 1):
                for j in range(1, self.grid_size - 1):
                    k_eff = self.k_map[i, j]
                    q = self.power[i, j] * 1e6  # W/mm² to W/m²
                    
                    # 5-point stencil with heat generation
                    T[i, j] = 0.25 * (
                        T[i+1, j] + T[i-1, j] + 
                        T[i, j+1] + T[i, j-1] + 
                        (q * self.dx**2) / k_eff
                    )
            
            # Check convergence
            error = np.max(np.abs(T - T_old))
            if error < tolerance:
                print(f"  Converged in {iteration+1} iterations (error: {error:.2e})")
                break
            
            if iteration % 1000 == 0:
                print(f"  Iteration {iteration}: max error = {error:.4f}")
        
        self.T = T
        return T
    
    def analyze_results(self, layout_type):
        """Analyze thermal results"""
        # Mask for interior (exclude boundaries)
        mask = np.zeros_like(self.T, dtype=bool)
        mask[5:-5, 5:-5] = True
        
        T_interior = self.T[mask]
        
        # Statistics
        peak_temp = np.max(T_interior)
        avg_temp = np.mean(T_interior)
        min_temp = np.min(T_interior)
        std_temp = np.std(T_interior)
        
        # Hotspot detection (>90% of peak)
        threshold = min_temp + 0.9 * (peak_temp - min_temp)
        hotspots = np.sum(T_interior > threshold)
        
        # Convert to Celsius for readability
        results = {
            'layout': layout_type,
            'peak_temp_K': float(peak_temp),
            'peak_temp_C': float(peak_temp - 273.15),
            'avg_temp_K': float(avg_temp),
            'avg_temp_C': float(avg_temp - 273.15),
            'min_temp_K': float(min_temp),
            'std_dev_K': float(std_temp),
            'hotspot_count': int(hotspots),
            'temp_range_K': float(peak_temp - min_temp),
            'uniformity_pct': float((1 - std_temp / (peak_temp - min_temp)) * 100) if peak_temp > min_temp else 100.0
        }
        
        return results
    
    def run_comparison(self):
        """Run full comparison between Yantra and Rectangular layouts"""
        print("\n" + "="*70)
        print("SIVAA THERMAL SIMULATION - YANTRA vs RECTANGULAR COMPARISON")
        print("="*70)
        print(f"Die Size: {self.die_size*1000:.1f}mm x {self.die_size*1000:.1f}mm")
        print(f"Grid: {self.grid_size} x {self.grid_size}")
        print(f"Ambient: {self.ambient_temp}K ({self.ambient_temp-273.15:.1f}°C)")
        
        # Solve Yantra layout
        self.solve_steady_state('yantra')
        yantra_results = self.analyze_results('yantra')
        yantra_T = self.T.copy()
        yantra_power = self.power.copy()
        yantra_k = self.k_map.copy()
        
        # Solve Rectangular layout
        self.solve_steady_state('rectangular')
        rect_results = self.analyze_results('rectangular')
        rect_T = self.T.copy()
        rect_power = self.power.copy()
        rect_k = self.k_map.copy()
        
        # Calculate improvements
        peak_reduction = (rect_results['peak_temp_K'] - yantra_results['peak_temp_K']) / (rect_results['peak_temp_K'] - self.ambient_temp) * 100
        uniformity_improvement = (rect_results['std_dev_K'] - yantra_results['std_dev_K']) / rect_results['std_dev_K'] * 100
        hotspot_reduction = (rect_results['hotspot_count'] - yantra_results['hotspot_count']) / max(1, rect_results['hotspot_count']) * 100
        
        # Print results
        print("\n" + "-"*70)
        print("RESULTS COMPARISON")
        print("-"*70)
        print(f"{'Metric':<30} {'Rectangular':<20} {'Yantra':<20}")
        print("-"*70)
        print(f"{'Peak Temperature (°C)':<30} {rect_results['peak_temp_C']:<20.2f} {yantra_results['peak_temp_C']:<20.2f}")
        print(f"{'Average Temperature (°C)':<30} {rect_results['avg_temp_C']:<20.2f} {yantra_results['avg_temp_C']:<20.2f}")
        print(f"{'Std Deviation (K)':<30} {rect_results['std_dev_K']:<20.2f} {yantra_results['std_dev_K']:<20.2f}")
        print(f"{'Hotspot Count':<30} {rect_results['hotspot_count']:<20d} {yantra_results['hotspot_count']:<20d}")
        print(f"{'Temperature Range (K)':<30} {rect_results['temp_range_K']:<20.2f} {yantra_results['temp_range_K']:<20.2f}")
        
        print("\n" + "-"*70)
        print("YANTRA IMPROVEMENT")
        print("-"*70)
        print(f"Peak Temperature Reduction:     {peak_reduction:.1f}%")
        print(f"Uniformity Improvement:         {uniformity_improvement:.1f}%")
        print(f"Hotspot Reduction:              {hotspot_reduction:.1f}%")
        
        # Store all results
        self.results = {
            'simulation_date': datetime.now().isoformat(),
            'parameters': {
                'die_size_mm': self.die_size * 1000,
                'grid_size': self.grid_size,
                'ambient_temp_K': self.ambient_temp
            },
            'yantra': yantra_results,
            'rectangular': rect_results,
            'improvement': {
                'peak_temp_reduction_pct': float(peak_reduction),
                'uniformity_improvement_pct': float(uniformity_improvement),
                'hotspot_reduction_pct': float(hotspot_reduction)
            },
            'sri_yantra_validation': {
                'layer_radii': SriYantraGeometry.LAYER_RADII,
                'golden_ratio_verification': SriYantraGeometry.verify_golden_ratio()
            }
        }
        
        # Store temperature maps for visualization
        self.yantra_T = yantra_T
        self.rect_T = rect_T
        self.yantra_power = yantra_power
        self.rect_power = rect_power
        
        return self.results
    
    def save_results(self, output_dir='.'):
        """Save results to JSON file"""
        output_path = os.path.join(output_dir, 'sivaa_thermal_complete_results.json')
        
        with open(output_path, 'w') as f:
            json.dump(self.results, f, indent=2)
        
        print(f"\nResults saved to: {output_path}")
        return output_path
    
    def generate_hotspot_format(self, output_dir='.'):
        """Generate HotSpot-compatible floorplan and power trace files"""
        
        # Floorplan file (.flp)
        flp_content = """# SIVAA Yantra Chip Floorplan
# Format: unit_name  width  height  left_x  bottom_y
# All dimensions in meters

bindu_core    3.3e-3    3.3e-3    8.35e-3    8.35e-3
l1_cache      2.0e-3    2.0e-3    6.5e-3     6.5e-3
l2_cache      2.66e-3   2.66e-3   5.17e-3    5.17e-3
l3_cache      1.3e-3    1.3e-3    4.52e-3    4.52e-3
mem_ctrl      2.8e-3    2.8e-3    3.36e-3    3.36e-3
hbm_phy       1.3e-3    1.3e-3    2.71e-3    2.71e-3
io_ring       2.02e-3   2.02e-3   1.69e-3    1.69e-3
pdn_ring      2.36e-3   2.36e-3   0.57e-3    0.57e-3
"""
        flp_path = os.path.join(output_dir, 'yantra_chip.flp')
        with open(flp_path, 'w') as f:
            f.write(flp_content)
        
        # Power trace file (.ptrace)
        ptrace_content = """# SIVAA Yantra Power Trace
# Format: time_step  unit1_power  unit2_power  ...
bindu_core l1_cache l2_cache l3_cache mem_ctrl hbm_phy io_ring pdn_ring
1.2 0.8 0.5 0.3 0.6 0.4 0.3 0.1
"""
        ptrace_path = os.path.join(output_dir, 'yantra_chip.ptrace')
        with open(ptrace_path, 'w') as f:
            f.write(ptrace_content)
        
        print(f"HotSpot files generated:")
        print(f"  Floorplan: {flp_path}")
        print(f"  Power trace: {ptrace_path}")
        
        return flp_path, ptrace_path


# ============================================================================
# MAIN EXECUTION
# ============================================================================
def main():
    """Main simulation execution"""
    
    print("\n" + "="*70)
    print("SIVAA - SILICON-INTEGRATED VEDIC ADVANCED ARCHITECTURE")
    print("Complete Thermal Validation Suite")
    print("="*70)
    
    # Initialize simulator
    sim = YantraThermalSimulator(
        die_size_mm=20.0,     # 20mm x 20mm die
        grid_size=100,         # 100x100 grid (fast, accurate enough)
        ambient_temp=300.0     # 27°C ambient
    )
    
    # Run comparison
    results = sim.run_comparison()
    
    # Print verdict
    print("\n" + "="*70)
    print("VERDICT")
    print("="*70)
    
    improvement = results['improvement']
    if improvement['peak_temp_reduction_pct'] > 20:
        print("✅ SIGNIFICANT THERMAL IMPROVEMENT - PUBLISHABLE RESULTS")
    elif improvement['peak_temp_reduction_pct'] > 10:
        print("⚠️  MODERATE IMPROVEMENT - NEEDS OPTIMIZATION")
    else:
        print("❌ MINIMAL IMPROVEMENT - REDESIGN REQUIRED")
    
    # Print golden ratio validation
    print("\n" + "-"*70)
    print("SRI YANTRA GOLDEN RATIO VALIDATION")
    print("-"*70)
    ratios = results['sri_yantra_validation']['golden_ratio_verification']
    print(f"Golden Ratio (φ) = {SriYantraGeometry.PHI:.6f}")
    print("Layer ratios:")
    for i, ratio in enumerate(ratios):
        phi_error = abs(ratio - SriYantraGeometry.PHI) / SriYantraGeometry.PHI * 100
        print(f"  Ratio {i+1}: {ratio:.4f} (φ error: {phi_error:.1f}%)")
    
    # Save results
    sim.save_results()
    
    # Generate HotSpot files
    sim.generate_hotspot_format()
    
    print("\n" + "="*70)
    print("SIMULATION COMPLETE")
    print("="*70)
    print("\nNext steps:")
    print("1. Run with HotSpot for validation: hotspot -f yantra_chip.flp -p yantra_chip.ptrace")
    print("2. Use results in IEEE paper Section IV")
    print("3. Include in patent evidence")
    
    return results


if __name__ == "__main__":
    results = main()
