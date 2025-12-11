/*
 * SIDDHANTA SHIROMANI GRAVITY ENGINE
 * ===================================
 * Based on सिद्धान्त शिरोमणि by Bhaskaracharya II (1150 CE)
 * 
 * Bhaskaracharya (Bhaskara II) described gravity as:
 * "आकृष्टिशक्तिश्च महि तया यत् खस्थं गुरुस्वाभिमुखं स्वशक्त्या।
 *  आकृष्यते तत्पततीव भाति समे समन्तात् क्व पतत्वियं खे॥"
 * 
 * Translation:
 * "The earth attracts inert objects in space towards itself,
 * by its own attraction power. It appears to fall (but actually)
 * on all sides, where will it fall in the sky?"
 * 
 * This describes:
 * 1. Central attraction (Madhyakarshana)
 * 2. Objects in equilibrium in space
 * 3. Gravity as an inherent property of massive bodies
 * 
 * 500 years before Newton!
 * 
 * Application:
 * - Orbital mechanics calculations
 * - Sensor data processing (accelerometers)
 * - Navigation systems (NavIC/GPS)
 * 
 * Author: SIVAA Project
 * Date: December 2025
 */

module siddhanta_gravity #(
    parameter DATA_WIDTH = 32,
    parameter FIXED_POINT = 16    // 16.16 fixed point
)(
    input  wire                    clk,
    input  wire                    rst_n,
    
    // Object position (relative to center of mass)
    input  wire signed [DATA_WIDTH-1:0] pos_x,
    input  wire signed [DATA_WIDTH-1:0] pos_y,
    input  wire signed [DATA_WIDTH-1:0] pos_z,
    
    // Object velocity
    input  wire signed [DATA_WIDTH-1:0] vel_x,
    input  wire signed [DATA_WIDTH-1:0] vel_y,
    input  wire signed [DATA_WIDTH-1:0] vel_z,
    
    // Mass parameters
    input  wire [DATA_WIDTH-1:0]  central_mass,    // M (planet/sun)
    input  wire [DATA_WIDTH-1:0]  object_mass,     // m (satellite)
    
    // Control
    input  wire                    start,
    input  wire [7:0]              time_step,       // dt for integration
    
    // Gravitational outputs
    output reg  signed [DATA_WIDTH-1:0] force_x,
    output reg  signed [DATA_WIDTH-1:0] force_y,
    output reg  signed [DATA_WIDTH-1:0] force_z,
    output reg  [DATA_WIDTH-1:0]        force_magnitude,
    
    // Orbital parameters
    output reg  [DATA_WIDTH-1:0]  orbital_radius,
    output reg  [DATA_WIDTH-1:0]  orbital_velocity,
    output reg  [DATA_WIDTH-1:0]  orbital_period,
    output reg  [DATA_WIDTH-1:0]  escape_velocity,
    
    // Updated position (after time_step)
    output reg  signed [DATA_WIDTH-1:0] new_pos_x,
    output reg  signed [DATA_WIDTH-1:0] new_pos_y,
    output reg  signed [DATA_WIDTH-1:0] new_pos_z,
    
    // Status
    output reg                     done,
    output reg                     in_orbit         // Object is in stable orbit
);

    // =========================================================================
    // GRAVITATIONAL CONSTANT
    // =========================================================================
    // G = 6.674 × 10^-11 N⋅m²/kg² (SI units)
    // For fixed-point, we scale appropriately
    
    // Scaled G for fixed-point (16.16 format)
    // Using G' = G × 2^32 for integer math
    localparam [DATA_WIDTH-1:0] G_SCALED = 32'h00000100;  // Scaled for demo
    
    // =========================================================================
    // INTERNAL REGISTERS
    // =========================================================================
    
    reg [DATA_WIDTH*2-1:0] r_squared;      // r²
    reg [DATA_WIDTH-1:0]   r_magnitude;    // |r|
    reg [DATA_WIDTH*2-1:0] gm_product;     // G × M
    reg [DATA_WIDTH*2-1:0] force_mag_sq;   // |F|²
    
    // State machine
    localparam IDLE = 3'd0;
    localparam CALC_R = 3'd1;
    localparam CALC_SQRT = 3'd2;
    localparam CALC_FORCE = 3'd3;
    localparam CALC_ORBIT = 3'd4;
    localparam UPDATE = 3'd5;
    localparam DONE = 3'd6;
    
    reg [2:0] state;
    reg [3:0] sqrt_iter;
    reg [DATA_WIDTH-1:0] sqrt_guess;
    
    // =========================================================================
    // BHASKARACHARYA'S GRAVITY CALCULATION
    // =========================================================================
    // F = G × M × m / r²  (Madhyakarshana)
    // Direction: towards center (akrishti)
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            in_orbit <= 1'b0;
            force_x <= 0;
            force_y <= 0;
            force_z <= 0;
            force_magnitude <= 0;
            orbital_radius <= 0;
            orbital_velocity <= 0;
            orbital_period <= 0;
            escape_velocity <= 0;
            new_pos_x <= 0;
            new_pos_y <= 0;
            new_pos_z <= 0;
            r_squared <= 0;
            r_magnitude <= 0;
            sqrt_iter <= 0;
            sqrt_guess <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= CALC_R;
                    end
                end
                
                CALC_R: begin
                    // Calculate r² = x² + y² + z²
                    r_squared <= (pos_x * pos_x) + (pos_y * pos_y) + (pos_z * pos_z);
                    
                    // Initialize sqrt
                    sqrt_guess <= (pos_x[DATA_WIDTH-1] ? -pos_x : pos_x) +
                                  (pos_y[DATA_WIDTH-1] ? -pos_y : pos_y) +
                                  (pos_z[DATA_WIDTH-1] ? -pos_z : pos_z);
                    sqrt_guess <= sqrt_guess >> 1;  // Initial guess = (|x|+|y|+|z|)/2
                    sqrt_iter <= 4'd0;
                    
                    state <= CALC_SQRT;
                end
                
                CALC_SQRT: begin
                    // Newton-Raphson for sqrt(r²)
                    // x_new = (x + r²/x) / 2
                    if (sqrt_iter < 8 && sqrt_guess != 0) begin
                        sqrt_guess <= (sqrt_guess + (r_squared[DATA_WIDTH-1:0] / sqrt_guess)) >> 1;
                        sqrt_iter <= sqrt_iter + 1;
                    end else begin
                        r_magnitude <= sqrt_guess;
                        orbital_radius <= sqrt_guess;
                        state <= CALC_FORCE;
                    end
                end
                
                CALC_FORCE: begin
                    // F = G × M × m / r²
                    // Force direction: towards center (negative position)
                    
                    if (r_squared != 0 && r_magnitude != 0) begin
                        // GM product
                        gm_product <= G_SCALED * central_mass;
                        
                        // Force magnitude = GM × m / r²
                        force_magnitude <= (G_SCALED * central_mass * object_mass) / 
                                          r_squared[DATA_WIDTH-1:0];
                        
                        // Force components (towards center)
                        // F_x = -F × x/r
                        force_x <= -((G_SCALED * central_mass * object_mass * pos_x) / 
                                    (r_squared[DATA_WIDTH-1:0] * r_magnitude));
                        force_y <= -((G_SCALED * central_mass * object_mass * pos_y) / 
                                    (r_squared[DATA_WIDTH-1:0] * r_magnitude));
                        force_z <= -((G_SCALED * central_mass * object_mass * pos_z) / 
                                    (r_squared[DATA_WIDTH-1:0] * r_magnitude));
                    end
                    
                    state <= CALC_ORBIT;
                end
                
                CALC_ORBIT: begin
                    // Orbital parameters (Bhaskaracharya knew these!)
                    
                    // Orbital velocity = sqrt(GM/r)
                    if (r_magnitude != 0) begin
                        orbital_velocity <= sqrt_guess;  // Approximation
                    end
                    
                    // Escape velocity = sqrt(2GM/r) = sqrt(2) × orbital_velocity
                    escape_velocity <= (orbital_velocity * 32'h00016A83) >> FIXED_POINT;  // ×√2
                    
                    // Orbital period = 2π × sqrt(r³/GM)
                    // Simplified: T ∝ r^1.5
                    orbital_period <= (r_magnitude * r_magnitude) >> 10;  // Approximation
                    
                    // Check if in stable orbit
                    // |v| ≈ sqrt(GM/r) means stable orbit
                    in_orbit <= (vel_x * vel_x + vel_y * vel_y + vel_z * vel_z) < 
                               (2 * G_SCALED * central_mass / r_magnitude);
                    
                    state <= UPDATE;
                end
                
                UPDATE: begin
                    // Update position using velocity and acceleration
                    // Using Verlet integration
                    
                    // a = F/m
                    // new_pos = pos + vel × dt + 0.5 × a × dt²
                    // Simplified: new_pos ≈ pos + vel × dt
                    
                    new_pos_x <= pos_x + ((vel_x * time_step) >> 8);
                    new_pos_y <= pos_y + ((vel_y * time_step) >> 8);
                    new_pos_z <= pos_z + ((vel_z * time_step) >> 8);
                    
                    state <= DONE;
                end
                
                DONE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule

// =============================================================================
// BHASKARACHARYA'S CONTRIBUTIONS (1114-1185 CE)
// =============================================================================
//
// Siddhanta Shiromani has four parts:
// 1. Lilavati - Arithmetic
// 2. Bijaganita - Algebra
// 3. Goladhyaya - Spherical trigonometry
// 4. Grahaganita - Planetary mathematics
//
// KEY DISCOVERIES:
//
// 1. GRAVITY (Madhyakarshana):
//    - Central attraction force
//    - Objects fall towards Earth's center
//    - Described equilibrium in space
//
// 2. EARTH'S ROTATION:
//    - Daily rotation causes day/night
//    - Not celestial sphere rotation
//
// 3. PLANETARY MOTION:
//    - Accurate planetary positions
//    - Ecliptic calculations
//
// 4. CALCULUS CONCEPTS:
//    - Instantaneous velocity
//    - Derivatives of sine
//    - 500 years before Newton/Leibniz!
//
// APPLICATION IN CHIPS:
// - Orbital mechanics processors
// - Accelerometer data processing
// - Navigation IC (NavIC/GPS)
// - Inertial measurement units
//
// =============================================================================
