`timescale 1ns / 1ps

module control_unit (
    input      clk,
    input      reset,
    input      i_mode,
    input      i_run_stop,
    input      i_clear,
    input      i_sw1,
    input      i_sw2,
    input      i_sw3,
    input      i_btn1,
    input      i_btn2,
    input      i_btn3,
    output     o_sw1,
    output     o_sw2,
    output     o_sw3,
    output     o_btn0,
    output     o_btn1,
    output     o_btn2,
    output     o_btn3,
    output     o_mode,
    output reg o_run_stop,
    output reg o_clear
);
    localparam STOP = 2'b00, RUN = 2'b01, CLEAR = 2'b10;
    // state variable
    reg [1:0] current_st, next_st;

    assign o_mode = i_mode;

    assign o_sw1  = i_sw1;
    assign o_sw2  = i_sw2;
    assign o_sw3  = i_sw3;
    assign o_btn0 = i_run_stop; // btn0
    assign o_btn1 = i_btn1;
    assign o_btn2 = i_btn2;
    assign o_btn3 = i_btn3;

    // state register SL
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            current_st <= STOP;
        end else begin
            current_st <= next_st;
        end
    end

    // next state CL + output CL
    always @(*) begin
        next_st = current_st;
        o_run_stop = 1'b0;
        o_clear = 1'b0;
        case (current_st)
            STOP: begin
                o_run_stop = 1'b0;
                o_clear = 1'b0;
                if (i_run_stop) begin
                    next_st = RUN;
                end else if (i_clear) begin
                    next_st = CLEAR;
                end
            end
            RUN: begin
                o_run_stop = 1'b1;
                o_clear = 1'b0;
                if (i_run_stop) begin
                    next_st = STOP;
                end
            end
            CLEAR: begin
                o_run_stop = 1'b0;
                o_clear = 1'b1;
                next_st = STOP;
            end
            default: begin
                next_st = current_st;
                o_run_stop = 1'b0;
                o_clear = 1'b0;
            end
        endcase
    end
endmodule
