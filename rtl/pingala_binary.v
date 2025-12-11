/*
 * PINGALA BINARY SYSTEM - Chhandah Shastra Implementation
 * ========================================================
 * Based on पिंगल's छन्दःशास्त्र (Chhandah Shastra) - c. 300 BCE
 * 
 * Pingala Acharya created the FIRST BINARY SYSTEM:
 * - Laghu (लघु) = Light/Short = 0
 * - Guru (गुरु) = Heavy/Long = 1
 * 
 * Key Concepts:
 * - Meru Prastara (मेरु प्रस्तार) = Pascal's Triangle (1000 years before Pascal!)
 * - Prastaara = Permutation generation
 * - Nashtam = Finding lost pattern
 * - Uddistha = Index from pattern
 * - Sankhya = Count of combinations
 * 
 * Application:
 * - Encryption algorithms
 * - Data compression
 * - Combinatorial logic
 * - Error correction codes
 * 
 * Author: SIVAA Project
 * Date: December 2025
 */

module pingala_binary #(
    parameter DATA_WIDTH = 32,
    parameter MAX_N = 16     // Maximum pattern length
)(
    input  wire                    clk,
    input  wire                    rst_n,
    
    // Operation select
    input  wire [2:0]              operation,
    input  wire [DATA_WIDTH-1:0]   input_data,
    input  wire [3:0]              n_value,    // Pattern length
    input  wire                    start,
    
    // Laghu-Guru pattern I/O
    input  wire [MAX_N-1:0]        laghu_guru_in,  // Binary pattern
    output reg  [MAX_N-1:0]        laghu_guru_out, // Result pattern
    
    // Meru Prastara (Pascal's Triangle) outputs
    output reg  [DATA_WIDTH-1:0]   meru_row [0:MAX_N],  // Row of triangle
    output reg  [DATA_WIDTH-1:0]   binomial_coeff,      // C(n,k)
    
    // Combinatorial outputs
    output reg  [DATA_WIDTH-1:0]   sankhya,      // Count
    output reg  [DATA_WIDTH-1:0]   uddistha,     // Index
    output reg  [DATA_WIDTH-1:0]   nashtam,      // Recovered pattern
    
    // Status
    output reg                     done,
    output reg                     busy
);

    // =========================================================================
    // PINGALA OPERATIONS
    // =========================================================================
    
    localparam OP_PRASTAARA = 3'd0;   // Generate all patterns
    localparam OP_NASHTAM   = 3'd1;   // Recover pattern from index
    localparam OP_UDDISTHA  = 3'd2;   // Get index of pattern
    localparam OP_SANKHYA   = 3'd3;   // Count patterns with k gurus
    localparam OP_MERU      = 3'd4;   // Generate Pascal's Triangle row
    localparam OP_BINOMIAL  = 3'd5;   // Calculate C(n,k)
    localparam OP_LAGHU_SUM = 3'd6;   // Sum using Pingala's method
    
    // =========================================================================
    // STATE MACHINE
    // =========================================================================
    
    localparam IDLE = 2'd0;
    localparam COMPUTE = 2'd1;
    localparam OUTPUT = 2'd2;
    
    reg [1:0] state;
    reg [4:0] iteration;
    
    // Meru Prastara storage (Pascal's Triangle)
    reg [DATA_WIDTH-1:0] meru_triangle [0:MAX_N][0:MAX_N];
    
    // =========================================================================
    // MERU PRASTARA GENERATION (Pascal's Triangle)
    // =========================================================================
    // Pingala's method:
    // Row 0:     1
    // Row 1:    1 1
    // Row 2:   1 2 1
    // Row 3:  1 3 3 1
    // Each entry = sum of two entries above
    
    integer i, j;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            busy <= 1'b0;
            iteration <= 5'd0;
            laghu_guru_out <= 16'd0;
            sankhya <= 32'd0;
            uddistha <= 32'd0;
            nashtam <= 32'd0;
            binomial_coeff <= 32'd0;
            
            // Initialize Meru Prastara
            for (i = 0; i <= MAX_N; i = i + 1) begin
                for (j = 0; j <= MAX_N; j = j + 1) begin
                    meru_triangle[i][j] <= 32'd0;
                end
                meru_row[i] <= 32'd0;
            end
            meru_triangle[0][0] <= 32'd1;
            
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        busy <= 1'b1;
                        state <= COMPUTE;
                        iteration <= 5'd0;
                        
                        // Pre-generate Meru Prastara
                        meru_triangle[0][0] <= 32'd1;
                        for (i = 1; i <= MAX_N; i = i + 1) begin
                            meru_triangle[i][0] <= 32'd1;
                            meru_triangle[i][i] <= 32'd1;
                            for (j = 1; j < i; j = j + 1) begin
                                meru_triangle[i][j] <= meru_triangle[i-1][j-1] + meru_triangle[i-1][j];
                            end
                        end
                    end
                end
                
                COMPUTE: begin
                    case (operation)
                        // =================================================
                        // PRASTAARA - Generate next pattern in sequence
                        // =================================================
                        OP_PRASTAARA: begin
                            // Simply increment the binary pattern
                            laghu_guru_out <= laghu_guru_in + 1;
                            state <= OUTPUT;
                        end
                        
                        // =================================================
                        // NASHTAM - Recover pattern from index
                        // =================================================
                        // Pingala's algorithm: which pattern has index I?
                        OP_NASHTAM: begin
                            // Index to binary pattern
                            nashtam <= input_data;
                            laghu_guru_out <= input_data[MAX_N-1:0];
                            state <= OUTPUT;
                        end
                        
                        // =================================================
                        // UDDISTHA - Get index of given pattern
                        // =================================================
                        // Pingala's algorithm: what is the rank of pattern P?
                        OP_UDDISTHA: begin
                            // Binary pattern to index
                            uddistha <= {16'd0, laghu_guru_in};
                            state <= OUTPUT;
                        end
                        
                        // =================================================
                        // SANKHYA - Count patterns with k Gurus
                        // =================================================
                        // This gives C(n,k) = number of n-bit patterns with k ones
                        OP_SANKHYA: begin
                            // C(n,k) from Meru Prastara
                            sankhya <= meru_triangle[n_value][input_data[3:0]];
                            state <= OUTPUT;
                        end
                        
                        // =================================================
                        // MERU - Generate row of Pascal's Triangle
                        // =================================================
                        OP_MERU: begin
                            for (i = 0; i <= n_value; i = i + 1) begin
                                meru_row[i] <= meru_triangle[n_value][i];
                            end
                            state <= OUTPUT;
                        end
                        
                        // =================================================
                        // BINOMIAL - Calculate C(n,k) directly
                        // =================================================
                        OP_BINOMIAL: begin
                            binomial_coeff <= meru_triangle[n_value][input_data[3:0]];
                            state <= OUTPUT;
                        end
                        
                        // =================================================
                        // LAGHU SUM - Pingala's binary addition
                        // =================================================
                        // Using Laghu-Guru representation
                        OP_LAGHU_SUM: begin
                            // Count number of Guru (1s) in pattern
                            sankhya <= 32'd0;
                            for (i = 0; i < MAX_N; i = i + 1) begin
                                if (laghu_guru_in[i]) begin
                                    sankhya <= sankhya + 1;
                                end
                            end
                            state <= OUTPUT;
                        end
                        
                        default: begin
                            state <= OUTPUT;
                        end
                    endcase
                end
                
                OUTPUT: begin
                    done <= 1'b1;
                    busy <= 1'b0;
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule

// =============================================================================
// PINGALA'S CONTRIBUTIONS (c. 300 BCE)
// =============================================================================
//
// 1. BINARY SYSTEM (Before Leibniz by 2000 years!):
//    Laghu (0) = Short syllable
//    Guru (1) = Long syllable
//
// 2. MERU PRASTARA (Before Pascal by 1800 years!):
//    The triangular array we call "Pascal's Triangle"
//    Each row gives binomial coefficients C(n,k)
//
// 3. FIBONACCI SEQUENCE:
//    Pingala counted "mātrā-vṛttas" (metrical patterns)
//    which follow the Fibonacci recurrence!
//    (Known to Virahanka, then Gopala, then Hemachandra)
//
// 4. BINARY ALGORITHMS:
//    - Prastaara: Enumeration (like binary counting)
//    - Nashtam: Rank-to-pattern (integer to binary)
//    - Uddistha: Pattern-to-rank (binary to integer)
//    - Sankhya: Counting (popcount / Hamming weight)
//
// =============================================================================
