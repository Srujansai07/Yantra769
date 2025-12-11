/*
 * MARMA ROUTER - 18 CRITICAL PATH NODES
 * ======================================
 * Based on मर्म स्थान (Marma Points) from Ayurveda
 * 
 * In Ayurveda, 107 Marma points exist in the body.
 * 18 are most critical - mapped to chip routing priorities.
 * 
 * Marma = "that which can cause death if injured"
 * In chip design = critical paths that affect timing closure
 * 
 * Priority Levels:
 * - Maximum (Bindu center): ALU output, Branch predictor
 * - High (L1 ring): Cache hit, Instruction fetch
 * - Medium (L2/L3): Memory controllers
 * - Low (I/O ring): PHY, Serializer
 * 
 * Author: SIVAA Project
 * Date: December 2025
 */

module marma_router #(
    parameter DATA_WIDTH = 64,
    parameter ADDR_WIDTH = 32,
    parameter NUM_MARMA_POINTS = 18
)(
    input  wire                    clk,
    input  wire                    rst_n,
    
    // Request interface
    input  wire                    req_valid,
    input  wire [4:0]              req_marma_id,    // Which Marma point
    input  wire [ADDR_WIDTH-1:0]   req_addr,
    input  wire [DATA_WIDTH-1:0]   req_data,
    input  wire                    req_write,
    
    // Response interface
    output reg                     resp_valid,
    output reg  [DATA_WIDTH-1:0]   resp_data,
    output reg  [3:0]              resp_latency,
    
    // Priority arbitration outputs
    output wire [17:0]             marma_active,
    output wire [3:0]              current_priority,
    
    // Timing constraint outputs (for synthesis)
    output wire [7:0]              critical_slack
);

    // =========================================================================
    // 18 MARMA POINTS DEFINITION
    // Based on Ayurvedic mapping to chip architecture
    // =========================================================================
    
    // Marma IDs
    localparam MARMA_ALU_OUT       = 5'd0;   // Bindu - Maximum priority
    localparam MARMA_BRANCH_PRED   = 5'd1;   // Bindu - Maximum priority
    localparam MARMA_L1_HIT        = 5'd2;   // L1 Ring - High
    localparam MARMA_INSTR_FETCH   = 5'd3;   // L1 Ring - High
    localparam MARMA_DATA_ALIGN    = 5'd4;   // L1 Ring - High
    localparam MARMA_L2_CTRL       = 5'd5;   // L2 Ring - High
    localparam MARMA_TLB_LOOKUP    = 5'd6;   // L2 Ring - High
    localparam MARMA_COHERENCY     = 5'd7;   // L2 Ring - High
    localparam MARMA_L3_ARBITER    = 5'd8;   // L3 Ring - Medium
    localparam MARMA_WRITE_BUF     = 5'd9;   // L3 Ring - Medium
    localparam MARMA_PREFETCH      = 5'd10;  // L3 Ring - Medium
    localparam MARMA_DRAM_CTRL     = 5'd11;  // Memory Ring - Medium
    localparam MARMA_REFRESH       = 5'd12;  // Memory Ring - Medium
    localparam MARMA_ECC           = 5'd13;  // Memory Ring - Medium
    localparam MARMA_PHY           = 5'd14;  // I/O Ring - Low
    localparam MARMA_SERIALIZER    = 5'd15;  // I/O Ring - Low
    localparam MARMA_CLK_RECOVERY  = 5'd16;  // I/O Ring - Low
    localparam MARMA_GROUND        = 5'd17;  // Outer - Lowest
    
    // Priority levels (higher = more critical)
    localparam PRIO_MAXIMUM = 4'd10;
    localparam PRIO_HIGH    = 4'd8;
    localparam PRIO_MEDIUM  = 4'd5;
    localparam PRIO_LOW     = 4'd2;
    localparam PRIO_LOWEST  = 4'd1;
    
    // Latency for each ring (in cycles)
    localparam LAT_BINDU   = 4'd1;
    localparam LAT_L1      = 4'd2;
    localparam LAT_L2      = 4'd4;
    localparam LAT_L3      = 4'd8;
    localparam LAT_MEMORY  = 4'd12;
    localparam LAT_IO      = 4'd15;
    
    // =========================================================================
    // MARMA PRIORITY LOOKUP TABLE
    // =========================================================================
    
    function [3:0] get_priority;
        input [4:0] marma_id;
        begin
            case (marma_id)
                MARMA_ALU_OUT, MARMA_BRANCH_PRED:
                    get_priority = PRIO_MAXIMUM;
                MARMA_L1_HIT, MARMA_INSTR_FETCH, MARMA_DATA_ALIGN,
                MARMA_L2_CTRL, MARMA_TLB_LOOKUP, MARMA_COHERENCY:
                    get_priority = PRIO_HIGH;
                MARMA_L3_ARBITER, MARMA_WRITE_BUF, MARMA_PREFETCH,
                MARMA_DRAM_CTRL, MARMA_REFRESH, MARMA_ECC:
                    get_priority = PRIO_MEDIUM;
                MARMA_PHY, MARMA_SERIALIZER, MARMA_CLK_RECOVERY:
                    get_priority = PRIO_LOW;
                default:
                    get_priority = PRIO_LOWEST;
            endcase
        end
    endfunction
    
    function [3:0] get_latency;
        input [4:0] marma_id;
        begin
            case (marma_id)
                MARMA_ALU_OUT, MARMA_BRANCH_PRED:
                    get_latency = LAT_BINDU;
                MARMA_L1_HIT, MARMA_INSTR_FETCH, MARMA_DATA_ALIGN:
                    get_latency = LAT_L1;
                MARMA_L2_CTRL, MARMA_TLB_LOOKUP, MARMA_COHERENCY:
                    get_latency = LAT_L2;
                MARMA_L3_ARBITER, MARMA_WRITE_BUF, MARMA_PREFETCH:
                    get_latency = LAT_L3;
                MARMA_DRAM_CTRL, MARMA_REFRESH, MARMA_ECC:
                    get_latency = LAT_MEMORY;
                default:
                    get_latency = LAT_IO;
            endcase
        end
    endfunction
    
    // =========================================================================
    // MARMA ACTIVITY TRACKING
    // =========================================================================
    
    reg [17:0] marma_activity_reg;
    reg [3:0] current_prio_reg;
    reg [3:0] latency_counter;
    reg [4:0] active_marma;
    
    assign marma_active = marma_activity_reg;
    assign current_priority = current_prio_reg;
    
    // State machine
    localparam IDLE = 2'd0;
    localparam ROUTE = 2'd1;
    localparam WAIT = 2'd2;
    localparam COMPLETE = 2'd3;
    
    reg [1:0] state;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            resp_valid <= 1'b0;
            resp_data <= 64'd0;
            resp_latency <= 4'd0;
            marma_activity_reg <= 18'd0;
            current_prio_reg <= 4'd0;
            latency_counter <= 4'd0;
            active_marma <= 5'd0;
        end else begin
            case (state)
                IDLE: begin
                    resp_valid <= 1'b0;
                    if (req_valid && req_marma_id < NUM_MARMA_POINTS) begin
                        state <= ROUTE;
                        active_marma <= req_marma_id;
                        current_prio_reg <= get_priority(req_marma_id);
                        latency_counter <= get_latency(req_marma_id);
                        marma_activity_reg[req_marma_id] <= 1'b1;
                    end
                end
                
                ROUTE: begin
                    // Priority-based routing (higher priority = less delay)
                    // In real implementation, this would affect physical routing
                    state <= WAIT;
                end
                
                WAIT: begin
                    if (latency_counter > 0) begin
                        latency_counter <= latency_counter - 1;
                    end else begin
                        state <= COMPLETE;
                    end
                end
                
                COMPLETE: begin
                    resp_valid <= 1'b1;
                    resp_data <= req_data;  // Echo for now
                    resp_latency <= get_latency(active_marma);
                    marma_activity_reg[active_marma] <= 1'b0;
                    state <= IDLE;
                end
            endcase
        end
    end
    
    // =========================================================================
    // CRITICAL SLACK CALCULATION
    // For synthesis - higher priority Marma points get tighter timing
    // =========================================================================
    
    // Slack = 100 - (priority * 10)
    // Bindu (priority 10) → slack = 0 (tightest timing)
    // I/O (priority 2) → slack = 80 (relaxed timing)
    assign critical_slack = 8'd100 - (current_prio_reg * 8'd10);

endmodule

// =============================================================================
// MARMA POINT CORRESPONDENCE (Ayurveda → Chip)
// =============================================================================
//
// Adhipati (Head crown)      → ALU output / Branch predictor
// Sthapani (Third eye)       → L1 hit/miss detection
// Shankha (Temple)           → Instruction fetch
// Krikatika (Neck joint)     → Data alignment
// Hridaya (Heart)            → L2 controller
// Nabhi (Navel)              → TLB lookup
// Basti (Bladder)            → Coherency checker
// Kshipra (Toe/finger web)   → L3 arbiter
// Talahridaya (Palm center)  → Write buffer
// Kurcha (Arch of foot)      → Prefetch engine
// Kurpara (Elbow)            → DRAM controller
// Ani (Knee)                 → Refresh logic
// Urvi (Thigh)               → ECC encoder
// Lohitaksha (Wrist/ankle)   → PHY interface
// Indrabasti (Mid-forearm)   → Serializer
// Gulpha (Ankle)             → Clock recovery
// Janu (Knee cap)            → Ground reference
//
// =============================================================================
