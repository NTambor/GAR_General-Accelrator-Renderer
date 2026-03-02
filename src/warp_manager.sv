`default_nettype none
`timescale 1ns/1ns

/* Warp Builder
* The goal of this block to the split up the jobs of the warp schedular into more digestable jobs
* this job is to take the thread that are sent the the SM and the put them into groups called warps.
* A warp is a group of threads of a static size difined by the archtecter that are to be run in parallel on a core.
* In industy the warp size is a static 32 threads in the case of GAR the user will be able to set the size of warps.
* The Module will also be responcable for reodering warps if that is required
* Inputs 
* (Threads, Next_PCs, Thread_count)
* Outputs
* (Warps_id, Num_Warps)
*/

module warp_manager #(
    parameter THREADS_PER_WARP = 32,
    parameter THREADS_PER_BLOCK = 256,
    parameter WARPS_PER_CORE = 8
    )(
    input wire clk,
    input wire reset,
    input wire start,
    //input reg [WARPS_PER_CORE:0] done,
    input wire [7:0] warps_states [WARPS_PER_CORE-1:0],
    input wire [1:0] warp_status [WARPS_PER_CORE-1:0],

    output reg [3:0] warp_ids [THREADS_PER_BLOCK-1:0],
    output reg [$clog2(THREADS_PER_BLOCK):0] thread_count,
    output reg done
);
    // Calculate the total number of blocks based on total threads & threads per block
    wire [7:0] total_warps;
    assign total_warps = (thread_count + THREADS_PER_WARP - 1) / THREADS_PER_WARP;

    // Keep track of how many warps have been processed
    reg [7:0] warps_dispatched; // What warps have been dispatched
    reg [7:0] warps_done; // How many blocks have finished processing?
    reg start_execution; // EDA: Unimportant hack used because of EDA tooling

    always @(posedge clk) begin
        if (reset) begin
            warps_done <= 0;
            start_execution <=0;
            for (int i = 1; i < THREADS_PER_BLOCK; i++) begin
                    warp_ids[i] <= (THREADS_PER_BLOCK/THREADS_PER_WARP);
            end
        end else if (start) begin   
            if (!start_execution) begin 
                for (int i = 0; i < WARPS_PER_CORE; i++) begin
                    for (int j = 0;  j< THREADS_PER_WARP; j++) begin
                        warp_ids[(THREADS_PER_WARP*i)+j] <= i;
                    end
                end
                start_execution <=1;
            end
            if (warps_done == total_warps) begin 
                done <= 1;
            end

            /*TODO: change this for loop and if statement to deal with
            * done warps and not blocks and to reorder the curren
            */
            for (int i = 0; i < WARPS_PER_CORE; i++) begin
                if ((warps_states[i] == 3'b111) && (i < total_warps)) begin
                    // If a core just finished executing it's current block, reset it
                    //warp_
                    warps_done = warps_done + 1;
                end
            end
        end
    end
endmodule