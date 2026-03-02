`default_nettype none
`timescale 1ns/1ns

module tb_warp_manager();

    // -----------------------------------------
    // Parameters
    // -----------------------------------------
    parameter THREADS_PER_WARP = 32;
    parameter THREADS_PER_BLOCK = 256;
    parameter WARPS_PER_CORE = 8;

    // -----------------------------------------
    // Testbench Signals
    // -----------------------------------------
    logic clk;
    logic reset;
    logic start;
    
    // Note: Assuming 'done' is intended to be an output from the module
    wire [WARPS_PER_CORE:0] done; 
    
    // Note: Assuming 'thread_count' is intended to be an input to the module
    logic [$clog2(THREADS_PER_BLOCK):0] thread_count; 
    
    wire [3:0] warp_ids [$clog2(THREADS_PER_BLOCK):0];

    // -----------------------------------------
    // Instantiate the Unit Under Test (UUT)
    // -----------------------------------------
    warp_manager #(
        .THREADS_PER_WARP(THREADS_PER_WARP),
        .THREADS_PER_BLOCK(THREADS_PER_BLOCK),
        .WARPS_PER_CORE(WARPS_PER_CORE)
    ) uut (
        .clk(clk),
        .reset(reset),
        .start(start),
        .done(done),
        .warp_ids(warp_ids),
        .thread_count(thread_count)
    );

    // -----------------------------------------
    // Clock Generation
    // -----------------------------------------
    always #5 clk = ~clk; // 100MHz clock (10ns period)

    // -----------------------------------------
    // Waveform Generation
    // -----------------------------------------
    initial begin
        $dumpfile("waveform.vcd");   // Name of the output waveform file
        $dumpvars(0, tb_warp_builder); // Dump all variables in this module and below
        
        // Note: Dumping arrays (like warp_ids) in VCD format isn't supported 
        // by all simulators out-of-the-box. If using ModelSim/Questa, you might 
        // need simulator-specific commands or use SystemVerilog $monitor for arrays.
    end

    // -----------------------------------------
    // Test Stimulus
    // -----------------------------------------
    initial begin
        // 1. Initialize signals
        clk = 0;
        reset = 1;
        start = 0;
        thread_count = 256; // Example input value

        // 2. Hold reset for a few clock cycles
        #20;
        reset = 0;
        
        // 3. Trigger the start signal
        #10;
        start = 1;
        
        // 4. Drop start signal after one clock cycle (like a pulse)
        #10;
        start = 0;

        // 5. Wait for the module to process
        #200;

        // 6. Test with a different thread count
        thread_count = 128;
        start = 1;
        #10;
        start = 0;

        #200;

        // End simulation
        $display("Simulation complete. Check waveform.vcd for timing details.");
        $finish;
    end

endmodule