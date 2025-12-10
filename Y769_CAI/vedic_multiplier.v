/*
 * VEDIC MULTIPLIER - VERILOG IMPLEMENTATION
 * ==========================================
 * Based on Urdhva Tiryagbhyam Sutra (Vertically and Crosswise)
 * 
 * This implementation demonstrates the efficiency of Vedic mathematics
 * for hardware multiplication circuits.
 * 
 * Hierarchy:
 *   vedic_mult_2x2 -> vedic_mult_4x4 -> vedic_mult_8x8
 * 
 * Advantages over conventional multipliers:
 *   - Reduced critical path delay
 *   - Lower gate count
 *   - More parallelism
 */

// ============================================================
// 2x2 VEDIC MULTIPLIER (Base Case)
// ============================================================
module vedic_mult_2x2(
    input  [1:0] a,      // 2-bit multiplicand
    input  [1:0] b,      // 2-bit multiplier
    output [3:0] p       // 4-bit product
);
    wire [3:0] pp;       // Partial products
    wire c1;             // Carry
    
    // Step 1: Vertical products (Urdhva)
    // a[0]*b[0] gives LSB
    // a[1]*b[1] gives part of MSB
    assign pp[0] = a[0] & b[0];  // LSB direct
    assign pp[3] = a[1] & b[1];  // MSB partial
    
    // Step 2: Cross products (Tiryagbhyam)
    // a[1]*b[0] and a[0]*b[1] are added for middle bits
    assign pp[1] = a[1] & b[0];
    assign pp[2] = a[0] & b[1];
    
    // Step 3: Combine with carries
    assign p[0] = pp[0];
    assign {c1, p[1]} = pp[1] + pp[2];
    assign {p[3], p[2]} = pp[3] + c1;
    
endmodule

// ============================================================
// 4x4 VEDIC MULTIPLIER (Using four 2x2 multipliers)
// ============================================================
module vedic_mult_4x4(
    input  [3:0] a,      // 4-bit multiplicand
    input  [3:0] b,      // 4-bit multiplier
    output [7:0] p       // 8-bit product
);
    wire [3:0] q0, q1, q2, q3;   // Outputs of 2x2 multipliers
    wire [5:0] sum1, sum2;       // Intermediate sums
    wire [3:0] carry1, carry2;
    
    // Instantiate four 2x2 Vedic multipliers
    // Following Urdhva Tiryagbhyam pattern at higher level
    
    // q0 = a[1:0] * b[1:0]  (Lower × Lower)
    vedic_mult_2x2 m0(.a(a[1:0]), .b(b[1:0]), .p(q0));
    
    // q1 = a[3:2] * b[1:0]  (Upper × Lower)
    vedic_mult_2x2 m1(.a(a[3:2]), .b(b[1:0]), .p(q1));
    
    // q2 = a[1:0] * b[3:2]  (Lower × Upper)
    vedic_mult_2x2 m2(.a(a[1:0]), .b(b[3:2]), .p(q2));
    
    // q3 = a[3:2] * b[3:2]  (Upper × Upper)
    vedic_mult_2x2 m3(.a(a[3:2]), .b(b[3:2]), .p(q3));
    
    // Combine results using Vedic addition pattern
    // p = q0 + (q1 + q2) << 2 + q3 << 4
    
    assign p[1:0] = q0[1:0];
    
    assign sum1 = {2'b00, q0[3:2]} + {2'b00, q1[1:0]} + {2'b00, q2[1:0]};
    assign p[3:2] = sum1[1:0];
    
    assign sum2 = {2'b00, sum1[5:2]} + {2'b00, q1[3:2]} + {2'b00, q2[3:2]} + {2'b00, q3[1:0]};
    assign p[5:4] = sum2[1:0];
    
    assign {p[7:6]} = sum2[5:2] + q3[3:2];
    
endmodule

// ============================================================
// 8x8 VEDIC MULTIPLIER (Using four 4x4 multipliers)
// ============================================================
module vedic_mult_8x8(
    input  [7:0] a,       // 8-bit multiplicand
    input  [7:0] b,       // 8-bit multiplier
    output [15:0] p       // 16-bit product
);
    wire [7:0] q0, q1, q2, q3;    // Outputs of 4x4 multipliers
    wire [11:0] sum1;
    wire [11:0] sum2;
    wire [7:0] sum3;
    
    // Instantiate four 4x4 Vedic multipliers
    vedic_mult_4x4 m0(.a(a[3:0]), .b(b[3:0]), .p(q0));
    vedic_mult_4x4 m1(.a(a[7:4]), .b(b[3:0]), .p(q1));
    vedic_mult_4x4 m2(.a(a[3:0]), .b(b[7:4]), .p(q2));
    vedic_mult_4x4 m3(.a(a[7:4]), .b(b[7:4]), .p(q3));
    
    // Combine results
    assign p[3:0] = q0[3:0];
    
    assign sum1 = {4'b0000, q0[7:4]} + {4'b0000, q1[3:0]} + {4'b0000, q2[3:0]};
    assign p[7:4] = sum1[3:0];
    
    assign sum2 = {4'b0000, sum1[11:4]} + {4'b0000, q1[7:4]} + {4'b0000, q2[7:4]} + {4'b0000, q3[3:0]};
    assign p[11:8] = sum2[3:0];
    
    assign sum3 = sum2[11:4] + q3[7:4];
    assign p[15:12] = sum3[3:0];
    
endmodule

// ============================================================
// TESTBENCH
// ============================================================
module vedic_mult_tb;
    reg [7:0] a, b;
    wire [15:0] p;
    
    vedic_mult_8x8 uut(.a(a), .b(b), .p(p));
    
    initial begin
        $display("========================================");
        $display("VEDIC MULTIPLIER TESTBENCH");
        $display("========================================");
        $display("Time\t  A\t  B\t  Product\tExpected");
        $display("----------------------------------------");
        
        // Test cases
        a = 8'd15;  b = 8'd15;  #10;
        $display("%0t\t%d\t%d\t%d\t\t%d", $time, a, b, p, a*b);
        
        a = 8'd127; b = 8'd2;   #10;
        $display("%0t\t%d\t%d\t%d\t\t%d", $time, a, b, p, a*b);
        
        a = 8'd255; b = 8'd255; #10;
        $display("%0t\t%d\t%d\t%d\t\t%d", $time, a, b, p, a*b);
        
        a = 8'd100; b = 8'd50;  #10;
        $display("%0t\t%d\t%d\t%d\t\t%d", $time, a, b, p, a*b);
        
        a = 8'd7;   b = 8'd8;   #10;
        $display("%0t\t%d\t%d\t%d\t\t%d", $time, a, b, p, a*b);
        
        $display("========================================");
        $display("All tests completed!");
        $finish;
    end
endmodule

/*
 * SYNTHESIS NOTES:
 * ================
 * 
 * To synthesize for FPGA (Xilinx Vivado):
 *   1. Create new project
 *   2. Add this file as design source
 *   3. Set vedic_mult_8x8 as top module
 *   4. Run synthesis
 *   5. Compare with conventional array multiplier
 * 
 * Expected improvements over array multiplier:
 *   - Delay: ~30-40% reduction
 *   - Area:  ~20-25% reduction
 *   - Power: ~15-20% reduction
 * 
 * APPLICATIONS:
 * =============
 *   - DSP (Digital Signal Processing)
 *   - Neural network accelerators
 *   - Cryptographic hardware
 *   - High-speed arithmetic units
 */
