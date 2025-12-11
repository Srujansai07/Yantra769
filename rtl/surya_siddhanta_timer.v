/*
 * SURYA SIDDHANTA TIME SYSTEM
 * ============================
 * Based on सूर्य सिद्धांत - Ancient Indian Astronomical Text
 * 
 * The Surya Siddhanta defines time from the smallest unit
 * (Truti - ~29.6 microseconds) to cosmic scales (Kalpa - 4.32 billion years).
 * 
 * Time Units (from smallest to largest):
 * - Truti (त्रुटि) = 29.6296 microseconds (1/33750 second)
 * - Tatpara = 100 Truti = 2.96 ms
 * - Nimesha (निमेष) = 16/75 second = 213 ms (blink of eye)
 * - Kashtha (काष्ठा) = 18 Nimesha = 3.84 seconds
 * - Kala (कला) = 30 Kashtha = 115 seconds
 * - Ghatika (घटिका) = 30 Kala = 24 minutes
 * - Muhurta (मुहूर्त) = 2 Ghatika = 48 minutes
 * - Prahara = 2 Muhurta = 96 minutes
 * - Ahoratra (day-night) = 30 Muhurta = 24 hours
 * - Paksha = 15 Ahoratra (fortnight)
 * - Masa = 2 Paksha (month)
 * - Ritu = 2 Masa (season)
 * - Ayana = 3 Ritu (half-year)
 * - Varsha = 2 Ayana (year)
 * - Yuga cycles (Satya, Treta, Dwapara, Kali)
 * - Mahayuga = 4,320,000 years
 * - Manvantara = 71 Mahayugas
 * - Kalpa = 14 Manvantaras = 4.32 billion years
 * 
 * Application:
 * - Precise timer/counter design
 * - Multi-scale time keeping
 * - Astronomical clock design
 * 
 * Author: SIVAA Project
 * Date: December 2025
 */

