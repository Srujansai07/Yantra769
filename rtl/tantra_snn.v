/*
 * ============================================================================
 * SPIKING NEURAL NETWORK (SNN) - Tantra Recursive Feedback Module
 * ============================================================================
 * 
 * Implements neuromorphic computing with recursive feedback loops.
 * 
 * This is the "Tantra" module - the infinite loop that learns:
 * - Spiking neurons (event-driven, not continuous)
 * - Recurrent connections (feedback loops)
 * - Hebbian learning (neurons that fire together wire together)
 * - Self-correction through feedback
 * 
 * Unlike standard AI that processes linearly:
 *   Standard: Input -> Process -> Output (done)
 * 
 * Tantra architecture:
 *   Input -> Process -> Output -> Feedback -> Process again
 *           (Loop continues until convergence or paradox detection)
 * 
 * Based on: Neuromorphic computing, Spiking Neural Networks
 * 
 * ============================================================================
 */

`timescale 1ns / 1ps

// ============================================================================
// LEAKY INTEGRATE-AND-FIRE NEURON
// ============================================================================
// Models biological neuron: accumulates input, fires when threshold reached

module lif_neuron #(
    parameter POTENTIAL_WIDTH = 16,
    parameter THRESHOLD = 16'd40000,
    parameter LEAK_RATE = 16'd100,      // Leak per cycle
    parameter REFRACTORY_PERIOD = 8     // Cycles after spike
)(
    input  wire                       clk,
    input  wire                       rst_n,
    
    // Synaptic inputs (weighted)
    input  wire [POTENTIAL_WIDTH-1:0] synaptic_input,
    input  wire                       input_valid,
    
    // Feedback from downstream neurons (Tantra loop)
    input  wire [POTENTIAL_WIDTH-1:0] feedback_input,
    input  wire                       feedback_valid,
    
    // Spike output
    output reg                        spike,
    output reg [POTENTIAL_WIDTH-1:0]  membrane_potential,
    
    // State
    output reg                        is_refractory
);
    reg [3:0] refractory_counter;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            membrane_potential <= 0;
            spike <= 0;
            is_refractory <= 0;
            refractory_counter <= 0;
        end else begin
            spike <= 0;  // Default: no spike
            
            if (is_refractory) begin
                // In refractory period - cannot fire
                refractory_counter <= refractory_counter - 1;
                if (refractory_counter == 0) begin
                    is_refractory <= 0;
                end
            end else begin
                // Integrate phase: accumulate inputs
                if (input_valid) begin
                    membrane_potential <= membrane_potential + synaptic_input;
                end
                
                // Tantra feedback: add feedback signal (recursive learning)
                if (feedback_valid) begin
                    membrane_potential <= membrane_potential + (feedback_input >> 1);
                end
                
                // Leak phase: gradual decay
                if (membrane_potential > LEAK_RATE) begin
                    membrane_potential <= membrane_potential - LEAK_RATE;
                end else begin
                    membrane_potential <= 0;
                end
                
                // Fire phase: check threshold
                if (membrane_potential >= THRESHOLD) begin
                    spike <= 1;
                    membrane_potential <= 0;  // Reset after spike
                    is_refractory <= 1;
                    refractory_counter <= REFRACTORY_PERIOD;
                end
            end
        end
    end

endmodule

// ============================================================================
// SYNAPSE WITH HEBBIAN LEARNING
// ============================================================================
// "Neurons that fire together, wire together"
// Weight increases when pre and post neurons spike together

module hebbian_synapse #(
    parameter WEIGHT_WIDTH = 8,
    parameter INITIAL_WEIGHT = 8'd128,
    parameter LEARNING_RATE = 8'd4,
    parameter MAX_WEIGHT = 8'd255,
    parameter MIN_WEIGHT = 8'd1
)(
    input  wire                   clk,
    input  wire                   rst_n,
    
    // Pre-synaptic (input) spike
    input  wire                   pre_spike,
    
    // Post-synaptic (output) spike - for Hebbian learning
    input  wire                   post_spike,
    
    // Input data
    input  wire [15:0]            input_data,
    input  wire                   input_valid,
    
    // Weighted output
    output wire [15:0]            weighted_output,
    output reg                    output_valid,
    
    // Current weight (observable)
    output reg [WEIGHT_WIDTH-1:0] weight
);
    // Temporal window for spike-timing dependent plasticity
    reg [3:0] pre_spike_history;
    reg [3:0] post_spike_history;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            weight <= INITIAL_WEIGHT;
            pre_spike_history <= 0;
            post_spike_history <= 0;
        end else begin
            // Track spike timing
            pre_spike_history <= {pre_spike_history[2:0], pre_spike};
            post_spike_history <= {post_spike_history[2:0], post_spike};
            
            // Hebbian learning rule
            // If pre-spike followed by post-spike: strengthen (LTP)
            if (pre_spike_history[1] && post_spike) begin
                if (weight < MAX_WEIGHT - LEARNING_RATE) begin
                    weight <= weight + LEARNING_RATE;
                end else begin
                    weight <= MAX_WEIGHT;
                end
            end
            // If post-spike followed by pre-spike: weaken (LTD)  
            else if (post_spike_history[1] && pre_spike) begin
                if (weight > MIN_WEIGHT + LEARNING_RATE) begin
                    weight <= weight - LEARNING_RATE;
                end else begin
                    weight <= MIN_WEIGHT;
                end
            end
        end
    end
    
    // Apply weight to input
    assign weighted_output = (input_data * weight) >> 8;
    
    always @(posedge clk) begin
        output_valid <= input_valid;
    end

endmodule

// ============================================================================
// TANTRA LAYER - Recurrent Neural Layer with Feedback
// ============================================================================

module tantra_layer #(
    parameter NUM_NEURONS = 8,
    parameter INPUT_WIDTH = 16
)(
    input  wire                           clk,
    input  wire                           rst_n,
    
    // External input
    input  wire [NUM_NEURONS*INPUT_WIDTH-1:0] layer_input,
    input  wire                               input_valid,
    
    // Feedback from next layer (or output feedback)
    input  wire [NUM_NEURONS-1:0]             feedback_spikes,
    
    // Layer output
    output wire [NUM_NEURONS-1:0]             layer_spikes,
    output wire [NUM_NEURONS*INPUT_WIDTH-1:0] layer_potentials,
    
    // Convergence detection
    output reg                                converged,
    output reg [7:0]                          iteration_count
);
    // Internal feedback (recurrent connections within layer)
    wire [INPUT_WIDTH-1:0] internal_feedback [0:NUM_NEURONS-1];
    
    // Convergence tracking
    reg [NUM_NEURONS-1:0] prev_spikes;
    reg [3:0] stable_count;
    
    genvar n;
    generate
        for (n = 0; n < NUM_NEURONS; n = n + 1) begin : neuron_gen
            
            // Synapse for external input
            wire [INPUT_WIDTH-1:0] weighted_input;
            wire input_syn_valid;
            
            hebbian_synapse input_syn (
                .clk(clk),
                .rst_n(rst_n),
                .pre_spike(input_valid),
                .post_spike(layer_spikes[n]),
                .input_data(layer_input[n*INPUT_WIDTH +: INPUT_WIDTH]),
                .input_valid(input_valid),
                .weighted_output(weighted_input),
                .output_valid(input_syn_valid),
                .weight()
            );
            
            // Feedback synapse (Tantra recurrence)
            wire [INPUT_WIDTH-1:0] weighted_feedback;
            
            hebbian_synapse feedback_syn (
                .clk(clk),
                .rst_n(rst_n),
                .pre_spike(feedback_spikes[(n+1) % NUM_NEURONS]),
                .post_spike(layer_spikes[n]),
                .input_data({8'b0, internal_feedback[(n+1) % NUM_NEURONS][7:0]}),
                .input_valid(|feedback_spikes),
                .weighted_output(weighted_feedback),
                .output_valid(),
                .weight()
            );
            
            // Neuron
            wire [INPUT_WIDTH-1:0] combined_input = weighted_input + weighted_feedback;
            
            lif_neuron neuron (
                .clk(clk),
                .rst_n(rst_n),
                .synaptic_input(combined_input),
                .input_valid(input_syn_valid),
                .feedback_input(weighted_feedback),
                .feedback_valid(|feedback_spikes),
                .spike(layer_spikes[n]),
                .membrane_potential(layer_potentials[n*INPUT_WIDTH +: INPUT_WIDTH]),
                .is_refractory()
            );
            
            // Internal feedback path
            assign internal_feedback[n] = layer_potentials[n*INPUT_WIDTH +: INPUT_WIDTH];
        end
    endgenerate
    
    // Convergence detection: when spike pattern stabilizes
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            prev_spikes <= 0;
            stable_count <= 0;
            converged <= 0;
            iteration_count <= 0;
        end else begin
            prev_spikes <= layer_spikes;
            iteration_count <= iteration_count + 1;
            
            if (layer_spikes == prev_spikes && |layer_spikes) begin
                // Pattern is stable
                stable_count <= stable_count + 1;
                if (stable_count >= 4) begin
                    converged <= 1;
                end
            end else begin
                stable_count <= 0;
                converged <= 0;
            end
        end
    end

endmodule

// ============================================================================
// TANTRA CORE - Complete Recursive Feedback Network
// ============================================================================

module tantra_core #(
    parameter NUM_LAYERS = 3,
    parameter NEURONS_PER_LAYER = 8,
    parameter DATA_WIDTH = 16
)(
    input  wire                     clk,
    input  wire                     rst_n,
    
    // Input data
    input  wire [DATA_WIDTH*NEURONS_PER_LAYER-1:0] data_in,
    input  wire                     data_valid,
    
    // Output
    output wire [NEURONS_PER_LAYER-1:0] output_spikes,
    output wire                     output_valid,
    output wire                     network_converged,
    
    // Loop detection (Anavastha)
    output reg                      loop_detected,
    output reg [7:0]                total_iterations
);
    // Inter-layer connections
    wire [NEURONS_PER_LAYER-1:0] layer_spikes [0:NUM_LAYERS-1];
    wire [DATA_WIDTH*NEURONS_PER_LAYER-1:0] layer_potentials [0:NUM_LAYERS-1];
    wire [NUM_LAYERS-1:0] layer_converged;
    wire [7:0] layer_iterations [0:NUM_LAYERS-1];
    
    // Tantra feedback: output loops back to input
    wire [NEURONS_PER_LAYER-1:0] output_feedback = layer_spikes[NUM_LAYERS-1];
    
    genvar L;
    generate
        for (L = 0; L < NUM_LAYERS; L = L + 1) begin : layer_gen
            
            wire [DATA_WIDTH*NEURONS_PER_LAYER-1:0] layer_input;
            wire layer_input_valid;
            wire [NEURONS_PER_LAYER-1:0] feedback;
            
            if (L == 0) begin : first_layer
                // First layer receives external input + Tantra feedback
                assign layer_input = data_in;
                assign layer_input_valid = data_valid;
                assign feedback = output_feedback;  // TANTRA: Output -> Input loop
            end else begin : hidden_layer
                // Hidden layers receive from previous layer
                assign layer_input = layer_potentials[L-1];
                assign layer_input_valid = |layer_spikes[L-1];
                assign feedback = layer_spikes[L-1];
            end
            
            tantra_layer #(
                .NUM_NEURONS(NEURONS_PER_LAYER),
                .INPUT_WIDTH(DATA_WIDTH)
            ) layer (
                .clk(clk),
                .rst_n(rst_n),
                .layer_input(layer_input),
                .input_valid(layer_input_valid),
                .feedback_spikes(feedback),
                .layer_spikes(layer_spikes[L]),
                .layer_potentials(layer_potentials[L]),
                .converged(layer_converged[L]),
                .iteration_count(layer_iterations[L])
            );
        end
    endgenerate
    
    // Network-wide convergence
    assign output_spikes = layer_spikes[NUM_LAYERS-1];
    assign output_valid = layer_converged[NUM_LAYERS-1];
    assign network_converged = &layer_converged;
    
    // Loop detection: if iterations exceed threshold without convergence
    localparam MAX_ITERATIONS = 200;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            loop_detected <= 0;
            total_iterations <= 0;
        end else begin
            total_iterations <= layer_iterations[0];  // Track first layer
            
            if (total_iterations >= MAX_ITERATIONS && !network_converged) begin
                loop_detected <= 1;  // Anavastha detected!
            end else if (network_converged) begin
                loop_detected <= 0;
            end
        end
    end

endmodule
