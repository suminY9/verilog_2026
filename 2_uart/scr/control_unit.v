`timescale 1ns / 1ps

module control_unit (
    input clk,
    input reset,
    //button
    input i_up,
    input i_down,
    input i_right,         //run_stop: 0=stop, 1=run
    input i_left,          //clear: 0=non-clear, 1=clear
    //switch
    //input i_count_mode,    // sw[0]: 0=up_count, 1=down_count
    input i_watch_select,  // sw[1]: 0=watch,    1=stopwatch
                           // sw[2]: 0=hour_min, 1=sec_msec
    input i_edit,          // sw[3]: 0=not_edit, 1=edit

    //output           o_count_mode,
    output reg       o_run_stop,
    output reg       o_clear,
    output reg [1:0] o_edit_msec,
    output reg [1:0] o_edit_sec,
    output reg [1:0] o_edit_min,
    output reg [1:0] o_edit_hour,
    output reg [3:0] LED
);

    //assign o_count_mode = i_count_mode;

    // stopwatch parameter
    localparam STOP = 2'b00, RUN = 2'b01, CLEAR = 2'b10;
    // watch parameter
    localparam MSEC = 2'b00, SEC = 2'b01, MIN = 2'b10, HOUR = 2'b11;

    reg [1:0] current_stopwatch, next_stopwatch;
    reg [1:0] current_watch_edit, next_watch_edit;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            current_stopwatch  <= STOP;
            current_watch_edit <= MSEC;
        end else begin
            current_stopwatch  <= next_stopwatch;
            current_watch_edit <= next_watch_edit;
        end
    end

    // stopwatch, edit mode off
    always @(*) begin
        // stopwatch, edit mode don't care
        if (i_watch_select == 1) begin
            //initialize
            next_stopwatch = current_stopwatch;
            o_run_stop     = 1'b0;
            o_clear        = 1'b0;
            o_edit_msec    = 2'b00;
            o_edit_sec     = 2'b00;
            o_edit_min     = 2'b00;
            o_edit_hour    = 2'b00;
            LED = 4'b0000;

            case (current_stopwatch)
                STOP: begin
                    o_run_stop = 1'b0;
                    o_clear = 1'b0;
                    if (i_right) next_stopwatch = RUN;
                    else if (i_left) next_stopwatch = CLEAR;
                end
                RUN: begin
                    o_run_stop = 1'b1;
                    o_clear = 1'b0;
                    if (i_right) next_stopwatch = STOP;
                end
                CLEAR: begin
                    o_run_stop     = 1'b0;
                    o_clear        = 1'b1;
                    next_stopwatch = STOP;
                end
            endcase
        end else
        // watch, edit mode on
        if ((i_edit == 1) & (i_watch_select == 0)) begin
            next_watch_edit = current_watch_edit;
            o_run_stop      = 1'b0;
            o_clear         = 1'b0;
            o_edit_msec     = 2'b00;
            o_edit_sec      = 2'b00;
            o_edit_min      = 2'b00;
            o_edit_hour     = 2'b00;

            case (current_watch_edit)
                MSEC: begin
                    LED = 4'b0001;
                    if (i_up) o_edit_msec = 2'b01;
                    else if (i_down) o_edit_msec = 2'b11;
                    else if (i_right) next_watch_edit = HOUR;
                    else if (i_left) next_watch_edit = SEC;
                end
                SEC: begin
                    LED = 4'b0010;
                    if (i_up) o_edit_sec = 2'b01;
                    else if (i_down) o_edit_sec = 2'b11;
                    else if (i_right) next_watch_edit = MSEC;
                    else if (i_left) next_watch_edit = MIN;
                end
                MIN: begin
                    LED = 4'b0100;
                    if (i_up) o_edit_min = 2'b01;
                    else if (i_down) o_edit_min = 2'b11;
                    else if (i_right) next_watch_edit = SEC;
                    else if (i_left) next_watch_edit = HOUR;
                end
                HOUR: begin
                    LED = 4'b1000;
                    if (i_up) o_edit_hour = 2'b01;
                    else if (i_down) o_edit_hour = 2'b11;
                    else if (i_right) next_watch_edit = MIN;
                    else if (i_left) next_watch_edit = MSEC;
                end
            endcase
        end else
        // watch, edit mode off
        begin
            o_run_stop      = 1'b0;
            o_clear         = 1'b0;
            o_edit_msec     = 2'b00;
            o_edit_sec      = 2'b00;
            o_edit_min      = 2'b00;
            o_edit_hour     = 2'b00;
            LED             = 4'b0000;
        end
    end

endmodule
