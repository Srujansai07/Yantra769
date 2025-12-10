/*
 * ============================================================================
 * TESTBENCH - Vedic vs Conventional Multiplier Comparison
 * ============================================================================
 * 
 * Comprehensive testbench to verify correctness and compare performance
 * of Vedic Mathematics multiplier against conventional implementation
 * 
 * Tests include:
 * 1. Exhaustive testing for small bit widths
 * 2. Random testing for larger bit widths
 * 3. Edge cases (0, max values, powers of 2)
 * 4. Timing comparison
 * 
 * ============================================================================
 */

`timescale 1ns / 1ps

module tb_vedic_multiplier;

    // ========================================================================
    // Parameters
    // ========================================================================
    parameter TEST_WIDTH = 8;
    parameter NUM_RANDOM_TESTS = 1000;
    
    // ========================================================================
    // Test Signals
    // ========================================================================
    reg  [TEST_WIDTH-1:0]   a, b;
    wire [2*TEST_WIDTH-1:0] vedic_product;
    wire [2*TEST_WIDTH-1:0] conv_product;
    reg  [2*TEST_WIDTH-1:0] expected_product;
    
    // Performance counters
    integer pass_count = 0;
    integer fail_count = 0;
    integer test_num = 0;
    
    // Timing measurement
    real vedic_start, vedic_end, vedic_time;
    real conv_start, conv_end, conv_time;
    
    // ========================================================================
    // Device Under Test Instantiation
    // ========================================================================
    
    // Vedic Multiplier (our implementation)
    vedic_8bit_multiplier vedic_mult (
        .a(a),
        .b(b),
        .product(vedic_product)
    );
    
    // Conventional Multiplier (for comparison)
    conventional_8bit_multiplier conv_mult (
        .a(a),
        .b(b),
        .product(conv_product)
    );
    
    // ========================================================================
    // Test Procedures
    // ========================================================================
    
    // Check single multiplication
    task check_multiplication;
        input [TEST_WIDTH-1:0] test_a;
        input [TEST_WIDTH-1:0] test_b;
        begin
            a = test_a;
            b = test_b;
            expected_product = test_a * test_b;
            
            #10; // Wait for combinational logic to settle
            
            test_num = test_num + 1;
            
            // Check Vedic result
            if (vedic_product !== expected_product) begin
                fail_count = fail_count + 1;
                $display("FAIL Test %0d: %0d x %0d", test_num, test_a, test_b);
                $display("  Expected: %0d, Vedic Got: %0d", expected_product, vedic_product);
            end else begin
                pass_count = pass_count + 1;
            end
            
            // Verify conventional also matches (sanity check)
            if (conv_product !== expected_product) begin
                $display("WARNING: Conventional multiplier mismatch!");
                $display("  Expected: %0d, Conv Got: %0d", expected_product, conv_product);
            end
        end
    endtask
    
    // ========================================================================
    // Main Test Sequence
    // ========================================================================
    
    initial begin
        $display("==============================================");
        $display("YANTRA769: Vedic Multiplier Testbench");
        $display("==============================================");
        $display("Testing %0d-bit Vedic Mathematics Multiplier", TEST_WIDTH);
        $display("Algorithm: Urdhva Tiryagbhyam (Vertically & Crosswise)");
        $display("==============================================\n");
        
        // Initialize
        a = 0;
        b = 0;
        
        // --------------------------------------------------------------------
        // Test 1: Edge Cases
        // --------------------------------------------------------------------
        $display("Test Phase 1: Edge Cases");
        $display("------------------------");
        
        // Zero multiplication
        check_multiplication(0, 0);
        check_multiplication(0, 8'hFF);
        check_multiplication(8'hFF, 0);
        
        // Identity (multiply by 1)
        check_multiplication(1, 1);
        check_multiplication(1, 8'hAB);
        check_multiplication(8'hCD, 1);
        
        // Maximum values
        check_multiplication(8'hFF, 8'hFF);
        
        // Powers of 2
        check_multiplication(2, 2);
        check_multiplication(4, 4);
        check_multiplication(8, 8);
        check_multiplication(16, 16);
        check_multiplication(128, 2);
        
        $display("Edge cases completed: %0d passed, %0d failed\n", 
                 pass_count, fail_count);
        
        // --------------------------------------------------------------------
        // Test 2: Sequential Pattern Tests
        // --------------------------------------------------------------------
        $display("Test Phase 2: Sequential Patterns");
        $display("----------------------------------");
        
        // Small number exhaustive test
        for (a = 0; a < 16; a = a + 1) begin
            for (b = 0; b < 16; b = b + 1) begin
                check_multiplication(a, b);
            end
        end
        
        $display("Sequential tests completed: %0d passed, %0d failed\n", 
                 pass_count, fail_count);
        
        // --------------------------------------------------------------------
        // Test 3: Random Tests
        // --------------------------------------------------------------------
        $display("Test Phase 3: Random Tests (%0d iterations)", NUM_RANDOM_TESTS);
        $display("--------------------------------------------");
        
        repeat (NUM_RANDOM_TESTS) begin
            check_multiplication($random, $random);
        end
        
        $display("Random tests completed: %0d passed, %0d failed\n", 
                 pass_count, fail_count);
        
        // --------------------------------------------------------------------
        // Test 4: Performance Comparison (Simulation Time)
        // --------------------------------------------------------------------
        $display("Test Phase 4: Performance Comparison");
        $display("------------------------------------");
        
        // Measure Vedic multiplier response
        a = 8'hA5;
        b = 8'h5A;
        vedic_start = $realtime;
        #1; // Minimal delay to trigger evaluation
        vedic_end = $realtime;
        vedic_time = vedic_end - vedic_start;
        
        // Note: In simulation, timing is simulated. 
        // Real comparison requires synthesis reports.
        $display("Simulation timing captured (synthesis needed for real timing)");
        $display("  Vedic result:        %0d x %0d = %0d", a, b, vedic_product);
        $display("  Conventional result: %0d x %0d = %0d", a, b, conv_product);
        
        // --------------------------------------------------------------------
        // Final Summary
        // --------------------------------------------------------------------
        $display("\n==============================================");
        $display("FINAL TEST SUMMARY");
        $display("==============================================");
        $display("Total Tests:  %0d", test_num);
        $display("Passed:       %0d", pass_count);
        $display("Failed:       %0d", fail_count);
        $display("Pass Rate:    %0.2f%%", (pass_count * 100.0) / test_num);
        
        if (fail_count == 0) begin
            $display("\n*** ALL TESTS PASSED - VEDIC MULTIPLIER VERIFIED ***");
            $display("The Urdhva Tiryagbhyam algorithm is correctly implemented!");
        end else begin
            $display("\n*** SOME TESTS FAILED - REVIEW REQUIRED ***");
        end
        
        $display("==============================================");
        $display("\nVEDIC MATHEMATICS ADVANTAGE:");
        $display("- Parallel partial product generation");
        $display("- Reduced critical path through crosswise multiplication");
        $display("- Regular structure ideal for VLSI layout");
        $display("- Typically 20-45%% improvement over conventional");
        $display("==============================================\n");
        
        $finish;
    end
    
    // ========================================================================
    // Waveform Dump for Analysis
    // ========================================================================
    initial begin
        $dumpfile("vedic_multiplier_tb.vcd");
        $dumpvars(0, tb_vedic_multiplier);
    end

endmodule
