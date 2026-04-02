`timescale 1ns / 1ps

module tb_stopwatch_datapath;


    reg clk;
    reg reset;
    reg mode;
    reg clear;
    reg run_stop;
    reg sw_1;
    reg sel_display;
    reg digit_l;
    reg digit_r;
    reg time_up;
    reg time_down;
    wire [6:0] msec;
    wire [5:0] sec;
    wire [5:0] min;
    wire [4:0] hour;
    wire time_out;

    stopwatch_datapath dut (
        .reset(reset),
        .clk(clk),
        .mode(mode),
        .clear(clear),
        .run_stop(run_stop),
        .sw_1(sw_1),
        .sel_display(sel_display),  // sw[2] 1: hour_min, 0: s_ms
        .digit_l(digit_l),
        .digit_r(digit_r),
        .time_up(time_up),
        .time_down(time_down),
        .msec(msec),
        .sec(sec),
        .min(min),
        .hour(hour),
        .time_out(time_out)
    );


    always #5 clk = ~clk;

    integer i;
    initial begin


        #0;
        clk = 0;
        reset = 1;
        mode = 0;
        clear = 0;
        run_stop = 1;
        i = 0;

        #5;
        reset = 0;
        #5;


        // 30ms
        for (i = 0; i < 10; i = i + 1) begin
            #1000_000;
            #1000_000;
            #1000_000;
        end

        mode = 1;

        for (i = 0; i < 10; i = i + 1) begin
            #1000_000;
            #1000_000;
            #1000_000;
            #1000_000;
            #1000_000;
        end


        mode = 0;

        for (i = 0; i < 10; i = i + 1) begin
            #1000_000;
            #1000_000;
            #1000_000;
            #1000_000;
            #1000_000;
        end

        $stop;
    end


endmodule
