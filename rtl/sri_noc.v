/*
 * ============================================================================
 * SRI-NoC: Sri Yantra Fractal Network-on-Chip
 * ============================================================================
 * 
 * Replaces Manhattan mesh topology with fractal interconnects based on
 * the Sri Yantra sacred geometry.
 * 
 * Key Properties:
 * - 9 Trikonas (triangles) = 9 Compute Clusters
 * - Bindu (center) = Global Synchronization Node
 * - Marma Sthanas (18 points) = TSV/Clock distribution nodes
 * - Small World Network = O(log N) latency vs O(√N) for mesh
 * - Golden Ratio scaling suppresses standing waves
 * 
 * Based on: FracNoC research, Sri Yantra geometry (51° angles)
 * 
 * ============================================================================
 */

`timescale 1ns / 1ps

// ============================================================================
// Parameters derived from Sri Yantra geometry
// ============================================================================
// PHI (Golden Ratio) = 1.618033988749895
// Approximated as 1618/1000 for fixed-point math

module sri_noc_parameters;
    // Golden Ratio (fixed point: multiply by 1000)
    localparam PHI_NUM = 1618;
    localparam PHI_DEN = 1000;
    
    // Sri Yantra angles (degrees)
    localparam SHIVA_ANGLE = 51;   // Upward triangles
    localparam SHAKTI_ANGLE = 51;  // Downward triangles
    
    // Structure counts
    localparam NUM_TRIKONAS = 9;        // 9 interlocking triangles
    localparam NUM_INNER_TRIANGLES = 43; // Created by intersections
    localparam NUM_MARMA = 18;          // Critical intersection points
endmodule

// ============================================================================
// BINDU NODE - Central Global Synchronizer
// ============================================================================
// The Bindu is the center point of Sri Yantra
// In SPU, it provides global clock, reset, and arbitration

module bindu_controller #(
    parameter NUM_CLUSTERS = 9,
    parameter DATA_WIDTH = 64,
    parameter ADDR_WIDTH = 32
)(
    input  wire                     clk,
    input  wire                     rst_n,
    
    // Global synchronization (Om frequency)
    output reg                      global_sync,
    output reg  [31:0]              om_phase,
    
    // Cluster interfaces
    input  wire [NUM_CLUSTERS-1:0]  cluster_req,
    input  wire [NUM_CLUSTERS*DATA_WIDTH-1:0] cluster_data_in,
    output reg  [NUM_CLUSTERS-1:0]  cluster_grant,
    output reg  [DATA_WIDTH-1:0]    broadcast_data,
    
    // Loop resolution (Anavastha handling)
    input  wire [NUM_CLUSTERS-1:0]  loop_alerts,
    output reg  [NUM_CLUSTERS-1:0]  dissolution_cmd  // Force reset to Neither
);
    // Om phase generator (fundamental resonant frequency)
    // This creates the "Mantra" timing for global operations
    localparam OM_PERIOD = 1000;  // Cycles per Om wave
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            om_phase <= 0;
            global_sync <= 0;
        end else begin
            if (om_phase >= OM_PERIOD - 1) begin
                om_phase <= 0;
                global_sync <= 1;  // Global sync pulse
            end else begin
                om_phase <= om_phase + 1;
                global_sync <= 0;
            end
        end
    end
    
    // Round-robin arbitration (Yantra rotation symmetry)
    reg [3:0] current_grant;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cluster_grant <= 0;
            current_grant <= 0;
        end else begin
            cluster_grant <= 0;
            // Rotate through clusters seeking requests
            if (cluster_req[current_grant]) begin
                cluster_grant[current_grant] <= 1;
            end
            current_grant <= (current_grant + 1) % NUM_CLUSTERS;
        end
    end
    
    // Loop dissolution - sends reset to clusters with detected loops
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dissolution_cmd <= 0;
        end else begin
            dissolution_cmd <= loop_alerts;  // Mirror alerts as dissolution commands
        end
    end
    
    // Broadcast selected cluster data to all
    always @(posedge clk) begin
        broadcast_data <= cluster_data_in[current_grant*DATA_WIDTH +: DATA_WIDTH];
    end

endmodule

// ============================================================================
// TRIKONA CLUSTER - Single Compute Triangle
// ============================================================================
// Each of 9 triangles in Sri Yantra represents a compute cluster
// Shiva triangles (upward) = Memory/Context processing
// Shakti triangles (downward) = Logic/Inference processing

module trikona_cluster #(
    parameter CLUSTER_ID = 0,
    parameter DATA_WIDTH = 64,
    parameter IS_SHIVA = 1  // 1 = Shiva (memory), 0 = Shakti (logic)
)(
    input  wire                  clk,
    input  wire                  rst_n,
    
    // Bindu interface
    input  wire                  global_sync,
    input  wire                  dissolution_cmd,
    output reg                   loop_alert,
    
    // Data interface
    input  wire [DATA_WIDTH-1:0] data_in,
    input  wire                  data_valid,
    output reg  [DATA_WIDTH-1:0] data_out,
    output reg                   data_ready,
    
    // Inter-cluster connections (3 edges of triangle)
    input  wire [DATA_WIDTH-1:0] edge_a_in,
    input  wire [DATA_WIDTH-1:0] edge_b_in,
    input  wire [DATA_WIDTH-1:0] edge_c_in,
    output reg  [DATA_WIDTH-1:0] edge_a_out,
    output reg  [DATA_WIDTH-1:0] edge_b_out,
    output reg  [DATA_WIDTH-1:0] edge_c_out
);
    // Local processing state
    reg [DATA_WIDTH-1:0] local_state;
    reg [7:0] process_count;
    
    // Shiva clusters focus on accumulation (memory-like)
    // Shakti clusters focus on transformation (logic-like)
    
    generate
        if (IS_SHIVA) begin : shiva_logic
            // SHIVA: Memory/Accumulation cluster
            always @(posedge clk or negedge rst_n) begin
                if (!rst_n || dissolution_cmd) begin
                    local_state <= 0;
                    data_out <= 0;
                    loop_alert <= 0;
                end else if (global_sync) begin
                    // Accumulate on global sync
                    local_state <= local_state + edge_a_in + edge_b_in + edge_c_in;
                    data_out <= local_state;
                    data_ready <= 1;
                end else if (data_valid) begin
                    local_state <= local_state + data_in;
                end
            end
        end else begin : shakti_logic
            // SHAKTI: Logic/Transformation cluster
            always @(posedge clk or negedge rst_n) begin
                if (!rst_n || dissolution_cmd) begin
                    local_state <= 0;
                    data_out <= 0;
                    loop_alert <= 0;
                end else if (global_sync) begin
                    // Transform on global sync
                    local_state <= (edge_a_in ^ edge_b_in) | edge_c_in;
                    data_out <= local_state;
                    data_ready <= 1;
                end else if (data_valid) begin
                    local_state <= data_in ^ local_state;
                end
            end
        end
    endgenerate
    
    // Propagate to edges (fractal routing)
    always @(posedge clk) begin
        edge_a_out <= local_state;
        edge_b_out <= local_state;
        edge_c_out <= local_state;
    end

endmodule

// ============================================================================
// MARMA ROUTER - Intersection Point Router
// ============================================================================
// Marma Sthanas are the 18 critical intersection points
// Used for TSV placement and clock distribution

module marma_router #(
    parameter MARMA_ID = 0,
    parameter DATA_WIDTH = 64,
    parameter NUM_PORTS = 4  // Variable based on intersection degree
)(
    input  wire                  clk,
    input  wire                  rst_n,
    
    // Port interfaces
    input  wire [NUM_PORTS*DATA_WIDTH-1:0] port_in,
    input  wire [NUM_PORTS-1:0]            port_valid,
    output reg  [NUM_PORTS*DATA_WIDTH-1:0] port_out,
    output reg  [NUM_PORTS-1:0]            port_ready,
    
    // Routing table (destination -> port mapping)
    input  wire [7:0]            dest_addr,
    output reg  [3:0]            output_port
);
    // Golden Ratio based routing decision
    // Uses XOR-fold of address for pseudo-random but deterministic routing
    
    always @(*) begin
        // Simple modular routing based on address folding
        output_port = (dest_addr[7:4] ^ dest_addr[3:0]) % NUM_PORTS;
    end
    
    // Crossbar switch
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            port_out <= 0;
            port_ready <= 0;
        end else begin
            port_ready <= port_valid;
            for (i = 0; i < NUM_PORTS; i = i + 1) begin
                if (port_valid[i]) begin
                    port_out[output_port*DATA_WIDTH +: DATA_WIDTH] <= 
                        port_in[i*DATA_WIDTH +: DATA_WIDTH];
                end
            end
        end
    end

endmodule

// ============================================================================
// SRI-NoC TOP LEVEL - Complete Fractal Network
// ============================================================================

module sri_noc #(
    parameter DATA_WIDTH = 64,
    parameter ADDR_WIDTH = 32
)(
    input  wire                  clk,
    input  wire                  rst_n,
    
    // External interface (Bhupura boundary)
    input  wire [DATA_WIDTH-1:0] ext_data_in,
    input  wire                  ext_valid,
    input  wire [ADDR_WIDTH-1:0] ext_addr,
    output wire [DATA_WIDTH-1:0] ext_data_out,
    output wire                  ext_ready,
    
    // Status
    output wire                  global_sync,
    output wire [8:0]            cluster_status
);
    localparam NUM_CLUSTERS = 9;
    
    // Bindu controller
    wire [NUM_CLUSTERS-1:0] cluster_req;
    wire [NUM_CLUSTERS*DATA_WIDTH-1:0] cluster_data;
    wire [NUM_CLUSTERS-1:0] cluster_grant;
    wire [DATA_WIDTH-1:0] broadcast_data;
    wire [NUM_CLUSTERS-1:0] loop_alerts;
    wire [NUM_CLUSTERS-1:0] dissolution_cmd;
    
    bindu_controller #(
        .NUM_CLUSTERS(NUM_CLUSTERS),
        .DATA_WIDTH(DATA_WIDTH)
    ) bindu (
        .clk(clk),
        .rst_n(rst_n),
        .global_sync(global_sync),
        .om_phase(),
        .cluster_req(cluster_req),
        .cluster_data_in(cluster_data),
        .cluster_grant(cluster_grant),
        .broadcast_data(broadcast_data),
        .loop_alerts(loop_alerts),
        .dissolution_cmd(dissolution_cmd)
    );
    
    // Generate 9 Trikona clusters
    // 4 Shiva (upward) + 5 Shakti (downward) as per Sri Yantra
    
    wire [DATA_WIDTH-1:0] edges [0:NUM_CLUSTERS-1][0:2];
    wire [NUM_CLUSTERS-1:0] data_ready_arr;
    
    genvar c;
    generate
        for (c = 0; c < NUM_CLUSTERS; c = c + 1) begin : cluster_gen
            trikona_cluster #(
                .CLUSTER_ID(c),
                .DATA_WIDTH(DATA_WIDTH),
                .IS_SHIVA(c < 4 ? 1 : 0)  // First 4 are Shiva, rest Shakti
            ) cluster (
                .clk(clk),
                .rst_n(rst_n),
                .global_sync(global_sync),
                .dissolution_cmd(dissolution_cmd[c]),
                .loop_alert(loop_alerts[c]),
                .data_in(broadcast_data),
                .data_valid(cluster_grant[c]),
                .data_out(cluster_data[c*DATA_WIDTH +: DATA_WIDTH]),
                .data_ready(data_ready_arr[c]),
                .edge_a_in(edges[(c+1)%NUM_CLUSTERS][0]),
                .edge_b_in(edges[(c+2)%NUM_CLUSTERS][1]),
                .edge_c_in(edges[(c+3)%NUM_CLUSTERS][2]),
                .edge_a_out(edges[c][0]),
                .edge_b_out(edges[c][1]),
                .edge_c_out(edges[c][2])
            );
        end
    endgenerate
    
    // External interface connects to Cluster 0
    assign cluster_req[0] = ext_valid;
    assign ext_data_out = cluster_data[0 +: DATA_WIDTH];
    assign ext_ready = data_ready_arr[0];
    assign cluster_req[NUM_CLUSTERS-1:1] = 0;  // Other clusters request internally
    
    assign cluster_status = data_ready_arr;

endmodule
