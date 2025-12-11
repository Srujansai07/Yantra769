/*
 * NAVA GRAHA POWER CONTROLLER - 9 VOLTAGE DOMAINS
 * =================================================
 * Based on नवग्रह (Nine Planets) from Jyotish Shastra
 * 
 * Each Graha (planet) controls a power domain:
 * 
 * Surya (सूर्य)    Sun      - Core VDD (0.8V)  - Main compute
 * Chandra (चन्द्र) Moon     - SRAM VDD (0.7V)  - Cache power
 * Mangala (मंगल)  Mars     - Boost VDD (1.0V) - Turbo mode
 * Budha (बुध)     Mercury  - I/O VDD (1.8V)   - I/O interface
 * Guru (गुरु)     Jupiter  - PLL VDD (1.2V)   - Clock gen
 * Shukra (शुक्र)  Venus    - Analog VDD (3.3V)- Analog blocks
 * Shani (शनि)    Saturn   - Retention (0.4V) - Sleep mode
 * Rahu (राहु)     N. Node  - Always-on (0.6V) - RTC/Wake
 * Ketu (केतु)     S. Node  - Backup (Battery) - Backup power
 * 
 * Author: SIVAA Project
 * Date: December 2025
 */

module nava_graha_power #(
    parameter NUM_DOMAINS = 9
)(
    input  wire        clk,
    input  wire        rst_n,
    
    // Power mode control
    input  wire [3:0]  power_mode,        // 0=Active, 1=Idle, 2=Sleep, 3=Off
    input  wire        turbo_request,      // Request Mangala boost
    input  wire        sleep_request,      // Request Shani retention
    
    // Individual domain control
    input  wire [8:0]  domain_enable,      // Which Grahas are active
    
    // Voltage outputs (scaled 0-255 = 0V-3.3V)
    output reg  [7:0]  vdd_surya,          // Core VDD
    output reg  [7:0]  vdd_chandra,        // SRAM VDD
    output reg  [7:0]  vdd_mangala,        // Boost VDD
    output reg  [7:0]  vdd_budha,          // I/O VDD
    output reg  [7:0]  vdd_guru,           // PLL VDD
    output reg  [7:0]  vdd_shukra,         // Analog VDD
    output reg  [7:0]  vdd_shani,          // Retention VDD
    output reg  [7:0]  vdd_rahu,           // Always-on VDD
    output reg  [7:0]  vdd_ketu,           // Backup VDD
    
    // Power status
    output wire [8:0]  domain_active,
    output wire [7:0]  total_power,        // Estimated power (mW scaled)
    output wire        power_good,
    
    // Graha influence (each bit = planet influence active)
    output wire [8:0]  graha_influence
);

    // =========================================================================
    // GRAHA (ग्रह) DOMAIN INDICES
    // =========================================================================
    
    localparam SURYA   = 4'd0;
    localparam CHANDRA = 4'd1;
    localparam MANGALA = 4'd2;
    localparam BUDHA   = 4'd3;
    localparam GURU    = 4'd4;
    localparam SHUKRA  = 4'd5;
    localparam SHANI   = 4'd6;
    localparam RAHU    = 4'd7;
    localparam KETU    = 4'd8;
    
    // =========================================================================
    // VOLTAGE LEVELS (in 8-bit scale: 0=0V, 255=3.3V)
    // =========================================================================
    
    // Normal operation voltages
    localparam V_0_4V = 8'd31;   // 0.4V - Retention (Shani)
    localparam V_0_6V = 8'd46;   // 0.6V - Always-on (Rahu)
    localparam V_0_7V = 8'd54;   // 0.7V - SRAM (Chandra)
    localparam V_0_8V = 8'd62;   // 0.8V - Core (Surya)
    localparam V_1_0V = 8'd77;   // 1.0V - Turbo (Mangala)
    localparam V_1_2V = 8'd93;   // 1.2V - PLL (Guru)
    localparam V_1_8V = 8'd139;  // 1.8V - I/O (Budha)
    localparam V_3_3V = 8'd255;  // 3.3V - Analog (Shukra)
    localparam V_BATT = 8'd92;   // ~1.2V Battery (Ketu)
    
    // =========================================================================
    // POWER MODE STATE MACHINE
    // =========================================================================
    
    localparam MODE_ACTIVE = 4'd0;  // All domains active
    localparam MODE_IDLE   = 4'd1;  // Core at reduced voltage
    localparam MODE_SLEEP  = 4'd2;  // Only Shani/Rahu/Ketu active
    localparam MODE_OFF    = 4'd3;  // Only Ketu (battery backup)
    localparam MODE_TURBO  = 4'd4;  // Mangala boost active
    
    reg [3:0] current_mode;
    reg [8:0] domain_active_reg;
    
    assign domain_active = domain_active_reg;
    assign graha_influence = domain_active_reg;
    
    // =========================================================================
    // VOLTAGE REGULATION
    // =========================================================================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset to sleep mode (safe state)
            current_mode <= MODE_SLEEP;
            domain_active_reg <= 9'b111_000_000;  // Shani, Rahu, Ketu only
            
            vdd_surya   <= 8'd0;
            vdd_chandra <= 8'd0;
            vdd_mangala <= 8'd0;
            vdd_budha   <= 8'd0;
            vdd_guru    <= 8'd0;
            vdd_shukra  <= 8'd0;
            vdd_shani   <= V_0_4V;
            vdd_rahu    <= V_0_6V;
            vdd_ketu    <= V_BATT;
        end else begin
            // Mode transition logic
            if (sleep_request) begin
                current_mode <= MODE_SLEEP;
            end else if (turbo_request) begin
                current_mode <= MODE_TURBO;
            end else begin
                current_mode <= power_mode;
            end
            
            // Voltage setting based on mode
            case (current_mode)
                MODE_ACTIVE: begin
                    // All Grahas active at normal voltages
                    domain_active_reg <= 9'b111_111_111;
                    
                    vdd_surya   <= domain_enable[SURYA]   ? V_0_8V : 8'd0;
                    vdd_chandra <= domain_enable[CHANDRA] ? V_0_7V : 8'd0;
                    vdd_mangala <= 8'd0;  // No boost in normal mode
                    vdd_budha   <= domain_enable[BUDHA]   ? V_1_8V : 8'd0;
                    vdd_guru    <= domain_enable[GURU]    ? V_1_2V : 8'd0;
                    vdd_shukra  <= domain_enable[SHUKRA]  ? V_3_3V : 8'd0;
                    vdd_shani   <= V_0_4V;  // Always ready
                    vdd_rahu    <= V_0_6V;  // Always on
                    vdd_ketu    <= V_BATT;  // Battery backup
                end
                
                MODE_TURBO: begin
                    // Mangala (Mars) boost active!
                    domain_active_reg <= 9'b111_111_111;
                    
                    vdd_surya   <= V_1_0V;  // Boost core too!
                    vdd_chandra <= V_0_8V;  // Boost cache
                    vdd_mangala <= V_1_0V;  // TURBO!
                    vdd_budha   <= V_1_8V;
                    vdd_guru    <= V_1_2V;
                    vdd_shukra  <= V_3_3V;
                    vdd_shani   <= V_0_4V;
                    vdd_rahu    <= V_0_6V;
                    vdd_ketu    <= V_BATT;
                end
                
                MODE_IDLE: begin
                    // Reduced voltages for idle
                    domain_active_reg <= 9'b111_110_011;
                    
                    vdd_surya   <= V_0_7V;  // Reduced
                    vdd_chandra <= V_0_6V;  // Reduced
                    vdd_mangala <= 8'd0;
                    vdd_budha   <= V_1_8V;  // I/O stays
                    vdd_guru    <= V_1_2V;  // PLL stays
                    vdd_shukra  <= 8'd0;    // Analog off
                    vdd_shani   <= V_0_4V;
                    vdd_rahu    <= V_0_6V;
                    vdd_ketu    <= V_BATT;
                end
                
                MODE_SLEEP: begin
                    // Only Shani (retention), Rahu (always-on), Ketu (backup)
                    domain_active_reg <= 9'b111_000_000;
                    
                    vdd_surya   <= 8'd0;
                    vdd_chandra <= 8'd0;
                    vdd_mangala <= 8'd0;
                    vdd_budha   <= 8'd0;
                    vdd_guru    <= 8'd0;
                    vdd_shukra  <= 8'd0;
                    vdd_shani   <= V_0_4V;  // Retention for state
                    vdd_rahu    <= V_0_6V;  // RTC/Wake logic
                    vdd_ketu    <= V_BATT;  // Battery backup
                end
                
                MODE_OFF: begin
                    // Only Ketu (battery backup) for critical data
                    domain_active_reg <= 9'b100_000_000;
                    
                    vdd_surya   <= 8'd0;
                    vdd_chandra <= 8'd0;
                    vdd_mangala <= 8'd0;
                    vdd_budha   <= 8'd0;
                    vdd_guru    <= 8'd0;
                    vdd_shukra  <= 8'd0;
                    vdd_shani   <= 8'd0;
                    vdd_rahu    <= 8'd0;
                    vdd_ketu    <= V_BATT;  // Battery RTC only
                end
                
                default: begin
                    current_mode <= MODE_ACTIVE;
                end
            endcase
        end
    end
    
    // =========================================================================
    // POWER ESTIMATION
    // =========================================================================
    
    // Simple power model: P = V^2 / R (scaled)
    // Each domain contributes proportionally to its voltage
    wire [15:0] power_sum;
    assign power_sum = 
        (vdd_surya   >> 2) +
        (vdd_chandra >> 2) +
        (vdd_mangala >> 2) +
        (vdd_budha   >> 3) +
        (vdd_guru    >> 3) +
        (vdd_shukra  >> 3) +
        (vdd_shani   >> 4) +
        (vdd_rahu    >> 4) +
        (vdd_ketu    >> 4);
    
    assign total_power = power_sum[7:0];
    
    // Power good when all enabled domains are stable
    assign power_good = (domain_active_reg == domain_enable) || 
                        (current_mode == MODE_SLEEP) ||
                        (current_mode == MODE_OFF);

