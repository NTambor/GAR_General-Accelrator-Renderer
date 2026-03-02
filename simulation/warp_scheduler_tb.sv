`default_nettype none
`timescale 1ns/1ns
/* This is the test bench file for the warp scheduler
* in this file the warp scheduler must be tested in it ability 
* to create warps from a thread block
* output warps to fetcher and computer cores
* manage warps as they are returned
*/ 
module tb_warp_scheduler #(
    parameter THREADS_PER_BLOCK = 4;
    parameter WARPS_PER_CORE = 2;
)();
    logic clk;
    logic reset[WARPS_PER_CORE-1:0];
    logic start[WARPS_PER_CORE-1:0];
    logic [$clog2(THREADS_PER_BLOCK):0] thread_count;

    // Control Signals
    logic decoded_mem_read_enable;
    logic decoded_mem_write_enable;
    logic decoded_ret;

    // Memory Access State
    logic [2:0] fetcher_state;
    logic [1:0] lsu_state [THREADS_PER_BLOCK-1:0];

    //TODO: warp output controlls; need to be able send out warp masks
    // needs to get back when a warp is finished executing in the pipeline
    // need to send out warp groups for threads
    //Warp controlls
    logic [$clog2(WARPS_PER_CORE):0]warp_index;
    logic [$clog2(WARPS_PER_CORE):0]warp_groups[THREADS_PER_BLOCK-1:0];
    logic [THREADS_PER_BLOCK-1:0] masks [WARPS_PER_CORE-1:0];

    // Current & Next PC
    logic [7:0] current_pc;
    logic [7:0] next_pc [THREADS_PER_BLOCK-1:0];

    // Execution State
    logic [2:0] core_state;
    logic[3:0] warp;
    logic done;


    warp_scheduler warp_scheduler_instance(
        .clk(clk), .reset(reset), .start(start), 
        .thread_count(thread_count),
        .decoded_mem_read_enable(decoded_mem_read_enable),
        .decoded_mem_write_enable(decoded_mem_write_enable),
        .decoded_ret(decoded_ret),
        .fetcher_state(fetcher_state),
        .lsu_state(lsu_state),
        .warp_index(warp_index),
        .warp_groups(warp_groups),
        .masks(masks),
        .current_pc(current_pc),
        .next_pc(next_pc),
        .core_state(core_state),
        .warp(warp),
        .done(done)
    )
    initial begin
        clk = 0;
        forever clk = ~clk; #5;
    end
    initial begin
        $dumpfile(“warp_scheduler.vcd”);
        $dumpvars(0, tb_warp_scheduler);
    end



endmodule