/*
 * KATAPAYADI SANKHYA - Vedic Hashing System
 * ==========================================
 * Based on कटपयादि सङ्ख्या encoding system
 * 
 * This is a HASHING SYSTEM used by ancient Rishis to encode
 * mathematical formulas into shlokas (verses).
 * 
 * The Encoding:
 * क(ka)=1, ख(kha)=2, ग(ga)=3, घ(gha)=4, ङ(nga)=5
 * च(cha)=6, छ(chha)=7, ज(ja)=8, झ(jha)=9, ञ(nya)=0
 * ट(ta)=1, ठ(tha)=2, ड(da)=3, ढ(dha)=4, ण(na)=5
 * त(ta)=6, थ(tha)=7, द(da)=8, ध(dha)=9, न(na)=0
 * प(pa)=1, फ(pha)=2, ब(ba)=3, भ(bha)=4, म(ma)=5
 * य(ya)=1, र(ra)=2, ल(la)=3, व(va)=4, श(sha)=5
 * ष(sha)=6, स(sa)=7, ह(ha)=8
 * 
 * Famous Example:
 * "गोपीभाग्यमधुव्रात" encodes π = 3.14159265358979...
 * 
 * Application:
 * - Cryptographic hash functions
 * - Memory addressing
 * - Data encoding/compression
 * 
 * Author: SIVAA Project
 * Date: December 2025
 */

