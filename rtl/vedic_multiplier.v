/*
 * ============================================================================
 * VEDIC MATHEMATICS MULTIPLIER - Urdhva Tiryagbhyam Sutra
 * ============================================================================
 * 
 * Implementation of the ancient Vedic multiplication algorithm
 * "Urdhva Tiryagbhyam" meaning "Vertically and Crosswise"
 * 
 * This algorithm achieves multiplication through parallel partial product
 * generation and efficient addition, reducing gate delay compared to
 * conventional array multipliers.
 * 
 * The method works by:
 * 1. Vertical multiplication of corresponding digits
 * 2. Crosswise multiplication of adjacent digits  
 * 3. Parallel addition of partial products
 * 
 * Benefits over conventional multipliers:
 * - 20-45% reduction in delay
 * - Lower power consumption
 * - Reduced gate count
 * - Regular structure suitable for VLSI
 * 
 * Author: Yantra769 Project
 * Date: 2024
 * License: Open Source for Research
 * ============================================================================
 */

// ============================================================================
// 2-BIT VEDIC MULTIPLIER - Base Unit
// ============================================================================
// This is the fundamental building block using Urdhva Tiryagbhyam
// 
// For A = {a1, a0} and B = {b1, b0}:
//
//       a1  a0
//     x b1  b0
//   -----------
//   Step 1: p0 = a0 * b0          (Vertical - rightmost)
//   Step 2: p1 = (a1*b0) + (a0*b1) (Crosswise - middle)
//   Step 3: p2 = a1 * b1          (Vertical - leftmost)
//
//   Result = {p2, p1, p0} with carry propagation
// ============================================================================

module vedic_2bit_multiplier (
    input  wire [1:0] a,      // 2-bit multiplicand
    input  wire [1:0] b,      // 2-bit multiplier
    output wire [3:0] product // 4-bit product
);
    // Internal wires for partial products
    wire p0, p1, p2, p3;      // Individual bit products
    wire c1, c2;              // Carry bits
    wire sum1;                // Intermediate sum
    
    // Step 1: Vertical multiplication (rightmost column)
    // p0 = a0 AND b0
    assign p0 = a[0] & b[0];
    
    // Step 2: Crosswise multiplication (middle column)
    // p1 = (a1 AND b0) XOR (a0 AND b1)
    // c1 = carry from this addition
    assign p1 = a[1] & b[0];
    assign p2 = a[0] & b[1];
    
    // Step 3: Vertical multiplication (leftmost column)
    // p3 = a1 AND b1
    assign p3 = a[1] & b[1];
    
    // Combine using half adders and full adders
    // Product bit 0: direct from p0
    assign product[0] = p0;
    
    // Product bit 1: XOR of crosswise products
    assign sum1 = p1 ^ p2;
    assign product[1] = sum1;
    
    // Generate carry
    assign c1 = p1 & p2;
    
    // Product bit 2: p3 XOR carry
    assign product[2] = p3 ^ c1;
    
    // Product bit 3: carry from bit 2
    assign product[3] = p3 & c1;

endmodule


// ============================================================================
// 4-BIT VEDIC MULTIPLIER - Using 2-bit blocks
// ============================================================================
// Uses four 2-bit Vedic multipliers arranged hierarchically
// 
// For A = {a3,a2,a1,a0} and B = {b3,b2,b1,b0}:
// Split into: A = {AH, AL} where AH = {a3,a2}, AL = {a1,a0}
//             B = {BH, BL} where BH = {b3,b2}, BL = {b1,b0}
//
// Product = (AH * BH) << 4 + (AH * BL + AL * BH) << 2 + (AL * BL)
// ============================================================================

