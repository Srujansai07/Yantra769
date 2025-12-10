/*
 * ============================================================================
 * SRI YANTRA MEMORY CONTROLLER
 * ============================================================================
 * 
 * Cache hierarchy inspired by Sri Yantra sacred geometry:
 * 
 * BINDU (Center)     → L1 Cache (Fastest, smallest)
 * INNER TRIANGLES    → L2 Cache (Fast, medium)
 * OUTER TRIANGLES    → L3 Cache (Medium, larger)
 * LOTUS PETALS       → Shared Memory Buffer
 * BHUPURA (Square)   → Main Memory Interface
 * 
 * Key principles applied:
 * 1. Golden Ratio (φ ≈ 1.618) for cache size progression
 * 2. 9-way set associativity (9 triangles of Sri Yantra)
 * 3. Concentric access patterns matching yantra rings
 * 4. Fractal prefetching based on self-similarity
 * 
 * ============================================================================
 */

`timescale 1ns / 1ps

// ============================================================================
// SRI YANTRA CACHE PARAMETERS
// ============================================================================
// Using Golden Ratio for cache sizing:
// L1: 1 unit (base)
// L2: φ × L1 ≈ 1.618 units  
// L3: φ × L2 ≈ 2.618 units
// This creates natural harmony in access patterns

module sri_yantra_cache #(
    parameter ADDR_WIDTH   = 32,
    parameter DATA_WIDTH   = 64,
    parameter L1_SIZE_KB   = 32,     // Bindu (center)
    parameter L2_SIZE_KB   = 52,     // φ × L1 ≈ 51.8 KB
    parameter L3_SIZE_KB   = 84,     // φ × L2 ≈ 84.1 KB
    parameter WAYS         = 9,      // 9 triangles of Sri Yantra
    parameter LINE_SIZE    = 64      // Cache line size (bytes)
)(
    input  wire                  clk,
    input  wire                  rst_n,
    
    // CPU Interface (Bindu - center point)
    input  wire                  cpu_valid,
    input  wire                  cpu_write,
    input  wire [ADDR_WIDTH-1:0] cpu_addr,
    input  wire [DATA_WIDTH-1:0] cpu_wdata,
    output reg  [DATA_WIDTH-1:0] cpu_rdata,
    output reg                   cpu_ready,
    
    // Memory Interface (Bhupura - outer boundary)
    output reg                   mem_valid,
    output reg                   mem_write,
    output reg  [ADDR_WIDTH-1:0] mem_addr,
    output reg  [DATA_WIDTH-1:0] mem_wdata,
    input  wire [DATA_WIDTH-1:0] mem_rdata,
    input  wire                  mem_ready
);

    // ========================================================================
    // YANTRA GEOMETRY CONSTANTS
    // ========================================================================
    localparam PHI = 1618;  // Golden ratio × 1000 (fixed point)
    localparam PHI_BASE = 1000;
    
    // Cache geometry derived from Sri Yantra
    localparam L1_LINES = (L1_SIZE_KB * 1024) / LINE_SIZE;  // Bindu
    localparam L2_LINES = (L2_SIZE_KB * 1024) / LINE_SIZE;  // Inner triangles
    localparam L3_LINES = (L3_SIZE_KB * 1024) / LINE_SIZE;  // Outer triangles
    
    // Set/Way calculations (9-way = 9 triangles)
    localparam L1_SETS = L1_LINES / WAYS;
    localparam L2_SETS = L2_LINES / WAYS;
    localparam L3_SETS = L3_LINES / WAYS;
    
    // Address breakdown
    localparam OFFSET_BITS = $clog2(LINE_SIZE);
    localparam L1_INDEX_BITS = $clog2(L1_SETS);
    localparam TAG_BITS = ADDR_WIDTH - OFFSET_BITS - L1_INDEX_BITS;
    
    // ========================================================================
    // CACHE STORAGE (Yantra Levels)
    // ========================================================================
    
    // L1 Cache - BINDU (Fastest access, center of yantra)
    reg [DATA_WIDTH-1:0] l1_data [0:L1_LINES-1];
    reg [TAG_BITS-1:0]   l1_tag  [0:L1_LINES-1];
    reg                  l1_valid [0:L1_LINES-1];
    reg                  l1_dirty [0:L1_LINES-1];
    reg [3:0]            l1_lru   [0:L1_SETS-1];  // LRU per set
    
    // Access statistics (for yantra-pattern prefetching)
    reg [15:0] access_pattern [0:8];  // 9 pattern trackers (9 triangles)
    reg [ADDR_WIDTH-1:0] last_addr;
    reg [2:0] pattern_index;

    // ========================================================================
    // ADDRESS DECODE (Yantra Ring Mapping)
    // ========================================================================
    wire [OFFSET_BITS-1:0]    offset    = cpu_addr[OFFSET_BITS-1:0];
    wire [L1_INDEX_BITS-1:0]  l1_index  = cpu_addr[OFFSET_BITS +: L1_INDEX_BITS];
    wire [TAG_BITS-1:0]       tag       = cpu_addr[ADDR_WIDTH-1 -: TAG_BITS];
    
    // ========================================================================
    // TRIANGLE-BASED SET SELECTION
    // ========================================================================
    // Maps address to one of 9 ways using yantra geometry
    function [3:0] yantra_way_select;
        input [ADDR_WIDTH-1:0] addr;
        input [15:0] pattern;
        begin
            // XOR-fold address with pattern for pseudo-random but deterministic mapping
            yantra_way_select = (addr[11:8] ^ addr[7:4] ^ pattern[3:0]) % WAYS;
        end
    endfunction
    
    // ========================================================================
    // FRACTAL PREFETCH LOGIC (Self-similarity principle)
    // ========================================================================
    // Sri Yantra has self-similar patterns at each scale
    // Use this for intelligent prefetching
    
    reg [ADDR_WIDTH-1:0] prefetch_addr;
    reg                  prefetch_valid;
    
    always @(posedge clk) begin
        if (!rst_n) begin
            prefetch_valid <= 0;
            pattern_index <= 0;
        end else if (cpu_valid && cpu_ready) begin
            // Detect access patterns
            access_pattern[pattern_index] <= cpu_addr[15:0];
            pattern_index <= (pattern_index + 1) % 9;  // 9 triangles
            
            // Fractal prefetch: predict next address based on pattern
            // Using golden ratio stride
            prefetch_addr <= cpu_addr + (LINE_SIZE * PHI / PHI_BASE);
            prefetch_valid <= 1;
            
            last_addr <= cpu_addr;
        end else begin
            prefetch_valid <= 0;
        end
    end
    
    // ========================================================================
    // CACHE ACCESS STATE MACHINE
    // ========================================================================
    localparam IDLE       = 3'b000;
    localparam L1_CHECK   = 3'b001;  // Bindu check
    localparam L2_CHECK   = 3'b010;  // Inner triangle check
    localparam L3_CHECK   = 3'b011;  // Outer triangle check
    localparam MEM_FETCH  = 3'b100;  // Bhupura access
    localparam WRITEBACK  = 3'b101;
    localparam PREFETCH   = 3'b110;  // Lotus petal prefetch
    
    reg [2:0] state;
    reg [ADDR_WIDTH-1:0] pending_addr;
    reg [DATA_WIDTH-1:0] pending_data;
    reg pending_write;
    
    integer i;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            cpu_ready <= 0;
            cpu_rdata <= 0;
            mem_valid <= 0;
            for (i = 0; i < L1_LINES; i = i + 1) begin
                l1_valid[i] <= 0;
                l1_dirty[i] <= 0;
            end
        end else begin
            case (state)
                IDLE: begin
                    cpu_ready <= 0;
                    mem_valid <= 0;
                    if (cpu_valid) begin
                        pending_addr <= cpu_addr;
                        pending_data <= cpu_wdata;
                        pending_write <= cpu_write;
                        state <= L1_CHECK;
                    end
                end
                
                L1_CHECK: begin
                    // Check L1 cache (BINDU)
                    // Simplified: direct-mapped for demo
                    if (l1_valid[l1_index] && l1_tag[l1_index] == tag) begin
                        // L1 HIT - fastest path through center
                        if (pending_write) begin
                            l1_data[l1_index] <= pending_data;
                            l1_dirty[l1_index] <= 1;
                        end else begin
                            cpu_rdata <= l1_data[l1_index];
                        end
                        cpu_ready <= 1;
                        state <= IDLE;
                    end else begin
                        // L1 MISS - expand to outer rings
                        state <= MEM_FETCH;
                    end
                end
                
                MEM_FETCH: begin
                    // Go to main memory (BHUPURA)
                    mem_valid <= 1;
                    mem_write <= pending_write;
                    mem_addr <= pending_addr;
                    mem_wdata <= pending_data;
                    
                    if (mem_ready) begin
                        if (!pending_write) begin
                            cpu_rdata <= mem_rdata;
                            // Fill L1
                            l1_data[l1_index] <= mem_rdata;
                            l1_tag[l1_index] <= tag;
                            l1_valid[l1_index] <= 1;
                            l1_dirty[l1_index] <= 0;
                        end
                        cpu_ready <= 1;
                        mem_valid <= 0;
                        state <= IDLE;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule

// ============================================================================
// YANTRA INTERCONNECT - 9-Point Star Topology
// ============================================================================
// Connecting multiple processing units using Sri Yantra's 
// 9 triangle intersection points

module yantra_interconnect #(
    parameter NUM_MASTERS = 4,
    parameter NUM_SLAVES  = 4,
    parameter ADDR_WIDTH  = 32,
    parameter DATA_WIDTH  = 64
)(
    input  wire                  clk,
    input  wire                  rst_n,
    
    // Master interfaces (Processing cores)
    input  wire [NUM_MASTERS-1:0]                  m_valid,
    input  wire [NUM_MASTERS-1:0]                  m_write,
    input  wire [NUM_MASTERS*ADDR_WIDTH-1:0]       m_addr,
    input  wire [NUM_MASTERS*DATA_WIDTH-1:0]       m_wdata,
    output wire [NUM_MASTERS*DATA_WIDTH-1:0]       m_rdata,
    output wire [NUM_MASTERS-1:0]                  m_ready,
    
    // Slave interfaces (Memory/peripherals)
    output wire [NUM_SLAVES-1:0]                   s_valid,
    output wire [NUM_SLAVES-1:0]                   s_write,
    output wire [NUM_SLAVES*ADDR_WIDTH-1:0]        s_addr,
    output wire [NUM_SLAVES*DATA_WIDTH-1:0]        s_wdata,
    input  wire [NUM_SLAVES*DATA_WIDTH-1:0]        s_rdata,
    input  wire [NUM_SLAVES-1:0]                   s_ready
);
    // Crossbar using yantra principle:
    // Each master can reach any slave through the central bindu
    // Arbitration uses round-robin inspired by yantra's rotational symmetry
    
    reg [$clog2(NUM_MASTERS)-1:0] current_master;
    reg [$clog2(NUM_SLAVES)-1:0]  target_slave;
    
    // Simple round-robin arbiter (yantra rotation)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_master <= 0;
        end else begin
            // Rotate through masters like yantra mandala rotation
            if (|m_valid) begin
                current_master <= (current_master + 1) % NUM_MASTERS;
            end
        end
    end
    
    // Address decode to select slave
    function [$clog2(NUM_SLAVES)-1:0] decode_slave;
        input [ADDR_WIDTH-1:0] addr;
        begin
            // Simple address-based decode
            decode_slave = addr[ADDR_WIDTH-1 -: $clog2(NUM_SLAVES)];
        end
    endfunction
    
    // Connect current master to appropriate slave
    // (Simplified for demonstration)
    genvar i;
    generate
        for (i = 0; i < NUM_SLAVES; i = i + 1) begin : slave_conn
            assign s_valid[i] = m_valid[current_master] && 
                               (decode_slave(m_addr[current_master*ADDR_WIDTH +: ADDR_WIDTH]) == i);
            assign s_write[i] = m_write[current_master];
            assign s_addr[i*ADDR_WIDTH +: ADDR_WIDTH] = m_addr[current_master*ADDR_WIDTH +: ADDR_WIDTH];
            assign s_wdata[i*DATA_WIDTH +: DATA_WIDTH] = m_wdata[current_master*DATA_WIDTH +: DATA_WIDTH];
        end
        
        for (i = 0; i < NUM_MASTERS; i = i + 1) begin : master_conn
            assign m_rdata[i*DATA_WIDTH +: DATA_WIDTH] = s_rdata[target_slave*DATA_WIDTH +: DATA_WIDTH];
            assign m_ready[i] = (i == current_master) ? s_ready[target_slave] : 1'b0;
        end
    endgenerate

endmodule