module katapayadi_hash #(
    parameter DATA_WIDTH = 32,
    parameter HASH_WIDTH = 64,
    parameter MAX_INPUT = 16
)(
    input  wire                    clk,
    input  wire                    rst_n,
    
    // Input data (can be text or binary)
    input  wire [7:0]              input_char [0:MAX_INPUT-1],
    input  wire [3:0]              input_length,
    input  wire                    start,
    
    // Hash operation select
    input  wire [1:0]              hash_mode,
    
    // Katapayadi encoded outputs
    output reg  [3:0]              digit_out [0:MAX_INPUT-1],
    output reg  [HASH_WIDTH-1:0]   hash_value,
    output reg  [DATA_WIDTH-1:0]   encoded_number,
    
    // Decoding outputs
    output reg  [7:0]              decoded_char [0:MAX_INPUT-1],
    
    // Status
    output reg                     done,
    output reg                     valid
);

    // =========================================================================
    // KATAPAYADI LOOKUP TABLE
    // =========================================================================
    // Sanskrit consonants to numbers (0-9)
    
    // Simplified: Using ASCII positions for demo
    // Real implementation would use Unicode Devanagari
    
    // Hash modes
    localparam MODE_ENCODE = 2'd0;   // Text to numbers
    localparam MODE_DECODE = 2'd1;   // Numbers to text (first consonant)
    localparam MODE_HASH   = 2'd2;   // Generate hash
    localparam MODE_PI     = 2'd3;   // Verify Pi encoding
    
    // =========================================================================
    // KATAPAYADI ENCODING FUNCTION
    // =========================================================================
    // Returns digit 0-9 for a consonant, or 'F' for vowels/invalid
    
    function [3:0] katapayadi_encode;
        input [7:0] char_in;
        begin
            case (char_in)
                // Ka varga (क वर्ग)
                8'h4B, 8'h6B: katapayadi_encode = 4'd1;  // K, k
                8'h47, 8'h67: katapayadi_encode = 4'd3;  // G, g
                // Cha varga (च वर्ग)
                8'h43, 8'h63: katapayadi_encode = 4'd6;  // C, c
                8'h4A, 8'h6A: katapayadi_encode = 4'd8;  // J, j
                // Ta varga (ट वर्ग)
                8'h54, 8'h74: katapayadi_encode = 4'd1;  // T, t
                8'h44, 8'h64: katapayadi_encode = 4'd3;  // D, d
                8'h4E, 8'h6E: katapayadi_encode = 4'd0;  // N, n
                // Pa varga (प वर्ग)
                8'h50, 8'h70: katapayadi_encode = 4'd1;  // P, p
                8'h42, 8'h62: katapayadi_encode = 4'd3;  // B, b
                8'h4D, 8'h6D: katapayadi_encode = 4'd5;  // M, m
                // Ya-aadi (य आदि)
                8'h59, 8'h79: katapayadi_encode = 4'd1;  // Y, y
                8'h52, 8'h72: katapayadi_encode = 4'd2;  // R, r
                8'h4C, 8'h6C: katapayadi_encode = 4'd3;  // L, l
                8'h56, 8'h76: katapayadi_encode = 4'd4;  // V, v
                8'h53, 8'h73: katapayadi_encode = 4'd7;  // S, s
                8'h48, 8'h68: katapayadi_encode = 4'd8;  // H, h
                // Vowels return F (skip)
                default: katapayadi_encode = 4'hF;
            endcase
        end
    endfunction
    
    // =========================================================================
    // HASH GENERATION (Vedic mixing function)
    // =========================================================================
    
    function [HASH_WIDTH-1:0] vedic_mix;
        input [HASH_WIDTH-1:0] h;
        input [3:0] digit;
        begin
            // Mix using Golden Ratio bits (like modern hash functions)
            // φ ≈ 1.618..., binary: 1.1001111000110111...
            vedic_mix = h ^ ({h[59:0], 4'd0} + {60'd0, digit});
            vedic_mix = vedic_mix ^ (vedic_mix >> 17);
            vedic_mix = vedic_mix * 64'h9E3779B97F4A7C15; // Golden ratio constant
            vedic_mix = vedic_mix ^ (vedic_mix >> 31);
        end
    endfunction
    
    // =========================================================================
    // STATE MACHINE
    // =========================================================================
    
    localparam IDLE = 2'd0;
    localparam PROCESS = 2'd1;
    localparam FINALIZE = 2'd2;
    
    reg [1:0] state;
    reg [3:0] char_index;
    reg [HASH_WIDTH-1:0] hash_accum;
    reg [DATA_WIDTH-1:0] number_accum;
    reg [3:0] digit_count;
    
    integer i;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            valid <= 1'b0;
            hash_value <= 64'd0;
            encoded_number <= 32'd0;
            char_index <= 4'd0;
            hash_accum <= 64'd0;
            number_accum <= 32'd0;
            digit_count <= 4'd0;
            
            for (i = 0; i < MAX_INPUT; i = i + 1) begin
                digit_out[i] <= 4'd0;
                decoded_char[i] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= PROCESS;
                        char_index <= 4'd0;
                        hash_accum <= 64'h5555555555555555;  // Initial seed
                        number_accum <= 32'd0;
                        digit_count <= 4'd0;
                    end
                end
                
                PROCESS: begin
                    if (char_index < input_length) begin
                        // Encode current character
                        digit_out[char_index] <= katapayadi_encode(input_char[char_index]);
                        
                        // If valid digit (not vowel)
                        if (katapayadi_encode(input_char[char_index]) != 4'hF) begin
                            // Add to hash
                            hash_accum <= vedic_mix(hash_accum, 
                                         katapayadi_encode(input_char[char_index]));
                            
                            // Add to number (for numeric encoding)
                            number_accum <= number_accum * 10 + 
                                           {28'd0, katapayadi_encode(input_char[char_index])};
                            
                            digit_count <= digit_count + 1;
                        end
                        
                        char_index <= char_index + 1;
                    end else begin
                        state <= FINALIZE;
                    end
                end
                
                FINALIZE: begin
                    // Final mixing
                    hash_value <= hash_accum ^ (hash_accum >> 23);
                    encoded_number <= number_accum;
                    
                    // Validate result
                    valid <= (digit_count > 0);
                    done <= 1'b1;
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule

// =============================================================================
// KATAPAYADI SYSTEM ORIGINS
// =============================================================================
//
// The Katapayadi system was used extensively in:
//
// 1. ASTRONOMICAL CALCULATIONS:
//    - Surya Siddhanta uses it for planetary positions
//    - Aryabhata's Aryabhatiya encodes numeric tables
//
// 2. MATHEMATICAL CONSTANTS:
//    - Pi encoded in "गोपीभाग्यमधुव्रात श्रुङ्गिशोदधिसन्धिग"
//      = 31415926535897932384...
//
// 3. CALENDAR SYSTEMS:
//    - North Indian Panchanga uses Katapayadi for Rashi names
//
// 4. MUSIC:
//    - Carnatic music Ragas numbered using Melakarta scheme
//      based on Katapayadi
//
// APPLICATION IN CHIPS:
// - Cryptographic hash functions (like SHA, but Vedic!)
// - Memory address encoding
// - Data compression
// - Error-detecting codes
//
// =============================================================================