module vedic_4bit_multiplier (
    input  wire [3:0] a,      // 4-bit multiplicand
    input  wire [7:0] b,      // 4-bit multiplier (padded for uniformity)
    output wire [7:0] product // 8-bit product
);
    // Split inputs into high and low parts
    wire [1:0] a_low  = a[1:0];
    wire [1:0] a_high = a[3:2];
    wire [1:0] b_low  = b[1:0];
    wire [1:0] b_high = b[3:2];
    
    // Partial products from 2-bit multipliers
    wire [3:0] pp0;  // AL * BL
    wire [3:0] pp1;  // AH * BL
    wire [3:0] pp2;  // AL * BH
    wire [3:0] pp3;  // AH * BH
    
    // Instantiate four 2-bit Vedic multipliers
    vedic_2bit_multiplier mult0 (.a(a_low),  .b(b_low),  .product(pp0));
    vedic_2bit_multiplier mult1 (.a(a_high), .b(b_low),  .product(pp1));
    vedic_2bit_multiplier mult2 (.a(a_low),  .b(b_high), .product(pp2));
    vedic_2bit_multiplier mult3 (.a(a_high), .b(b_high), .product(pp3));
    
    // Intermediate sums using Ripple Carry Adders
    wire [5:0] sum_stage1;    // pp1 + pp2 (shifted appropriately)
    wire [7:0] sum_stage2;    // Combine all
    
    // Stage 1: Add pp1 and pp2
    // These are cross products that need to be added
    wire [3:0] cross_sum;
    wire       cross_carry;
    
    assign {cross_carry, cross_sum} = pp1 + pp2;
    
    // Stage 2: Combine all partial products
    // product = pp0 + (cross_sum << 2) + (pp3 << 4) + (cross_carry << 6)
    wire [7:0] shifted_cross = {1'b0, cross_carry, cross_sum, 2'b00};
    wire [7:0] shifted_pp3   = {pp3, 4'b0000};
    wire [7:0] extended_pp0  = {4'b0000, pp0};
    
    // Final addition
    assign product = extended_pp0 + {2'b00, cross_sum, 2'b00} + 
                     shifted_pp3 + {1'b0, cross_carry, 6'b000000};

endmodule


// ============================================================================
// 8-BIT VEDIC MULTIPLIER - Cascaded from 4-bit blocks
// ============================================================================
// Same hierarchical approach: use four 4-bit multipliers
// ============================================================================

module vedic_8bit_multiplier (
    input  wire [7:0]  a,       // 8-bit multiplicand
    input  wire [7:0]  b,       // 8-bit multiplier
    output wire [15:0] product  // 16-bit product
);
    // Split into 4-bit halves
    wire [3:0] a_low  = a[3:0];
    wire [3:0] a_high = a[7:4];
    wire [3:0] b_low  = b[3:0];
    wire [3:0] b_high = b[7:4];
    
    // Partial products from 4-bit multipliers
    wire [7:0] pp0, pp1, pp2, pp3;
    
    // Instantiate four 4-bit Vedic multipliers
    vedic_4bit_multiplier mult0 (.a(a_low),  .b({4'b0, b_low}),  .product(pp0));
    vedic_4bit_multiplier mult1 (.a(a_high), .b({4'b0, b_low}),  .product(pp1));
    vedic_4bit_multiplier mult2 (.a(a_low),  .b({4'b0, b_high}), .product(pp2));
    vedic_4bit_multiplier mult3 (.a(a_high), .b({4'b0, b_high}), .product(pp3));
    
    // Combine partial products with proper shifting
    wire [8:0]  cross_sum;
    wire [15:0] final_sum;
    
    // Cross sum of middle products
    assign cross_sum = pp1 + pp2;
    
    // Final combination
    // product = pp0 + (cross_sum << 4) + (pp3 << 8)
    assign final_sum = {8'b0, pp0} + 
                       {3'b0, cross_sum, 4'b0} + 
                       {pp3, 8'b0};
    
    assign product = final_sum;

endmodule


// ============================================================================
// TOP-LEVEL WRAPPER - Configurable Vedic Multiplier
// ============================================================================

module yantra_vedic_multiplier #(
    parameter WIDTH = 8  // 2, 4, or 8
)(
    input  wire [WIDTH-1:0]     a,
    input  wire [WIDTH-1:0]     b,
    output wire [2*WIDTH-1:0]   product
);
    generate
        if (WIDTH == 2) begin : gen_2bit
            vedic_2bit_multiplier mult (
                .a(a),
                .b(b),
                .product(product)
            );
        end
        else if (WIDTH == 4) begin : gen_4bit
            vedic_4bit_multiplier mult (
                .a(a),
                .b({4'b0, b}),
                .product(product)
            );
        end
        else if (WIDTH == 8) begin : gen_8bit
            vedic_8bit_multiplier mult (
                .a(a),
                .b(b),
                .product(product)
            );
        end
    endgenerate

endmodule
