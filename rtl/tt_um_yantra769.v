/*
 * ============================================================================
 * TINYTAPEOUT WRAPPER - For Real Silicon Fabrication
 * ============================================================================
 * 
 * This wrapper makes the Yantra Vedic ALU compatible with:
 * - TinyTapeout (https://tinytapeout.com) - $500 for real silicon
 * - Efabless Caravel (https://efabless.com) - Open source ASIC
 * - SkyWater 130nm PDK - Open source process
 * 
 * TinyTapeout interface:
 * - 8 input pins (directly directly directly directly directly directly directly directly directly)
 * - 8 output pins
 * - 8 bidirectional pins
 * 
 * ============================================================================
 */

`default_nettype none
`timescale 1ns / 1ps

module tt_um_yantra769 (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // Bidirectional input path
    output wire [7:0] uio_out,  // Bidirectional output path
    output wire [7:0] uio_oe,   // Bidirectional enable (1=output)
    input  wire       ena,      // Enable signal
    input  wire       clk,      // Clock
    input  wire       rst_n     // Active-low reset
);
    // ========================================================================
    // Register Interface
    // ========================================================================
    // ui_in[7:4] = opcode
    // ui_in[3:0] = control
    // uio_in[7:0] = operand select / data input
    
    reg [7:0] operand_a_reg;
    reg [7:0] operand_b_reg;
    reg [3:0] opcode_reg;
    reg [15:0] result_reg;
    
    wire [7:0] mult_result_low;
    wire [7:0] mult_result_high;
    
    // State machine for loading operands
    reg [1:0] state;
    localparam IDLE    = 2'b00;
    localparam LOAD_A  = 2'b01;
    localparam LOAD_B  = 2'b10;
    localparam EXECUTE = 2'b11;
    
    // ========================================================================
    // 8-bit Vedic Multiplier Instance
    // ========================================================================
    wire [15:0] vedic_product;
    
    vedic_mult_8bit_tt vedic_mult (
        .a(operand_a_reg),
        .b(operand_b_reg),
        .p(vedic_product)
    );
    
    // ========================================================================
    // Control Logic
    // ========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            operand_a_reg <= 8'b0;
            operand_b_reg <= 8'b0;
            opcode_reg <= 4'b0;
            result_reg <= 16'b0;
        end else if (ena) begin
            opcode_reg <= ui_in[7:4];
            
            case (ui_in[1:0])
                2'b01: operand_a_reg <= uio_in;  // Load A
                2'b10: operand_b_reg <= uio_in;  // Load B
                2'b11: begin                      // Execute
                    case (ui_in[7:4])
                        4'b0000: result_reg <= {8'b0, operand_a_reg} + {8'b0, operand_b_reg}; // ADD
                        4'b0001: result_reg <= {8'b0, operand_a_reg} - {8'b0, operand_b_reg}; // SUB
                        4'b0010: result_reg <= vedic_product;                                 // VEDIC MUL
                        4'b0011: result_reg <= {8'b0, operand_a_reg & operand_b_reg};        // AND
                        4'b0100: result_reg <= {8'b0, operand_a_reg | operand_b_reg};        // OR
                        4'b0101: result_reg <= {8'b0, operand_a_reg ^ operand_b_reg};        // XOR
                        default: result_reg <= 16'b0;
                    endcase
                end
                default: ; // Hold
            endcase
        end
    end
    
    // ========================================================================
    // Output Assignment
    // ========================================================================
    assign uo_out = ui_in[2] ? result_reg[15:8] : result_reg[7:0];
    
    // Bidirectional pins as outputs showing status
    assign uio_out = {4'b0, opcode_reg};
    assign uio_oe  = 8'b11110000;  // Upper 4 bits as output

endmodule

// ============================================================================
// Compact 8-bit Vedic Multiplier for TinyTapeout
// ============================================================================
module vedic_mult_8bit_tt (
    input  wire [7:0] a,
    input  wire [7:0] b,
    output wire [15:0] p
);
    // Using same hierarchical Urdhva Tiryagbhyam
    wire [3:0] p00, p01, p10, p11;
    wire [7:0] pp0, pp1, pp2, pp3;
    
    // 2x2 bit multiplications
    assign p00 = {2'b0, a[1:0]} * {2'b0, b[1:0]};
    assign p01 = {2'b0, a[3:2]} * {2'b0, b[1:0]};
    assign p10 = {2'b0, a[1:0]} * {2'b0, b[3:2]};
    assign p11 = {2'b0, a[3:2]} * {2'b0, b[3:2]};
    
    // First level combination
    wire [7:0] low_half, high_half;
    assign low_half = {4'b0, p00} + ({4'b0, p01} << 2) + ({4'b0, p10} << 2) + ({4'b0, p11} << 4);
    
    // Upper 4x4 bits
    wire [3:0] q00, q01, q10, q11;
    assign q00 = {2'b0, a[5:4]} * {2'b0, b[5:4]};
    assign q01 = {2'b0, a[7:6]} * {2'b0, b[5:4]};
    assign q10 = {2'b0, a[5:4]} * {2'b0, b[7:6]};
    assign q11 = {2'b0, a[7:6]} * {2'b0, b[7:6]};
    
    assign high_half = {4'b0, q00} + ({4'b0, q01} << 2) + ({4'b0, q10} << 2) + ({4'b0, q11} << 4);
    
    // Cross terms
    wire [7:0] cross1 = a[3:0] * b[7:4];
    wire [7:0] cross2 = a[7:4] * b[3:0];
    
    // Final combination
    assign p = {8'b0, low_half} + ({8'b0, cross1} << 4) + ({8'b0, cross2} << 4) + ({high_half, 8'b0});

endmodule

`default_nettype wire
