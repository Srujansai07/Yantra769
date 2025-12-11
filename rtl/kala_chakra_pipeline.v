/*
 * KALA CHAKRA PIPELINE - 12-STAGE PROCESSOR
 * ==========================================
 * Based on काल चक्र (Time Wheel) / 12 Rashis (Zodiac)
 * 
 * The 12 Rashis map to 12 pipeline stages:
 * 
 * Stage  1: Mesha (मेष)       Aries      → Instruction Fetch 1
 * Stage  2: Vrishabha (वृषभ)  Taurus     → Instruction Fetch 2
 * Stage  3: Mithuna (मिथुन)   Gemini     → Decode 1
 * Stage  4: Karka (कर्क)      Cancer     → Decode 2
 * Stage  5: Simha (सिंह)      Leo        → Register Read
 * Stage  6: Kanya (कन्या)     Virgo      → Execute 1 (ALU)
 * Stage  7: Tula (तुला)       Libra      → Execute 2 (Balance)
 * Stage  8: Vrishchika (वृश्चिक) Scorpio → Memory 1
 * Stage  9: Dhanu (धनु)       Sagittarius→ Memory 2
 * Stage 10: Makara (मकर)      Capricorn  → Write Back 1
 * Stage 11: Kumbha (कुम्भ)    Aquarius   → Write Back 2
 * Stage 12: Meena (मीन)       Pisces     → Commit
 * 
 * Author: SIVAA Project
 * Date: December 2025
 */

