/*
 * ============================================================================
 * SRI-PROCESSING UNIT (SPU) - Complete Top Level
 * ============================================================================
 * 
 * The revolutionary processor integrating:
 * - Navya-Nyaya 4-valued logic (resolves logic loops)
 * - Sri Yantra Fractal NoC (O(log N) interconnect)
 * - Vedic Mathematics ALU (Urdhva Tiryagbhyam)
 * - Phononic Thermal Management (heat recycling)
 * - Sri Yantra Cache Hierarchy (Golden Ratio sizing)
 * 
 * This is the complete Vedicon-Silicon integration.
 * 
 * "The Vedas have provided the schematic; it is now time to etch it."
 * 
 * ============================================================================
 */

`timescale 1ns / 1ps

module spu_top #(
    parameter DATA_WIDTH = 64,
    parameter ADDR_WIDTH = 32,
    parameter NUM_CLUSTERS = 9,
    parameter NUM_THERMAL_ZONES = 4
)(
    // Clock and Reset
    input  wire                     clk,
    input  wire                     rst_n,
    
    // External Memory Interface (Bhupura Boundary)
    input  wire [DATA_WIDTH-1:0]    mem_rdata,
    input  wire                     mem_ready,
    output wire                     mem_valid,
    output wire                     mem_write,
    output wire [ADDR_WIDTH-1:0]    mem_addr,
    output wire [DATA_WIDTH-1:0]    mem_wdata,
    
    // IO Interface
    input  wire [31:0]              io_input,
    input  wire                     io_valid,
    output wire [31:0]              io_output,
    output wire                     io_ready,
    
    // Temperature Sensors (optional, for thermal management)
    input  wire [47:0]              temp_sensors,  // 4 x 12-bit
    input  wire [3:0]               temp_valid,
    
    // Status and Debug
    output wire                     global_sync,    // Om pulse
    output wire [8:0]               cluster_status,
    output wire [3:0]               thermal_throttle,
    output wire [3:0]               thermal_emergency,
    output wire [15:0]              harvested_power,
    output wire                     loop_detected
);

    // ========================================================================
    // BINDU - Central Synchronization (Om Pulse)
    // ========================================================================
    wire om_pulse;
    wire power_valid;
    
    // ========================================================================
    // SRI-NoC: Fractal Network-on-Chip
    // ========================================================================
    wire [DATA_WIDTH-1:0] noc_data_out;
    wire noc_ready;
    wire [8:0] noc_cluster_status;
    
    sri_noc #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) u_sri_noc (
        .clk(clk),
        .rst_n(rst_n),
        .ext_data_in(mem_rdata),
        .ext_valid(mem_ready),
        .ext_addr(mem_addr),
        .ext_data_out(noc_data_out),
        .ext_ready(noc_ready),
        .global_sync(global_sync),
        .cluster_status(noc_cluster_status)
    );
    
    assign cluster_status = noc_cluster_status;
    
    // ========================================================================
    // NAVYA-NYAYA LOGIC UNIT (4-valued)
    // ========================================================================
    wire [1:0] nyaya_result;
    wire nyaya_loop;
    
    // Map IO input to Nyaya operations
    wire [1:0] nyaya_op_a = io_input[1:0];
    wire [1:0] nyaya_op_b = io_input[3:2];
    wire [2:0] nyaya_opcode = io_input[6:4];
    
    nyaya_alu u_nyaya (
        .clk(clk),
        .rst_n(rst_n),
        .op_a(nyaya_op_a),
        .op_b(nyaya_op_b),
        .opcode(nyaya_opcode),
        .result(nyaya_result),
        .loop_flag(nyaya_loop)
    );
    
    assign loop_detected = nyaya_loop;
    
    // ========================================================================
    // VEDIC MATHEMATICS ALU (32-bit)
    // ========================================================================
    wire [63:0] vedic_result;
    wire vedic_overflow, vedic_zero, vedic_valid;
    
    yantra_alu #(
        .WIDTH(32)
    ) u_vedic_alu (
        .clk(clk),
        .rst_n(rst_n),
        .operand_a(io_input),
        .operand_b(mem_rdata[31:0]),
        .opcode(io_input[31:28]),
        .result(vedic_result),
        .overflow(vedic_overflow),
        .zero(vedic_zero),
        .valid(vedic_valid)
    );
    
    // ========================================================================
    // SRI YANTRA CACHE (Golden Ratio Hierarchy)
    // ========================================================================
    wire [DATA_WIDTH-1:0] cache_rdata;
    wire cache_ready;
    
    sri_yantra_cache #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) u_cache (
        .clk(clk),
        .rst_n(rst_n),
        .cpu_valid(io_valid),
        .cpu_write(io_input[31]),
        .cpu_addr({{ADDR_WIDTH-16{1'b0}}, io_input[15:0]}),
        .cpu_wdata({{DATA_WIDTH-32{1'b0}}, io_input}),
        .cpu_rdata(cache_rdata),
        .cpu_ready(cache_ready),
        .mem_valid(mem_valid),
        .mem_write(mem_write),
        .mem_addr(mem_addr),
        .mem_wdata(mem_wdata),
        .mem_rdata(mem_rdata),
        .mem_ready(mem_ready)
    );
    
    // ========================================================================
    // PHONONIC THERMAL MANAGER
    // ========================================================================
    
    phononic_thermal_manager #(
        .NUM_ZONES(NUM_THERMAL_ZONES)
    ) u_thermal (
        .clk(clk),
        .rst_n(rst_n),
        .zone_temps(temp_sensors),
        .temp_valid(temp_valid),
        .throttle(thermal_throttle),
        .emergency(thermal_emergency),
        .recycled_power(harvested_power),
        .power_valid(power_valid),
        .om_pulse(om_pulse)
    );
    
    // ========================================================================
    // OUTPUT MULTIPLEXING
    // ========================================================================
    // Select output based on operation
    
    reg [31:0] io_out_reg;
    reg io_ready_reg;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            io_out_reg <= 0;
            io_ready_reg <= 0;
        end else begin
            // Combine results from different units
            io_out_reg <= {
                14'b0,              // Reserved
                nyaya_loop,         // Loop detection flag
                nyaya_result,       // Navya-Nyaya result
                vedic_overflow,     // Vedic ALU overflow
                vedic_result[13:0]  // Vedic ALU result (lower bits)
            };
            io_ready_reg <= vedic_valid | cache_ready;
        end
    end
    
    assign io_output = io_out_reg;
    assign io_ready = io_ready_reg;

endmodule

// ============================================================================
// SPU WRAPPER FOR TINYTAPEOUT
// ============================================================================
// Simplified wrapper for TinyTapeout submission

module tt_um_spu (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);
    // Simplified SPU interface for TinyTapeout
    wire [31:0] io_input = {24'b0, ui_in};
    wire [31:0] io_output;
    wire io_valid = ena;
    wire io_ready;
    wire global_sync;
    wire loop_detected;
    
    // Minimal SPU instantiation
    // Note: Full SPU requires more area than TinyTapeout allows
    // This is the Nyaya + Vedic core only
    
    wire [1:0] nyaya_result;
    wire [15:0] vedic_product;
    
    // Navya-Nyaya 4-valued logic
    nyaya_alu nyaya (
        .clk(clk),
        .rst_n(rst_n),
        .op_a(ui_in[1:0]),
        .op_b(ui_in[3:2]),
        .opcode(ui_in[6:4]),
        .result(nyaya_result),
        .loop_flag(loop_detected)
    );
    
    // Vedic multiplier (8-bit for TT)
    vedic_mult_8bit_tt vedic (
        .a(ui_in),
        .b(uio_in),
        .p(vedic_product)
    );
    
    // Output selection
    assign uo_out = ui_in[7] ? vedic_product[7:0] : 
                    {4'b0, loop_detected, 1'b0, nyaya_result};
    
    assign uio_out = vedic_product[15:8];
    assign uio_oe = 8'hFF;  // All outputs

endmodule
