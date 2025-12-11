/*
 * PANINI GRAMMAR ENGINE - Ashtadhyayi-Inspired Instruction Decoder
 * =================================================================
 * Based on पाणिनि's अष्टाध्यायी (Ashtadhyayi) - 4000 sutras
 * 
 * Panini (c. 500 BCE) created the first formal grammar system.
 * His meta-rules and production rules directly map to:
 * - Formal language theory (Backus-Naur Form)
 * - Compiler design (lexer, parser)
 * - Instruction decoding in processors
 * 
 * Key Concepts:
 * - Pratyahara (प्रत्याहार): Abbreviation rules → Opcode compression
 * - Sandhi (सन्धि): Junction rules → Instruction fusion
 * - Vibhakti (विभक्ति): Case endings → Addressing modes
 * - Dhatu (धातु): Root verbs → Operation codes
 * 
 * Author: SIVAA Project
 * Date: December 2025
 */

module panini_decoder #(
    parameter INSTR_WIDTH = 32,
    parameter OPCODE_WIDTH = 7,
    parameter REG_WIDTH = 5,
    parameter IMM_WIDTH = 12
)(
    input  wire                    clk,
    input  wire                    rst_n,
    
    // Instruction input
    input  wire [INSTR_WIDTH-1:0]  instruction,
    input  wire                    instr_valid,
    
    // Decoded outputs (Panini decomposition)
    output reg  [OPCODE_WIDTH-1:0] dhatu,          // Root operation (धातु)
    output reg  [2:0]              pratyaya,       // Suffix/modifier (प्रत्यय)
    output reg  [REG_WIDTH-1:0]    karta,          // Subject/destination (कर्ता)
    output reg  [REG_WIDTH-1:0]    karma,          // Object/source1 (कर्म)
    output reg  [REG_WIDTH-1:0]    karana,         // Instrument/source2 (करण)
    output reg  [IMM_WIDTH-1:0]    upasarga,       // Prefix/immediate (उपसर्ग)
    output reg  [2:0]              vibhakti,       // Case/addressing mode (विभक्ति)
    output reg  [1:0]              vachana,        // Number/width (वचन)
    output reg  [1:0]              kala,           // Tense/timing (काल)
    
    // Sandhi detection (instruction fusion)
    output reg                     sandhi_possible, // Can fuse with next instr
    output reg  [3:0]              sandhi_type,     // Type of fusion possible
    
    // Decoded instruction type
    output reg  [3:0]              instr_type,
    output reg                     decode_valid
);

    // =========================================================================
    // PRATYAHARA (प्रत्याहार) - Abbreviation System
    // =========================================================================
    // Panini's genius: compress rule sets using first-last notation
    // "अण्" means अ, इ, उ (vowels a, i, u)
    // We use this for opcode grouping
    
    // Opcode groups (like Panini's pratyahara)
    localparam DHATU_ALU   = 7'b0110011;  // R-type ALU
    localparam DHATU_LOAD  = 7'b0000011;  // Load
    localparam DHATU_STORE = 7'b0100011;  // Store
    localparam DHATU_BRANCH = 7'b1100011; // Branch
    localparam DHATU_IMM   = 7'b0010011;  // I-type ALU
    localparam DHATU_LUI   = 7'b0110111;  // Upper immediate
    localparam DHATU_JAL   = 7'b1101111;  // Jump and link
    localparam DHATU_JALR  = 7'b1100111;  // Jump register
    
    // =========================================================================
    // VIBHAKTI (विभक्ति) - Case System → Addressing Modes
    // =========================================================================
    // Sanskrit has 8 cases; we map to addressing modes
    
    localparam VIBH_PRATHAMA = 3'd0;  // Nominative → Register direct
    localparam VIBH_DVITIYA  = 3'd1;  // Accusative → Immediate
    localparam VIBH_TRITIYA  = 3'd2;  // Instrumental → Register indirect
    localparam VIBH_CHATURTHI = 3'd3; // Dative → Base+offset
    localparam VIBH_PANCHAMI = 3'd4;  // Ablative → PC-relative
    localparam VIBH_SHASHTHI = 3'd5;  // Genitive → Indexed
    localparam VIBH_SAPTAMI  = 3'd6;  // Locative → Memory direct
    localparam VIBH_SAMBODHAN = 3'd7; // Vocative → Special/interrupt
    
    // =========================================================================
    // VACHANA (वचन) - Number → Data Width
    // =========================================================================
    
    localparam VACH_EKA = 2'd0;   // Singular → Byte
    localparam VACH_DVI = 2'd1;   // Dual → Half-word
    localparam VACH_BAHU = 2'd2;  // Plural → Word
    localparam VACH_MAHA = 2'd3;  // (Extended) → Double-word
    
    // =========================================================================
    // KALA (काल) - Tense → Execution Timing
    // =========================================================================
    
    localparam KALA_VARTAMANA = 2'd0;  // Present → Execute now
    localparam KALA_BHUTA = 2'd1;      // Past → Use previous result
    localparam KALA_BHAVISHYA = 2'd2;  // Future → Speculative/prefetch
    localparam KALA_AJNATA = 2'd3;     // Unknown → Stall
    
    // =========================================================================
    // INSTRUCTION TYPE (Instr classification)
    // =========================================================================
    
    localparam TYPE_R = 4'd0;    // Register-register
    localparam TYPE_I = 4'd1;    // Immediate
    localparam TYPE_S = 4'd2;    // Store
    localparam TYPE_B = 4'd3;    // Branch
    localparam TYPE_U = 4'd4;    // Upper immediate
    localparam TYPE_J = 4'd5;    // Jump
    localparam TYPE_SANDHI = 4'd6; // Fused instruction
    
    // =========================================================================
    // MAIN DECODER (Ashtadhyayi rule application)
    // =========================================================================
    
    wire [6:0] opcode = instruction[6:0];
    wire [2:0] funct3 = instruction[14:12];
    wire [6:0] funct7 = instruction[31:25];
    wire [4:0] rd = instruction[11:7];
    wire [4:0] rs1 = instruction[19:15];
    wire [4:0] rs2 = instruction[24:20];
    
    // Immediate extraction (different formats)
    wire [11:0] imm_i = instruction[31:20];
    wire [11:0] imm_s = {instruction[31:25], instruction[11:7]};
    wire [12:0] imm_b = {instruction[31], instruction[7], instruction[30:25], instruction[11:8], 1'b0};
    wire [19:0] imm_u = instruction[31:12];
    wire [20:0] imm_j = {instruction[31], instruction[19:12], instruction[20], instruction[30:21], 1'b0};
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dhatu <= 7'd0;
            pratyaya <= 3'd0;
            karta <= 5'd0;
            karma <= 5'd0;
            karana <= 5'd0;
            upasarga <= 12'd0;
            vibhakti <= 3'd0;
            vachana <= 2'd0;
            kala <= 2'd0;
            sandhi_possible <= 1'b0;
            sandhi_type <= 4'd0;
            instr_type <= 4'd0;
            decode_valid <= 1'b0;
        end else if (instr_valid) begin
            // Extract Dhatu (root operation)
            dhatu <= opcode;
            
            // Extract Pratyaya (modifier from funct3/funct7)
            pratyaya <= funct3;
            
            // Karaka analysis (role assignment)
            karta <= rd;      // Destination = subject
            karma <= rs1;     // Source1 = object
            karana <= rs2;    // Source2 = instrument
            
            // Determine Vibhakti (addressing mode)
            case (opcode)
                DHATU_ALU:   vibhakti <= VIBH_PRATHAMA;  // Register direct
                DHATU_IMM:   vibhakti <= VIBH_DVITIYA;   // Immediate
                DHATU_LOAD:  vibhakti <= VIBH_CHATURTHI; // Base+offset
                DHATU_STORE: vibhakti <= VIBH_CHATURTHI; // Base+offset
                DHATU_BRANCH: vibhakti <= VIBH_PANCHAMI; // PC-relative
                DHATU_JAL:   vibhakti <= VIBH_PANCHAMI;  // PC-relative
                default:     vibhakti <= VIBH_PRATHAMA;
            endcase
            
            // Determine Vachana (data width from funct3)
            case (funct3[1:0])
                2'b00: vachana <= VACH_EKA;   // Byte
                2'b01: vachana <= VACH_DVI;   // Half
                2'b10: vachana <= VACH_BAHU;  // Word
                2'b11: vachana <= VACH_MAHA;  // Double
            endcase
            
            // Kala (timing) - for now, present tense
            kala <= KALA_VARTAMANA;
            
            // Extract Upasarga (immediate/prefix)
            case (opcode)
                DHATU_IMM, DHATU_LOAD, DHATU_JALR:
                    upasarga <= imm_i;
                DHATU_STORE:
                    upasarga <= imm_s;
                default:
                    upasarga <= imm_i;
            endcase
            
            // Instruction type classification
            case (opcode)
                DHATU_ALU:    instr_type <= TYPE_R;
                DHATU_IMM:    instr_type <= TYPE_I;
                DHATU_LOAD:   instr_type <= TYPE_I;
                DHATU_STORE:  instr_type <= TYPE_S;
                DHATU_BRANCH: instr_type <= TYPE_B;
                DHATU_LUI:    instr_type <= TYPE_U;
                DHATU_JAL:    instr_type <= TYPE_J;
                default:      instr_type <= TYPE_I;
            endcase
            
            // Sandhi detection (can this fuse with next instruction?)
            // Sandhi = junction rules in Sanskrit phonology
            // In CPU = instruction fusion (like macro-op fusion)
            sandhi_possible <= (opcode == DHATU_IMM && funct3 == 3'b000) || // ADD immediate
                              (opcode == DHATU_LUI);  // LUI can fuse with ADDI
            sandhi_type <= {opcode[3:0]};
            
            decode_valid <= 1'b1;
        end else begin
            decode_valid <= 1'b0;
        end
    end

endmodule

// =============================================================================
// PANINI-TO-RISC-V MAPPING
// =============================================================================
//
// Panini's Ashtadhyayi Structure:
//   Chapter 1-4: Formation rules (morphology)
//   Chapter 5-7: Derivation rules (syntax)
//   Chapter 8: Sandhi rules (phonological junction)
//
// RISC-V Mapping:
//   धातु (Dhatu)      = Opcode (root operation)
//   प्रत्यय (Pratyaya) = Funct3/Funct7 (modifier)
//   कर्ता (Karta)     = rd (destination register)
//   कर्म (Karma)      = rs1 (source register 1)
//   करण (Karana)     = rs2 (source register 2)
//   उपसर्ग (Upasarga) = Immediate (prefix/modifier)
//   विभक्ति (Vibhakti)= Addressing mode (case)
//   वचन (Vachana)    = Data width (singular/dual/plural)
//   काल (Kala)       = Timing (present/past/future)
//   सन्धि (Sandhi)    = Instruction fusion
//
// =============================================================================