endmodule

// =============================================================================
// NAVA GRAHA (NINE PLANETS) CORRESPONDENCE
// =============================================================================
//
// In Vedic Astrology, the 9 Grahas influence different aspects of life.
// In SIVAA, they control power domains:
//
// Surya (Sun):
//   - King of planets, source of energy
//   - Controls main CPU core power
//   - Dominant during active computation
//
// Chandra (Moon):
//   - Mind, memory, emotions
//   - Controls cache/SRAM power
//   - Waxes and wanes with memory activity
//
// Mangala (Mars):
//   - Energy, action, aggression
//   - Controls turbo/boost power
//   - Activates for high-performance bursts
//
// Budha (Mercury):
//   - Communication, intelligence
//   - Controls I/O interface power
//   - Always active for external communication
//
// Guru (Jupiter):
//   - Wisdom, expansion, timing
//   - Controls PLL/clock generation
//   - Governs all timing in the chip
//
// Shukra (Venus):
//   - Beauty, refinement, analog nature
//   - Controls analog block power
//   - For ADC/DAC operations
//
// Shani (Saturn):
//   - Discipline, restriction, preservation
//   - Controls retention mode power
//   - Preserves state during sleep
//
// Rahu (North Node):
//   - Shadow, always present but hidden
//   - Controls always-on domain
//   - Never sleeps (RTC, wake logic)
//
// Ketu (South Node):
//   - Past, detachment, backup
//   - Controls battery backup domain
//   - Ultimate fallback for critical data
//
// =============================================================================