module kala_chakra_pipeline #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32,
    parameter REG_ADDR_WIDTH = 5,
    parameter NUM_STAGES = 12
)(
    input  wire                    clk,
    input  wire                    rst_n,
    
    // Instruction memory interface
    input  wire [DATA_WIDTH-1:0]   instr_data,
    output reg  [ADDR_WIDTH-1:0]   instr_addr,
    
    // Data memory interface
    output reg                     mem_req,
    output reg                     mem_write,
    output reg  [ADDR_WIDTH-1:0]   mem_addr,
    output reg  [DATA_WIDTH-1:0]   mem_wdata,
    input  wire [DATA_WIDTH-1:0]   mem_rdata,
    input  wire                    mem_ready,
    
    // Pipeline status
    output wire [NUM_STAGES-1:0]   stage_active,
    output wire [3:0]              current_rashi,
    
    // Stall/Flush control
    input  wire                    stall,
    input  wire                    flush,
    
    // Debug
    output wire [ADDR_WIDTH-1:0]   commit_pc,
    output wire                    commit_valid
);

    // =========================================================================
    // RASHI (राशि) STAGE DEFINITIONS
    // =========================================================================
    
    localparam RASHI_MESHA      = 4'd0;   // IF1
    localparam RASHI_VRISHABHA  = 4'd1;   // IF2
    localparam RASHI_MITHUNA    = 4'd2;   // ID1
    localparam RASHI_KARKA      = 4'd3;   // ID2
    localparam RASHI_SIMHA      = 4'd4;   // RR
    localparam RASHI_KANYA      = 4'd5;   // EX1
    localparam RASHI_TULA       = 4'd6;   // EX2
    localparam RASHI_VRISHCHIKA = 4'd7;   // MEM1
    localparam RASHI_DHANU      = 4'd8;   // MEM2
    localparam RASHI_MAKARA     = 4'd9;   // WB1
    localparam RASHI_KUMBHA     = 4'd10;  // WB2
    localparam RASHI_MEENA      = 4'd11;  // COM
    
    // =========================================================================
    // PIPELINE REGISTERS (Between Rashis)
    // =========================================================================
    
    // IF1/IF2 → ID1
    reg [ADDR_WIDTH-1:0] if_id_pc;
    reg [DATA_WIDTH-1:0] if_id_instr;
    reg                  if_id_valid;
    
    // ID2 → RR
    reg [ADDR_WIDTH-1:0] id_rr_pc;
    reg [4:0]            id_rr_rs1;
    reg [4:0]            id_rr_rs2;
    reg [4:0]            id_rr_rd;
    reg [DATA_WIDTH-1:0] id_rr_imm;
    reg [3:0]            id_rr_alu_op;
    reg                  id_rr_mem_read;
    reg                  id_rr_mem_write;
    reg                  id_rr_valid;
    
    // RR → EX1
    reg [ADDR_WIDTH-1:0] rr_ex_pc;
    reg [DATA_WIDTH-1:0] rr_ex_rs1_data;
    reg [DATA_WIDTH-1:0] rr_ex_rs2_data;
    reg [DATA_WIDTH-1:0] rr_ex_imm;
    reg [4:0]            rr_ex_rd;
    reg [3:0]            rr_ex_alu_op;
    reg                  rr_ex_mem_read;
    reg                  rr_ex_mem_write;
    reg                  rr_ex_valid;
    
    // EX2 → MEM1
    reg [ADDR_WIDTH-1:0] ex_mem_pc;
    reg [DATA_WIDTH-1:0] ex_mem_result;
    reg [DATA_WIDTH-1:0] ex_mem_rs2_data;
    reg [4:0]            ex_mem_rd;
    reg                  ex_mem_mem_read;
    reg                  ex_mem_mem_write;
    reg                  ex_mem_valid;
    
    // MEM2 → WB1
    reg [ADDR_WIDTH-1:0] mem_wb_pc;
    reg [DATA_WIDTH-1:0] mem_wb_result;
    reg [4:0]            mem_wb_rd;
    reg                  mem_wb_valid;
    
    // WB2 → COM
    reg [ADDR_WIDTH-1:0] wb_com_pc;
    reg [DATA_WIDTH-1:0] wb_com_data;
    reg [4:0]            wb_com_rd;
    reg                  wb_com_valid;
    
    // Register file (32 registers)
    reg [DATA_WIDTH-1:0] regfile [0:31];
    
    // Program counter
    reg [ADDR_WIDTH-1:0] pc;
    
    // Stage activity tracking
    reg [NUM_STAGES-1:0] stage_active_reg;
    reg [3:0] current_rashi_reg;
    
    assign stage_active = stage_active_reg;
    assign current_rashi = current_rashi_reg;
    assign commit_pc = wb_com_pc;
    assign commit_valid = wb_com_valid;
    
    // =========================================================================
    // STAGE 1 & 2: MESHA + VRISHABHA (Instruction Fetch)
    // =========================================================================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc <= 32'd0;
            instr_addr <= 32'd0;
            if_id_pc <= 32'd0;
            if_id_instr <= 32'd0;
            if_id_valid <= 1'b0;
            stage_active_reg[0] <= 1'b0;
            stage_active_reg[1] <= 1'b0;
        end else if (!stall && !flush) begin
            // IF1: Mesha - Send address
            instr_addr <= pc;
            stage_active_reg[0] <= 1'b1;
            
            // IF2: Vrishabha - Receive instruction
            if_id_pc <= pc;
            if_id_instr <= instr_data;
            if_id_valid <= 1'b1;
            stage_active_reg[1] <= 1'b1;
            
            pc <= pc + 4;
        end else if (flush) begin
            if_id_valid <= 1'b0;
        end
    end
    
    // =========================================================================
    // STAGE 3 & 4: MITHUNA + KARKA (Decode)
    // =========================================================================
    
    wire [6:0] opcode = if_id_instr[6:0];
    wire [4:0] rd     = if_id_instr[11:7];
    wire [2:0] funct3 = if_id_instr[14:12];
    wire [4:0] rs1    = if_id_instr[19:15];
    wire [4:0] rs2    = if_id_instr[24:20];
    wire [6:0] funct7 = if_id_instr[31:25];
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            id_rr_pc <= 32'd0;
            id_rr_rs1 <= 5'd0;
            id_rr_rs2 <= 5'd0;
            id_rr_rd <= 5'd0;
            id_rr_imm <= 32'd0;
            id_rr_alu_op <= 4'd0;
            id_rr_mem_read <= 1'b0;
            id_rr_mem_write <= 1'b0;
            id_rr_valid <= 1'b0;
            stage_active_reg[2] <= 1'b0;
            stage_active_reg[3] <= 1'b0;
        end else if (!stall && !flush) begin
            stage_active_reg[2] <= if_id_valid;
            stage_active_reg[3] <= if_id_valid;
            
            id_rr_pc <= if_id_pc;
            id_rr_rs1 <= rs1;
            id_rr_rs2 <= rs2;
            id_rr_rd <= rd;
            id_rr_alu_op <= {funct7[5], funct3};
            
            // Immediate extraction (I-type for simplicity)
            id_rr_imm <= {{20{if_id_instr[31]}}, if_id_instr[31:20]};
            
            // Memory operations
            id_rr_mem_read <= (opcode == 7'b0000011);   // LOAD
            id_rr_mem_write <= (opcode == 7'b0100011);  // STORE
            
            id_rr_valid <= if_id_valid;
        end
    end
    
    // =========================================================================
    // STAGE 5: SIMHA (Register Read)
    // =========================================================================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rr_ex_pc <= 32'd0;
            rr_ex_rs1_data <= 32'd0;
            rr_ex_rs2_data <= 32'd0;
            rr_ex_imm <= 32'd0;
            rr_ex_rd <= 5'd0;
            rr_ex_alu_op <= 4'd0;
            rr_ex_mem_read <= 1'b0;
            rr_ex_mem_write <= 1'b0;
            rr_ex_valid <= 1'b0;
            stage_active_reg[4] <= 1'b0;
        end else if (!stall) begin
            stage_active_reg[4] <= id_rr_valid;
            
            rr_ex_pc <= id_rr_pc;
            rr_ex_rs1_data <= regfile[id_rr_rs1];
            rr_ex_rs2_data <= regfile[id_rr_rs2];
            rr_ex_imm <= id_rr_imm;
            rr_ex_rd <= id_rr_rd;
            rr_ex_alu_op <= id_rr_alu_op;
            rr_ex_mem_read <= id_rr_mem_read;
            rr_ex_mem_write <= id_rr_mem_write;
            rr_ex_valid <= id_rr_valid;
        end
    end
    
    // =========================================================================
    // STAGE 6 & 7: KANYA + TULA (Execute) - Uses Vedic ALU
    // =========================================================================
    
    reg [DATA_WIDTH-1:0] alu_result;
    
    always @(*) begin
        case (rr_ex_alu_op)
            4'b0000: alu_result = rr_ex_rs1_data + rr_ex_rs2_data;  // ADD
            4'b1000: alu_result = rr_ex_rs1_data - rr_ex_rs2_data;  // SUB
            4'b0001: alu_result = rr_ex_rs1_data << rr_ex_rs2_data[4:0]; // SLL
            4'b0010: alu_result = ($signed(rr_ex_rs1_data) < $signed(rr_ex_rs2_data)) ? 32'd1 : 32'd0; // SLT
            4'b0100: alu_result = rr_ex_rs1_data ^ rr_ex_rs2_data;  // XOR
            4'b0101: alu_result = rr_ex_rs1_data >> rr_ex_rs2_data[4:0]; // SRL
            4'b0110: alu_result = rr_ex_rs1_data | rr_ex_rs2_data;  // OR
            4'b0111: alu_result = rr_ex_rs1_data & rr_ex_rs2_data;  // AND
            default: alu_result = rr_ex_rs1_data + rr_ex_imm;       // ADD IMM
        endcase
    end
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ex_mem_pc <= 32'd0;
            ex_mem_result <= 32'd0;
            ex_mem_rs2_data <= 32'd0;
            ex_mem_rd <= 5'd0;
            ex_mem_mem_read <= 1'b0;
            ex_mem_mem_write <= 1'b0;
            ex_mem_valid <= 1'b0;
            stage_active_reg[5] <= 1'b0;
            stage_active_reg[6] <= 1'b0;
        end else if (!stall) begin
            stage_active_reg[5] <= rr_ex_valid;
            stage_active_reg[6] <= rr_ex_valid;
            
            ex_mem_pc <= rr_ex_pc;
            ex_mem_result <= alu_result;
            ex_mem_rs2_data <= rr_ex_rs2_data;
            ex_mem_rd <= rr_ex_rd;
            ex_mem_mem_read <= rr_ex_mem_read;
            ex_mem_mem_write <= rr_ex_mem_write;
            ex_mem_valid <= rr_ex_valid;
        end
    end
    
    // =========================================================================
    // STAGE 8 & 9: VRISHCHIKA + DHANU (Memory Access)
    // =========================================================================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_req <= 1'b0;
            mem_write <= 1'b0;
            mem_addr <= 32'd0;
            mem_wdata <= 32'd0;
            mem_wb_pc <= 32'd0;
            mem_wb_result <= 32'd0;
            mem_wb_rd <= 5'd0;
            mem_wb_valid <= 1'b0;
            stage_active_reg[7] <= 1'b0;
            stage_active_reg[8] <= 1'b0;
        end else if (!stall) begin
            stage_active_reg[7] <= ex_mem_valid;
            stage_active_reg[8] <= ex_mem_valid;
            
            mem_wb_pc <= ex_mem_pc;
            mem_wb_rd <= ex_mem_rd;
            
            if (ex_mem_mem_read || ex_mem_mem_write) begin
                mem_req <= 1'b1;
                mem_write <= ex_mem_mem_write;
                mem_addr <= ex_mem_result;
                mem_wdata <= ex_mem_rs2_data;
                
                if (ex_mem_mem_read && mem_ready) begin
                    mem_wb_result <= mem_rdata;
                end else begin
                    mem_wb_result <= ex_mem_result;
                end
            end else begin
                mem_req <= 1'b0;
                mem_wb_result <= ex_mem_result;
            end
            
            mem_wb_valid <= ex_mem_valid;
        end
    end
    
    // =========================================================================
    // STAGE 10 & 11: MAKARA + KUMBHA (Write Back)
    // =========================================================================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wb_com_pc <= 32'd0;
            wb_com_data <= 32'd0;
            wb_com_rd <= 5'd0;
            wb_com_valid <= 1'b0;
            stage_active_reg[9] <= 1'b0;
            stage_active_reg[10] <= 1'b0;
        end else if (!stall) begin
            stage_active_reg[9] <= mem_wb_valid;
            stage_active_reg[10] <= mem_wb_valid;
            
            wb_com_pc <= mem_wb_pc;
            wb_com_data <= mem_wb_result;
            wb_com_rd <= mem_wb_rd;
            wb_com_valid <= mem_wb_valid;
            
            // Write to register file
            if (mem_wb_valid && mem_wb_rd != 5'd0) begin
                regfile[mem_wb_rd] <= mem_wb_result;
            end
        end
    end
    
    // =========================================================================
    // STAGE 12: MEENA (Commit)
    // =========================================================================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            stage_active_reg[11] <= 1'b0;
            current_rashi_reg <= 4'd0;
        end else begin
            stage_active_reg[11] <= wb_com_valid;
            
            // Rotate through Rashis (for visualization)
            if (|stage_active_reg) begin
                current_rashi_reg <= (current_rashi_reg == 4'd11) ? 4'd0 : current_rashi_reg + 1;
            end
        end
    end
    
    // Initialize register file
    integer i;
    initial begin
        for (i = 0; i < 32; i = i + 1) begin
            regfile[i] = 32'd0;
        end
    end

endmodule

// =============================================================================
// RASHI (ZODIAC) CORRESPONDENCE
// =============================================================================
//
// Each Rashi governs specific pipeline activities:
//
// Mesha (Ram)      - Beginnings, Initiative → Instruction Fetch
// Vrishabha (Bull) - Stability, Resources → Instruction Latch
// Mithuna (Twins)  - Duality, Analysis → Decode (split)
// Karka (Crab)     - Memory, Foundation → Decode complete
// Simha (Lion)     - Power, Action → Register Read
// Kanya (Virgin)   - Precision, Detail → Execute (precise ALU)
// Tula (Balance)   - Balance, Harmony → Execute (balance paths)
// Vrishchika       - Transformation → Memory access
// Dhanu (Archer)   - Direction, Target → Memory complete
// Makara (Goat)    - Achievement → Write Back
// Kumbha (Water)   - Flow, Distribution → Register update
// Meena (Fish)     - Completion, End → Commit (cycle complete)
//
// =============================================================================