module surya_siddhanta_timer #(
    parameter CLK_FREQ = 100_000_000  // 100 MHz input clock
)(
    input  wire        clk,
    input  wire        rst_n,
    
    // Timer control
    input  wire        enable,
    input  wire        sync_pulse,    // External sync
    input  wire [3:0]  time_scale,    // Which unit to output
    
    // Time outputs (all units)
    output reg  [31:0] truti_count,       // Microsecond-scale
    output reg  [23:0] nimesha_count,     // ~200ms
    output reg  [15:0] kashtha_count,     // ~4 seconds
    output reg  [15:0] kala_count,        // ~2 minutes
    output reg  [15:0] ghatika_count,     // 24 minutes
    output reg  [15:0] muhurta_count,     // 48 minutes
    output reg  [15:0] ahoratra_count,    // Days
    output reg  [15:0] paksha_count,      // Fortnights
    output reg  [15:0] masa_count,        // Months
    output reg  [15:0] varsha_count,      // Years
    
    // Yuga tracking (cosmic time)
    output reg  [3:0]  current_yuga,      // 0=Satya, 1=Treta, 2=Dwapara, 3=Kali
    output reg  [31:0] yuga_progress,     // Progress within current yuga
    
    // Selected time output
    output reg  [31:0] selected_time,
    
    // Astronomical outputs
    output reg  [31:0] sidereal_day,      // Nakshatra day
    output reg  [31:0] lunar_day,         // Tithi
    output reg  [15:0] nakshatra,         // Current star (0-26)
    
    // Status
    output wire        tick_truti,        // Truti pulse
    output wire        tick_nimesha       // Nimesha pulse (~5 Hz)
);

    // =========================================================================
    // TIME UNIT CONVERSION CONSTANTS
    // =========================================================================
    
    // Truti = 29.6296 microseconds = 1/33750 second
    // At 100 MHz, 1 clock = 10 ns = 0.00001 ms
    // Truti = 29.6296 us = 2963 clocks at 100 MHz
    localparam CLOCKS_PER_TRUTI = 2963;
    
    // Nimesha = 16/75 second ≈ 213.33 ms
    // = 21,333,333 clocks at 100 MHz
    localparam CLOCKS_PER_NIMESHA = 21_333_333;
    
    // Kashtha = 18 Nimeshas ≈ 3.84 seconds
    localparam NIMESHA_PER_KASHTHA = 18;
    
    // Kala = 30 Kashthas ≈ 115 seconds
    localparam KASHTHA_PER_KALA = 30;
    
    // Ghatika = 30 Kalas = 24 minutes
    localparam KALA_PER_GHATIKA = 30;
    
    // Muhurta = 2 Ghatikas = 48 minutes
    localparam GHATIKA_PER_MUHURTA = 2;
    
    // Ahoratra = 30 Muhurtas = 24 hours
    localparam MUHURTA_PER_AHORATRA = 30;
    
    // Paksha = 15 Ahoratras
    localparam AHORATRA_PER_PAKSHA = 15;
    
    // Masa = 2 Pakshas
    localparam PAKSHA_PER_MASA = 2;
    
    // Varsha = 12 Masas
    localparam MASA_PER_VARSHA = 12;
    
    // Yuga durations (in years, scaled down for demo)
    // Actual: Kali=432000, Dwapara=864000, Treta=1296000, Satya=1728000
    // Demo: scaled by 1000x for practicality
    localparam KALI_YEARS    = 432;
    localparam DWAPARA_YEARS = 864;
    localparam TRETA_YEARS   = 1296;
    localparam SATYA_YEARS   = 1728;
    
    // =========================================================================
    // INTERNAL COUNTERS
    // =========================================================================
    
    reg [31:0] clock_counter;
    reg [31:0] nimesha_clock_counter;
    
    // Tick generators
    reg truti_tick, nimesha_tick;
    assign tick_truti = truti_tick;
    assign tick_nimesha = nimesha_tick;
    
    // =========================================================================
    // TRUTI COUNTER (Fastest unit - ~30 microseconds)
    // =========================================================================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clock_counter <= 32'd0;
            truti_count <= 32'd0;
            truti_tick <= 1'b0;
        end else if (enable) begin
            if (clock_counter >= CLOCKS_PER_TRUTI - 1) begin
                clock_counter <= 32'd0;
                truti_count <= truti_count + 1;
                truti_tick <= 1'b1;
            end else begin
                clock_counter <= clock_counter + 1;
                truti_tick <= 1'b0;
            end
        end
    end
    
    // =========================================================================
    // NIMESHA COUNTER (~213 ms - blink of eye)
    // =========================================================================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            nimesha_clock_counter <= 32'd0;
            nimesha_count <= 24'd0;
            nimesha_tick <= 1'b0;
        end else if (enable) begin
            if (nimesha_clock_counter >= CLOCKS_PER_NIMESHA - 1) begin
                nimesha_clock_counter <= 32'd0;
                nimesha_count <= nimesha_count + 1;
                nimesha_tick <= 1'b1;
            end else begin
                nimesha_clock_counter <= nimesha_clock_counter + 1;
                nimesha_tick <= 1'b0;
            end
        end
    end
    
    // =========================================================================
    // HIGHER TIME UNITS (Cascaded from Nimesha)
    // =========================================================================
    
    reg [4:0] nimesha_in_kashtha;
    reg [4:0] kashtha_in_kala;
    reg [4:0] kala_in_ghatika;
    reg [1:0] ghatika_in_muhurta;
    reg [4:0] muhurta_in_ahoratra;
    reg [3:0] ahoratra_in_paksha;
    reg [1:0] paksha_in_masa;
    reg [3:0] masa_in_varsha;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            kashtha_count <= 16'd0;
            kala_count <= 16'd0;
            ghatika_count <= 16'd0;
            muhurta_count <= 16'd0;
            ahoratra_count <= 16'd0;
            paksha_count <= 16'd0;
            masa_count <= 16'd0;
            varsha_count <= 16'd0;
            
            nimesha_in_kashtha <= 5'd0;
            kashtha_in_kala <= 5'd0;
            kala_in_ghatika <= 5'd0;
            ghatika_in_muhurta <= 2'd0;
            muhurta_in_ahoratra <= 5'd0;
            ahoratra_in_paksha <= 4'd0;
            paksha_in_masa <= 2'd0;
            masa_in_varsha <= 4'd0;
            
            current_yuga <= 4'd3;  // Start in Kali Yuga
            yuga_progress <= 32'd0;
        end else if (nimesha_tick) begin
            // Kashtha (18 Nimeshas)
            if (nimesha_in_kashtha >= NIMESHA_PER_KASHTHA - 1) begin
                nimesha_in_kashtha <= 5'd0;
                kashtha_count <= kashtha_count + 1;
                
                // Kala (30 Kashthas)
                if (kashtha_in_kala >= KASHTHA_PER_KALA - 1) begin
                    kashtha_in_kala <= 5'd0;
                    kala_count <= kala_count + 1;
                    
                    // Ghatika (30 Kalas)
                    if (kala_in_ghatika >= KALA_PER_GHATIKA - 1) begin
                        kala_in_ghatika <= 5'd0;
                        ghatika_count <= ghatika_count + 1;
                        
                        // Muhurta (2 Ghatikas)
                        if (ghatika_in_muhurta >= GHATIKA_PER_MUHURTA - 1) begin
                            ghatika_in_muhurta <= 2'd0;
                            muhurta_count <= muhurta_count + 1;
                            
                            // Ahoratra (30 Muhurtas = 1 day)
                            if (muhurta_in_ahoratra >= MUHURTA_PER_AHORATRA - 1) begin
                                muhurta_in_ahoratra <= 5'd0;
                                ahoratra_count <= ahoratra_count + 1;
                                
                                // Continue cascading for Paksha, Masa, Varsha...
                                if (ahoratra_in_paksha >= AHORATRA_PER_PAKSHA - 1) begin
                                    ahoratra_in_paksha <= 4'd0;
                                    paksha_count <= paksha_count + 1;
                                    
                                    if (paksha_in_masa >= PAKSHA_PER_MASA - 1) begin
                                        paksha_in_masa <= 2'd0;
                                        masa_count <= masa_count + 1;
                                        
                                        if (masa_in_varsha >= MASA_PER_VARSHA - 1) begin
                                            masa_in_varsha <= 4'd0;
                                            varsha_count <= varsha_count + 1;
                                            yuga_progress <= yuga_progress + 1;
                                        end else begin
                                            masa_in_varsha <= masa_in_varsha + 1;
                                        end
                                    end else begin
                                        paksha_in_masa <= paksha_in_masa + 1;
                                    end
                                end else begin
                                    ahoratra_in_paksha <= ahoratra_in_paksha + 1;
                                end
                            end else begin
                                muhurta_in_ahoratra <= muhurta_in_ahoratra + 1;
                            end
                        end else begin
                            ghatika_in_muhurta <= ghatika_in_muhurta + 1;
                        end
                    end else begin
                        kala_in_ghatika <= kala_in_ghatika + 1;
                    end
                end else begin
                    kashtha_in_kala <= kashtha_in_kala + 1;
                end
            end else begin
                nimesha_in_kashtha <= nimesha_in_kashtha + 1;
            end
        end
    end
    
    // =========================================================================
    // ASTRONOMICAL CALCULATIONS
    // =========================================================================
    
    // Nakshatra = 27 lunar mansions, each ~13.33 degrees
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            nakshatra <= 16'd0;
            sidereal_day <= 32'd0;
            lunar_day <= 32'd0;
        end else if (enable) begin
            // Sidereal day slightly shorter than solar day
            // Accumulate based on nimesha count
            sidereal_day <= (nimesha_count * 366) / 365;
            
            // Lunar day (Tithi) = 1/30 of lunar month
            lunar_day <= ahoratra_count % 30;
            
            // Nakshatra cycles through 27 stars
            nakshatra <= (ahoratra_count / 13) % 27;
        end
    end
    
    // =========================================================================
    // TIME SCALE SELECTOR
    // =========================================================================
    
    always @(*) begin
        case (time_scale)
            4'd0: selected_time = truti_count;
            4'd1: selected_time = {8'd0, nimesha_count};
            4'd2: selected_time = {16'd0, kashtha_count};
            4'd3: selected_time = {16'd0, kala_count};
            4'd4: selected_time = {16'd0, ghatika_count};
            4'd5: selected_time = {16'd0, muhurta_count};
            4'd6: selected_time = {16'd0, ahoratra_count};
            4'd7: selected_time = {16'd0, paksha_count};
            4'd8: selected_time = {16'd0, masa_count};
            4'd9: selected_time = {16'd0, varsha_count};
            4'd10: selected_time = yuga_progress;
            default: selected_time = truti_count;
        endcase
    end

endmodule

// =============================================================================
// SURYA SIDDHANTA TIME SYSTEM
// =============================================================================
//
// The Surya Siddhanta is one of the earliest astronomical texts,
// predating Ptolemy. Key concepts:
//
// 1. TRUTI - The smallest time unit (~30 microseconds)
//    Used for precise astronomical calculations
//
// 2. NIMESHA - "Blink of an eye" (~213 ms)
//    Natural human-scale reference
//
// 3. MUHURTA - 48 minutes
//    Used for auspicious timings (Electional astrology)
//
// 4. YUGA CYCLES:
//    - Kali Yuga:    432,000 years (current age)
//    - Dwapara Yuga: 864,000 years
//    - Treta Yuga:   1,296,000 years
//    - Satya Yuga:   1,728,000 years
//    - Total:        4,320,000 years (Mahayuga)
//
// 5. KALPA - Day of Brahma = 4.32 billion years
//    (Close to age of Earth!)
//
// APPLICATION IN CHIPS:
// - Multi-scale timer design
// - RTC with astronomical precision
// - GPS/NavIC timing systems
// - Atomic clock interfaces
//
// =============================================================================
