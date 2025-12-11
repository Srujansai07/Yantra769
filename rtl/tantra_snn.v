/*
 * TANTRA SPIKING NEURAL NETWORK - COMPLETE IMPLEMENTATION
 * ========================================================
 * Based on तन्त्र principles from Vedas and Shastras
 * 
 * Key Mappings:
 * - Kundalini (कुण्डलिनी) → Power/Energy accumulation
 * - 7 Chakras (चक्र) → 7 Processing layers
 * - Ida/Pingala → Excitatory/Inhibitory pathways
 * - Sushumna → Central data path
 * - STDP Learning → Tantric transformation (tapas/vairagya)
 * 
 * Architecture:
 * - 8 LIF neurons per layer (8 lotus petals)
 * - 7 layers total (7 chakras)
 * - Fully connected with learnable weights
 * - STDP-based weight updates
 * 
 * Author: SIVAA Project
 * Date: December 2025
 */

module tantra_snn #(
    parameter NUM_LAYERS = 7,      // 7 Chakras
    parameter NEURONS_PER_LAYER = 8,  // 8 lotus petals
    parameter DATA_WIDTH = 16,
    parameter WEIGHT_WIDTH = 8,
    parameter THRESHOLD = 100,     // Spike threshold
    parameter LEAK_SHIFT = 4       // Leak = V >> 4 (1/16)
)(
    input  wire                    clk,
    input  wire                    rst_n,
    
    // Input spikes (from sensors/previous layer)
    input  wire [NEURONS_PER_LAYER-1:0] input_spikes,
    input  wire [7:0]              input_current [0:NEURONS_PER_LAYER-1],
    
    // Output spikes (to actuators/next system)
    output wire [NEURONS_PER_LAYER-1:0] output_spikes,
    
    // Learning control
    input  wire                    learning_enable,
    input  wire [7:0]              learning_rate,   // STDP rate
    
    // Kundalini status (energy flow visualization)
    output wire [NUM_LAYERS-1:0]   chakra_active,
    output wire [DATA_WIDTH-1:0]   total_energy,
    
    // Debug
    output wire [7:0]              spike_count
);

    // =========================================================================
    // 7 CHAKRAS (चक्र) - Energy Centers / Processing Layers
    // =========================================================================
    // 
    // Chakra 0: Muladhara (मूलाधार) - Root - Input layer
    // Chakra 1: Svadhisthana (स्वाधिष्ठान) - Sacral
    // Chakra 2: Manipura (मणिपूर) - Solar Plexus
    // Chakra 3: Anahata (अनाहत) - Heart - Middle layer
    // Chakra 4: Vishuddha (विशुद्ध) - Throat
    // Chakra 5: Ajna (आज्ञा) - Third Eye
    // Chakra 6: Sahasrara (सहस्रार) - Crown - Output layer
    //
    // =========================================================================

    // Membrane potentials for all neurons
    reg [DATA_WIDTH-1:0] membrane_V [0:NUM_LAYERS-1][0:NEURONS_PER_LAYER-1];
    
    // Spike outputs for all neurons
    reg [NEURONS_PER_LAYER-1:0] layer_spikes [0:NUM_LAYERS-1];
    
    // Synaptic weights (fully connected between layers)
    reg signed [WEIGHT_WIDTH-1:0] weights [0:NUM_LAYERS-2][0:NEURONS_PER_LAYER-1][0:NEURONS_PER_LAYER-1];
    
    // Spike timing for STDP
    reg [7:0] spike_time [0:NUM_LAYERS-1][0:NEURONS_PER_LAYER-1];
    reg [7:0] global_time;
    
    // Energy accumulator
    reg [DATA_WIDTH-1:0] energy_sum;
    
    // =========================================================================
    // MULADHARA (मूलाधार) - ROOT CHAKRA - Input Layer
    // =========================================================================
    
    genvar i;
    generate
        for (i = 0; i < NEURONS_PER_LAYER; i = i + 1) begin : muladhara_neurons
            always @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    membrane_V[0][i] <= 16'd0;
                    layer_spikes[0][i] <= 1'b0;
                    spike_time[0][i] <= 8'd0;
                end else begin
                    // Kundalini awakening from external input
                    if (input_spikes[i]) begin
                        membrane_V[0][i] <= membrane_V[0][i] + {8'd0, input_current[i]};
                    end
                    
                    // Leak (prana dissipation)
                    membrane_V[0][i] <= membrane_V[0][i] - (membrane_V[0][i] >> LEAK_SHIFT);
                    
                    // Fire (kundalini release)
                    if (membrane_V[0][i] >= THRESHOLD) begin
                        layer_spikes[0][i] <= 1'b1;
                        membrane_V[0][i] <= 16'd0;
                        spike_time[0][i] <= global_time;
                    end else begin
                        layer_spikes[0][i] <= 1'b0;
                    end
                end
            end
        end
    endgenerate
    
    // =========================================================================
    // INTERMEDIATE CHAKRAS (1-5) - Hidden Layers
    // =========================================================================
    
    genvar layer, neuron, pre;
    generate
        for (layer = 1; layer < NUM_LAYERS - 1; layer = layer + 1) begin : chakra_layers
            for (neuron = 0; neuron < NEURONS_PER_LAYER; neuron = neuron + 1) begin : chakra_neurons
                
                // Calculate weighted sum from previous layer
                reg signed [DATA_WIDTH+8:0] weighted_sum;
                
                always @(posedge clk or negedge rst_n) begin
                    if (!rst_n) begin
                        membrane_V[layer][neuron] <= 16'd0;
                        layer_spikes[layer][neuron] <= 1'b0;
                        spike_time[layer][neuron] <= 8'd0;
                    end else begin
                        // Integrate inputs from previous chakra
                        weighted_sum = 0;
                        for (pre = 0; pre < NEURONS_PER_LAYER; pre = pre + 1) begin
                            if (layer_spikes[layer-1][pre]) begin
                                weighted_sum = weighted_sum + 
                                    {{(DATA_WIDTH+1){weights[layer-1][pre][neuron][WEIGHT_WIDTH-1]}}, 
                                     weights[layer-1][pre][neuron]};
                            end
                        end
                        
                        // Update membrane potential
                        if (weighted_sum > 0) begin
                            membrane_V[layer][neuron] <= membrane_V[layer][neuron] + weighted_sum[DATA_WIDTH-1:0];
                        end
                        
                        // Leak
                        membrane_V[layer][neuron] <= membrane_V[layer][neuron] - 
                                                     (membrane_V[layer][neuron] >> LEAK_SHIFT);
                        
                        // Fire
                        if (membrane_V[layer][neuron] >= THRESHOLD) begin
                            layer_spikes[layer][neuron] <= 1'b1;
                            membrane_V[layer][neuron] <= 16'd0;
                            spike_time[layer][neuron] <= global_time;
                        end else begin
                            layer_spikes[layer][neuron] <= 1'b0;
                        end
                    end
                end
            end
        end
    endgenerate
    
    // =========================================================================
    // SAHASRARA (सहस्रार) - CROWN CHAKRA - Output Layer
    // =========================================================================
    
    generate
        for (i = 0; i < NEURONS_PER_LAYER; i = i + 1) begin : sahasrara_neurons
            always @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    membrane_V[NUM_LAYERS-1][i] <= 16'd0;
                    layer_spikes[NUM_LAYERS-1][i] <= 1'b0;
                    spike_time[NUM_LAYERS-1][i] <= 8'd0;
                end else begin
                    // Same LIF dynamics as intermediate layers
                    // (Crown chakra represents final enlightenment/output)
                    
                    // Leak
                    membrane_V[NUM_LAYERS-1][i] <= membrane_V[NUM_LAYERS-1][i] - 
                                                   (membrane_V[NUM_LAYERS-1][i] >> LEAK_SHIFT);
                    
                    // Fire
                    if (membrane_V[NUM_LAYERS-1][i] >= THRESHOLD) begin
                        layer_spikes[NUM_LAYERS-1][i] <= 1'b1;
                        membrane_V[NUM_LAYERS-1][i] <= 16'd0;
                        spike_time[NUM_LAYERS-1][i] <= global_time;
                    end else begin
                        layer_spikes[NUM_LAYERS-1][i] <= 1'b0;
                    end
                end
            end
        end
    endgenerate
    
    // Output assignment
    assign output_spikes = layer_spikes[NUM_LAYERS-1];
    
    // =========================================================================
    // STDP LEARNING - TANTRIC TRANSFORMATION
    // =========================================================================
    // 
    // तपस् (Tapas) - Pre before Post → Strengthen connection
    // वैराग्य (Vairagya) - Post before Pre → Weaken connection
    //
    // =========================================================================
    
    generate
        for (layer = 0; layer < NUM_LAYERS - 1; layer = layer + 1) begin : stdp_layers
            for (pre = 0; pre < NEURONS_PER_LAYER; pre = pre + 1) begin : stdp_pre
                for (neuron = 0; neuron < NEURONS_PER_LAYER; neuron = neuron + 1) begin : stdp_post
                    
                    always @(posedge clk or negedge rst_n) begin
                        if (!rst_n) begin
                            // Initialize weights (random-ish based on position)
                            weights[layer][pre][neuron] <= (pre + neuron + layer) & 8'h3F;
                        end else if (learning_enable) begin
                            // STDP update when post-synaptic neuron fires
                            if (layer_spikes[layer+1][neuron]) begin
                                // Calculate timing difference
                                if (spike_time[layer][pre] < spike_time[layer+1][neuron]) begin
                                    // Pre before Post → Tapas (strengthen)
                                    if (weights[layer][pre][neuron] < 127) begin
                                        weights[layer][pre][neuron] <= weights[layer][pre][neuron] + 
                                                                       (learning_rate >> 4);
                                    end
                                end else begin
                                    // Post before Pre → Vairagya (weaken)
                                    if (weights[layer][pre][neuron] > -128) begin
                                        weights[layer][pre][neuron] <= weights[layer][pre][neuron] - 
                                                                       (learning_rate >> 4);
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    endgenerate
    
    // =========================================================================
    // GLOBAL TIME COUNTER
    // =========================================================================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            global_time <= 8'd0;
        end else begin
            global_time <= global_time + 8'd1;
        end
    end
    
    // =========================================================================
    // KUNDALINI STATUS - Energy Flow Visualization
    // =========================================================================
    
    // Chakra active indicators (1 if any neuron in layer spiked)
    generate
        for (layer = 0; layer < NUM_LAYERS; layer = layer + 1) begin : chakra_status
            assign chakra_active[layer] = |layer_spikes[layer];
        end
    endgenerate
    
    // Total energy (sum of all membrane potentials)
    integer l, n;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            energy_sum <= 16'd0;
        end else begin
            energy_sum <= 16'd0;
            for (l = 0; l < NUM_LAYERS; l = l + 1) begin
                for (n = 0; n < NEURONS_PER_LAYER; n = n + 1) begin
                    energy_sum <= energy_sum + membrane_V[l][n];
                end
            end
        end
    end
    assign total_energy = energy_sum;
    
    // Spike counter (total spikes in last cycle)
    reg [7:0] spike_cnt;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            spike_cnt <= 8'd0;
        end else begin
            spike_cnt <= 8'd0;
            for (l = 0; l < NUM_LAYERS; l = l + 1) begin
                for (n = 0; n < NEURONS_PER_LAYER; n = n + 1) begin
                    spike_cnt <= spike_cnt + layer_spikes[l][n];
                end
            end
        end
    end
    assign spike_count = spike_cnt;

endmodule

// =============================================================================
// CHAKRA CORRESPONDENCE TABLE
// =============================================================================
//
// Layer 0 - Muladhara    (Root)        - Input/Grounding
// Layer 1 - Svadhisthana (Sacral)      - First hidden
// Layer 2 - Manipura     (Solar Plexus) - Second hidden
// Layer 3 - Anahata      (Heart)        - Middle (key transition)
// Layer 4 - Vishuddha    (Throat)       - Fourth hidden
// Layer 5 - Ajna         (Third Eye)    - Fifth hidden (intuition)
// Layer 6 - Sahasrara    (Crown)        - Output/Enlightenment
//
// =============================================================================
