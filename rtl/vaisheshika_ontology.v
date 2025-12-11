/*
 * VAISHESHIKA ONTOLOGY ENGINE - Category-Based Processing
 * =========================================================
 * Based on वैशेषिक दर्शन (Vaisheshika Philosophy) by Kanada
 * 
 * Vaisheshika defines 7 Padarthas (categories of reality):
 * 1. Dravya (द्रव्य) - Substance → Data types
 * 2. Guna (गुण) - Quality → Attributes
 * 3. Karma (कर्म) - Action → Operations
 * 4. Samanya (सामान्य) - Universal → Type classes
 * 5. Vishesha (विशेष) - Particular → Instances
 * 6. Samavaya (समवाय) - Inherence → Relationships
 * 7. Abhava (अभाव) - Absence → Null/void handling
 * 
 * Atomic Theory:
 * Kanada (c. 600 BCE) proposed paramanu (atoms) as the
 * smallest indivisible units - directly applicable to
 * atomic operations in computing!
 * 
 * Author: SIVAA Project
 * Date: December 2025
 */

module vaisheshika_ontology #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 16,
    parameter NUM_SUBSTANCES = 16
)(
    input  wire                    clk,
    input  wire                    rst_n,
    
    // Object input
    input  wire [DATA_WIDTH-1:0]   object_data,
    input  wire [7:0]              object_id,
    input  wire                    object_valid,
    
    // Category classification outputs
    output reg  [2:0]              padartha,       // 7 categories
    output reg  [3:0]              dravya_type,    // Substance type
    output reg  [7:0]              guna_attributes, // Quality bits
    output reg  [3:0]              karma_action,   // Action type
    output reg  [7:0]              samanya_class,  // Universal class
    output reg  [7:0]              vishesha_id,    // Particular ID
    output reg  [7:0]              samavaya_ref,   // Inherence ref
    output reg                     abhava_null,    // Absence flag
    
    // Atomic operation support
    output reg                     paramanu_lock,  // Atomic lock
    output reg                     paramanu_done,  // Atomic complete
    
    // Classification status
    output reg                     classified,
    output reg  [3:0]              certainty       // Classification confidence
);

    // =========================================================================
    // SAPTA PADARTHA (सप्त पदार्थ) - Seven Categories
    // =========================================================================
    
    localparam PAD_DRAVYA   = 3'd0;  // Substance
    localparam PAD_GUNA     = 3'd1;  // Quality
    localparam PAD_KARMA    = 3'd2;  // Action
    localparam PAD_SAMANYA  = 3'd3;  // Universal
    localparam PAD_VISHESHA = 3'd4;  // Particular
    localparam PAD_SAMAVAYA = 3'd5;  // Inherence
    localparam PAD_ABHAVA   = 3'd6;  // Absence
    
    // =========================================================================
    // NAVA DRAVYA (नव द्रव्य) - Nine Substances
    // =========================================================================
    // Vaisheshika lists 9 eternal substances
    
    localparam DRAV_PRITHVI = 4'd0;  // Earth → Solid data (struct)
    localparam DRAV_JALA    = 4'd1;  // Water → Fluid data (stream)
    localparam DRAV_TEJAS   = 4'd2;  // Fire → Energy (power state)
    localparam DRAV_VAYU    = 4'd3;  // Air → Signal (bus)
    localparam DRAV_AKASHA  = 4'd4;  // Ether → Space (memory)
    localparam DRAV_KALA    = 4'd5;  // Time → Clock/timing
    localparam DRAV_DIK     = 4'd6;  // Space → Address
    localparam DRAV_ATMAN   = 4'd7;  // Soul → Process/thread
    localparam DRAV_MANAS   = 4'd8;  // Mind → Controller
    
    // =========================================================================
    // 24 GUNA (चतुर्विंशति गुण) - 24 Qualities
    // =========================================================================
    // Simplified to 8 bits for hardware
    
    localparam GUNA_RUPA    = 8'b0000_0001;  // Form/shape
    localparam GUNA_RASA    = 8'b0000_0010;  // Taste/flavor (type)
    localparam GUNA_GANDHA  = 8'b0000_0100;  // Smell (signature)
    localparam GUNA_SPARSHA = 8'b0000_1000;  // Touch (interface)
    localparam GUNA_SHABDA  = 8'b0001_0000;  // Sound (signal)
    localparam GUNA_SANKHYA = 8'b0010_0000;  // Number (count)
    localparam GUNA_PARIMANA = 8'b0100_0000; // Measure (size)
    localparam GUNA_PRITHAKTVA = 8'b1000_0000; // Separateness (unique)
    
    // =========================================================================
    // PANCHA KARMA (पञ्च कर्म) - Five Actions
    // =========================================================================
    
    localparam KARMA_UTKSHEPANA = 4'd0;  // Throwing up → Write
    localparam KARMA_APAKSHEPANA = 4'd1; // Throwing down → Read
    localparam KARMA_AKUNCHANA = 4'd2;   // Contraction → Compress
    localparam KARMA_PRASARANA = 4'd3;   // Expansion → Decompress
    localparam KARMA_GAMANA = 4'd4;      // Motion → Transfer
    
    // =========================================================================
    // CLASSIFICATION STATE MACHINE
    // =========================================================================
    
    localparam IDLE = 2'd0;
    localparam ANALYZE = 2'd1;
    localparam CLASSIFY = 2'd2;
    localparam OUTPUT = 2'd3;
    
    reg [1:0] state;
    
    // Substance memory (9 types tracked)
    reg [DATA_WIDTH-1:0] substance_store [0:NUM_SUBSTANCES-1];
    reg [3:0] substance_type [0:NUM_SUBSTANCES-1];
    reg [NUM_SUBSTANCES-1:0] substance_valid;
    
    // Atomic operation support (Paramanu)
    reg atomic_in_progress;
    reg [7:0] atomic_id;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            padartha <= PAD_ABHAVA;
            dravya_type <= 4'd0;
            guna_attributes <= 8'd0;
            karma_action <= 4'd0;
            samanya_class <= 8'd0;
            vishesha_id <= 8'd0;
            samavaya_ref <= 8'd0;
            abhava_null <= 1'b1;
            paramanu_lock <= 1'b0;
            paramanu_done <= 1'b0;
            classified <= 1'b0;
            certainty <= 4'd0;
            atomic_in_progress <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    classified <= 1'b0;
                    paramanu_done <= 1'b0;
                    
                    if (object_valid) begin
                        state <= ANALYZE;
                        vishesha_id <= object_id;
                    end
                end
                
                ANALYZE: begin
                    // Analyze object to determine Padartha
                    
                    // Check for Abhava (absence/null)
                    if (object_data == 32'd0) begin
                        padartha <= PAD_ABHAVA;
                        abhava_null <= 1'b1;
                        certainty <= 4'd15;  // 100% certain
                    end
                    // Check for Dravya (substance) patterns
                    else if (object_data[31:28] == 4'hD) begin
                        padartha <= PAD_DRAVYA;
                        abhava_null <= 1'b0;
                        
                        // Classify substance type
                        case (object_data[27:24])
                            4'h0: dravya_type <= DRAV_PRITHVI;
                            4'h1: dravya_type <= DRAV_JALA;
                            4'h2: dravya_type <= DRAV_TEJAS;
                            4'h3: dravya_type <= DRAV_VAYU;
                            4'h4: dravya_type <= DRAV_AKASHA;
                            4'h5: dravya_type <= DRAV_KALA;
                            4'h6: dravya_type <= DRAV_DIK;
                            4'h7: dravya_type <= DRAV_ATMAN;
                            default: dravya_type <= DRAV_MANAS;
                        endcase
                        certainty <= 4'd12;
                    end
                    // Check for Guna (quality)
                    else if (object_data[31:28] == 4'hC) begin
                        padartha <= PAD_GUNA;
                        guna_attributes <= object_data[7:0];
                        certainty <= 4'd10;
                    end
                    // Check for Karma (action)
                    else if (object_data[31:28] == 4'hA) begin
                        padartha <= PAD_KARMA;
                        karma_action <= object_data[3:0];
                        certainty <= 4'd14;
                    end
                    // Check for Samanya (universal/class)
                    else if (object_data[31:28] == 4'hB) begin
                        padartha <= PAD_SAMANYA;
                        samanya_class <= object_data[7:0];
                        certainty <= 4'd8;
                    end
                    // Check for Samavaya (inherence/relationship)
                    else if (object_data[31:28] == 4'hE) begin
                        padartha <= PAD_SAMAVAYA;
                        samavaya_ref <= object_data[7:0];
                        certainty <= 4'd11;
                    end
                    // Default to Vishesha (particular instance)
                    else begin
                        padartha <= PAD_VISHESHA;
                        certainty <= 4'd6;
                    end
                    
                    abhava_null <= 1'b0;
                    state <= CLASSIFY;
                end
                
                CLASSIFY: begin
                    // Store in ontology database
                    if (padartha == PAD_DRAVYA && !substance_valid[object_id[3:0]]) begin
                        substance_store[object_id[3:0]] <= object_data;
                        substance_type[object_id[3:0]] <= dravya_type;
                        substance_valid[object_id[3:0]] <= 1'b1;
                    end
                    
                    state <= OUTPUT;
                end
                
                OUTPUT: begin
                    classified <= 1'b1;
                    state <= IDLE;
                end
            endcase
            
            // Paramanu (Atomic) operation handling
            if (object_valid && object_data[31:28] == 4'hF) begin
                // Atomic operation requested
                if (!atomic_in_progress) begin
                    paramanu_lock <= 1'b1;
                    atomic_in_progress <= 1'b1;
                    atomic_id <= object_id;
                end
            end else if (atomic_in_progress && object_id == atomic_id) begin
                // Complete atomic operation
                paramanu_lock <= 1'b0;
                paramanu_done <= 1'b1;
                atomic_in_progress <= 1'b0;
            end
        end
    end
    
    // Initialize substance storage
    integer i;
    initial begin
        for (i = 0; i < NUM_SUBSTANCES; i = i + 1) begin
            substance_store[i] = 32'd0;
            substance_type[i] = 4'd0;
        end
        substance_valid = {NUM_SUBSTANCES{1'b0}};
    end

endmodule

// =============================================================================
// VAISHESHIKA PHILOSOPHY MAPPING
// =============================================================================
//
// Kanada's Atomic Theory (c. 600 BCE):
// - Paramanu (परमाणु) = indivisible atom
// - Dvyanuka = 2-atom molecule  
// - Tryanuka = 3-atom molecule (smallest visible)
//
// Computing Parallel:
// - Paramanu = Atomic memory operation (compare-and-swap)
// - Dvyanuka = 2-operand instruction
// - Tryanuka = 3-operand instruction (visible result)
//
// Seven Padarthas → Computing Categories:
// 1. Dravya (Substance) → Data types (int, float, struct)
// 2. Guna (Quality) → Attributes (const, volatile, signed)
// 3. Karma (Action) → Operations (add, mul, load, store)
// 4. Samanya (Universal) → Type classes (Number, Iterator)
// 5. Vishesha (Particular) → Object instances
// 6. Samavaya (Inherence) → Relationships (inheritance, composition)
// 7. Abhava (Absence) → Null, void, undefined
//
// =============================================================================
