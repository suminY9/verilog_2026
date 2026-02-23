`timescale 1ns / 1ps

module control_unit(
    input clk,
    input reset,
    input i_mode,      //sw[0]: 0=up_count & edit, 1=down_count
    input i_stopwatch, //sw[1]: 0=watch, 1=stopwatch
    input i_right,     //run_stop: 0=stop, 1=run
    input i_left,      //clear: 0=non-clear, 1=clear
    //input i_run_stop,
    //input i_clear,
    output o_mode,
    output reg o_stopwatch,
    output reg o_run_stop,
    output reg o_clear
    );

    localparam STOP = 2'b00, RUN = 2'b01, CLEAR = 2'b10, EDIT_WATCH = 2'b11;

    // reg variable
    reg [1:0] current_st, next_st;

    assign o_mode = i_mode;

    // state register SL
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            current_st <= STOP;
        end else begin
            current_st <= next_st;
        end
    end

    // next CL
    always @(*) begin
        // initialize
        next_st = current_st;
        o_run_stop = 1'b0;
        o_clear = 1'b0;

        case(current_st)
            STOP: begin
                o_run_stop = 1'b0;
                o_clear = 1'b0;
                if(i_right & i_stopwatch) begin
                    o_stopwatch = 1'b1;
                    next_st = RUN;
                end else if(i_left & i_stopwatch) begin
                    o_stopwatch = 1'b1;
                    next_st = CLEAR;
                end else if(i_stopwatch == 0) begin
                    o_stopwatch = 1'b0;
                    next_st = EDIT_WATCH;
                end
            end
            RUN: begin
                o_run_stop = 1'b1;
                o_clear = 1'b0;
                o_stopwatch = 1'b1;
               if(i_right) begin
                    next_st = STOP;
               end else if(i_stopwatch == 0) begin
                    o_stopwatch = 1'b0;
                    next_st = EDIT_WATCH;
               end
            end
            CLEAR: begin
                o_run_stop = 1'b0;
                o_clear = 1'b1;
                o_stopwatch = 1'b1;
                next_st = STOP;
            end
            EDIT_WATCH: begin
                o_run_stop = 1'b0;
                o_clear = 1'b0;
                o_stopwatch = 1'b0;
                if(i_stopwatch) begin
                    next_st = STOP;
                end
            end
        endcase
    end

endmodule
