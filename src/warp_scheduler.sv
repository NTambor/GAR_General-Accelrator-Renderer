`default_nettype none
`timescale 1ns/1ns

// SCHEDULER
// > Manages the entire control flow of a single compute core processing 1 block
// 1. FETCH - Retrieve instruction at current program counter (PC) from program memory
// 2. DECODE - Decode the instruction into the relevant control signals
// 3. REQUEST - If we have an instruction that accesses memory, trigger the async memory requests from LSUs
// 4. WAIT - Wait for all async memory requests to resolve (if applicable)
// 5. EXECUTE - Execute computations on retrieved data from registers / memory
// 6. UPDATE - Update register values (including NZP register) and program counter
// > Each core has it's own scheduler where multiple threads can be processed with
//   the same control flow at once.
// > Technically, different instructions can branch to different PCs, requiring "branch divergence." In
//   this minimal implementation, we assume no branch divergence (naive approach for simplicity)
module warp_scheduler #(
    parameter THREADS_PER_BLOCK = 8,
    parameter THREADS_PER_WARP = 4,
    parameter WARPS_PER_CORE = 2,
) (
    input wire clk,
    input wire reset,
    input wire start,
    input wire [$clog2(THREADS_PER_BLOCK):0] thread_count,

    // Control Signals
    input reg decoded_mem_read_enable,
    input reg decoded_mem_write_enable,
    input reg decoded_ret,

    // Memory Access State
    input reg [2:0] fetcher_state,
    input reg [1:0] lsu_state [THREADS_PER_BLOCK-1:0],

    //TODO: warp output controlls, need to be able send out warp masks
    // needs to get back when a warp is finished executing in the pipeline
    // need to send out warp groups for threads
    //Warp controlls
    input reg [$clog2(WARPS_PER_CORE):0]warp_index,
    output wire [$clog2(WARPS_PER_CORE):0]warp_groups[THREADS_PER_BLOCK-1:0],
    output reg [THREADS_PER_WARP-1:0] masks [WARPS_PER_CORE-1:0],

    // Current & Next PC
    output reg [7:0] current_pc,
    input reg [7:0] next_pc [THREADS_PER_BLOCK-1:0],

    // Execution State
    output reg [2:0] core_state,
    output reg[3:0] warp,
    output reg done
);
    //warp meta data
    reg [7:0] warps_states [WARPS_PER_CORE-1:0];
    reg [1:0] warp_status [WARPS_PER_CORE-1:0];
    reg [7:0] warp_pcs[WARPS_PER_CORE-1:0];
    reg [$clog2(WARPS_PER_CORE):0] next_warp;
    reg [WARPS_PER_CORE:0] start_warp;

    localparam 
        READY = 2'b00, // Ready to be swaped to
        STALL = 3'b01,       // Warp is currently Stalled
        MASKED = 2'b10,      // The warp is currently diverged and is masked
        SCHEDULED = 2'b11,     // There is no warp
        IDLE = 3'b000, // Waiting to start
        FETCH = 3'b001,       // Fetch instructions from program memory
        DECODE = 3'b010,      // Decode instructions into control signals
        REQUEST = 3'b011,     // Request data from registers or memory
        WAIT = 3'b100,        // Wait for response from memory if necessary
        EXECUTE = 3'b101,     // Execute ALU and PC calculations
        UPDATE = 3'b110,      // Update registers, NZP, and PC
        DONE = 3'b111;        // Done executing this block
    

    warp_manager #(
        .THREADS_PER_WARP(THREADS_PER_WARP),
        .THREADS_PER_BLOCK(THREADS_PER_BLOCK),
        .WARPS_PER_CORE(WARPS_PER_CORE)
    ) warp_manager_instance (
        .clk(clk),
        .reset(reset),
        .start(start),
        .warps_states(warps_states),
        .warp_status(warp_status),
        .done(done),
        .warp_ids(warp_groups),
        .masks(masks),
        .thread_count(thread_count)
    );


    always @(posedge clk) begin 
        if (reset) begin
            current_pc <= 0;
            core_state <= IDLE;
            done <= 0;
            warp <=0;
        end else begin 
            // schedule warps, these warps are sent to the dispatcher that navigates them to the right 
            // compute path. Options Round robin schedule a differnet warp every clk cycle, or context switching 
            // schedule a differnt warp ever cycle 
            // if (fetcher_state == 3'b010) begin 
            //     if (warp_status[next_warp] == READY)begin
            //         warp <= next_warp;
            //         current_pc <=warp_pcs[next_warp];
            //         core_state <= warps_states[next_warp];
            //         warp_status[next_warp] <= STALL;
            //         next_warp <= next_warp+1;
            //     end
            //     for (int i = 1; i < WARPS_PER_CORE; i++)begin
            //         else if (warp_status[next_warp + i] == READY)begin
            //             warp <= (next_warp + i);
            //             current_pc <=warp_pcs[next_warp + i];
            //             core_state <= warps_states[next_warp + i];
            //             warp_status[next_warp + i] <= STALL;
            //             next_warp <= (next_warp+1);
            //         end
            //     end 
            // end
            //TODO: warp managment MAYBE MOVE TO WARP MANAGER
            // if (warp_return) begin
            //     if (decoded_ret) begin 
            //         // If we reach a RET instruction, this block is done executing
            //         warps_states[warp_index] <= DONE;
            //     end else begin
            //         // TODO: Branch divergence. For now assume all next_pc converge
            //         warp_status[warp_index] <= READY;
            //         warp_pcs[warp_index] <= next_pc[0];
            //         // Update is synchronous so we move on after one cycle
            //         warps_states[warp_index] <= FETCH;
            //     end
            // end
            case (core_state)
                IDLE: begin
                    // Here after reset (before kernel is launched, or after previous block has been processed)
                    if (start) begin 
                        // Start by fetching the next instruction for this block based on PC
                        core_state <= FETCH;
                    end
                end
                FETCH: begin 
                    // Move on once fetcher_state = FETCHED
                    // if (fetcher_state == 3'b010) begin 
                    //     if (warp_status[next_warp] == READY)begin
                    //         warp <= next_warp;
                    //         current_pc <=warp_pcs[next_warp];
                    //         core_state <= warps_states[next_warp];
                    //         warp_status[next_warp] <= STALL;
                    //         next_warp <= next_warp+1;
                    //     end
                    //     // for (int i = 1; i < WARPS_PER_CORE; i++)begin
                    //     //     else begin if (warp_status[next_warp + i] == READY)begin
                    //     //         warp <= (next_warp + i);
                    //     //         current_pc <=warp_pcs[next_warp + i];
                    //     //         core_state <= warps_states[next_warp + i];
                    //     //         warp_status[next_warp + i] <= STALL;
                    //     //         next_warp <= (next_warp+1);
                    //     //     end
                    //     // end 
                    // end
                    if (fetcher_state == 3'b010) begin 
                        core_state <= DECODE;
                    end
                end
                DECODE: begin
                    // Decode is synchronous so we move on after one cycle
                    core_state <= REQUEST;
                end
                REQUEST: begin 
                    // Request is synchronous so we move on after one cycle
                    core_state <= WAIT;
                end
                WAIT: begin
                    // Wait for all LSUs to finish their request before continuing
                    reg any_lsu_waiting = 1'b0;
                    for (int i = 0; i < THREADS_PER_BLOCK; i++) begin
                        // Make sure no lsu_state = REQUESTING or WAITING
                        if (lsu_state[i] == 2'b01 || lsu_state[i] == 2'b10) begin
                            any_lsu_waiting = 1'b1;
                            break;
                        end
                    end

                    // If no LSU is waiting for a response, move onto the next stage
                    if (!any_lsu_waiting) begin
                        core_state <= EXECUTE;
                    end
                end
                EXECUTE: begin
                    // Execute is synchronous so we move on after one cycle
                    core_state <= UPDATE;
                end
                UPDATE: begin 
                    if (decoded_ret) begin 
                        // If we reach a RET instruction, this block is done executing
                        warps_states[warp_index] <= DONE;
                    end else begin
                        // TODO: Branch divergence. For now assume all next_pc converge
                        if (warp_status[next_warp] == READY)begin
                            warp <= next_warp;
                            current_pc <=warp_pcs[next_warp];
                            core_state <= warps_states[next_warp];
                            warp_status[next_warp] <= STALL;
                            next_warp <= next_warp+1;
                        end
                        warp_status[warp_index] <= READY;
                        warp_pcs[warp_index] <= next_pc[0];
                        // Update is synchronous so we move on after one cycle
                        warps_states[warp_index] <= FETCH;
                    end
                end
                DONE: begin 
                    // no-op
                end
            endcase
        end
    end
endmodule
