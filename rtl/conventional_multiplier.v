/*
 * ============================================================================
 * CONVENTIONAL MULTIPLIER - For Comparison Benchmarking
 * ============================================================================
 * 
 * Standard array/shift-and-add multiplier implementation
 * Used to compare against Vedic multiplier performance
 * 
 * ============================================================================
 */

// ============================================================================
// STANDARD 8-BIT ARRAY MULTIPLIER
// ============================================================================
// Uses the conventional shift-and-add approach
// Each partial product is generated and accumulated
// ============================================================================

module conventional_8bit_multiplier (
    input  wire [7:0]  a,       // 8-bit multiplicand
    input  wire [7:0]  b,       // 8-bit multiplier
    output wire [15:0] product  // 16-bit product
);
    // Generate all partial products
    wire [7:0] pp0 = b[0] ? a : 8'b0;
    wire [7:0] pp1 = b[1] ? a : 8'b0;
    wire [7:0] pp2 = b[2] ? a : 8'b0;
    wire [7:0] pp3 = b[3] ? a : 8'b0;
    wire [7:0] pp4 = b[4] ? a : 8'b0;
    wire [7:0] pp5 = b[5] ? a : 8'b0;
    wire [7:0] pp6 = b[6] ? a : 8'b0;
    wire [7:0] pp7 = b[7] ? a : 8'b0;
    
    // Shift and add all partial products
    // This creates a long carry chain - the main source of delay
    assign product = {8'b0, pp0} +
                     {7'b0, pp1, 1'b0} +
                     {6'b0, pp2, 2'b0} +
                     {5'b0, pp3, 3'b0} +
                     {4'b0, pp4, 4'b0} +
                     {3'b0, pp5, 5'b0} +
                     {2'b0, pp6, 6'b0} +
                     {1'b0, pp7, 7'b0};

endmodule


// ============================================================================
// STANDARD 4-BIT MULTIPLIER
// ============================================================================

module conventional_4bit_multiplier (
    input  wire [3:0] a,       // 4-bit multiplicand
    input  wire [3:0] b,       // 4-bit multiplier
    output wire [7:0] product  // 8-bit product
);
    wire [3:0] pp0 = b[0] ? a : 4'b0;
    wire [3:0] pp1 = b[1] ? a : 4'b0;
    wire [3:0] pp2 = b[2] ? a : 4'b0;
    wire [3:0] pp3 = b[3] ? a : 4'b0;
    
    assign product = {4'b0, pp0} +
                     {3'b0, pp1, 1'b0} +
                     {2'b0, pp2, 2'b0} +
                     {1'b0, pp3, 3'b0};

endmodule
