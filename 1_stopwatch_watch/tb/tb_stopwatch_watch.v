`timescale 1ns / 1ps

module tb_stopwatch_watch ();

    reg        clk;
    reg        reset;
    reg  [2:0] sw;
    reg        btn_r;
    reg        btn_l;
    wire [3:0] fnd_digit;
    wire [7:0] fnd_data;

    top_stopwatch_watch dut (
        .clk(clk),
        .reset(reset),
        .sw(sw),
        .btn_r(btn_r),
        .btn_l(btn_l),
        .fnd_digit(fnd_digit),
        .fnd_data(fnd_data)
    );

    always #5 clk = ~clk;

/*
    sw[0]: mode: 0(up) 1(down)
    sw[1]: select: 0(watch) 1(stop watch)
    sw[2]: fnd select: 0(sec_msec) 1(hour_min)

    btn_r: run_stop: 0(stop) 1(run)
    btn_l: clear: 0(none) 1(clear)
*/

    initial begin
        #0;
        clk = 0;
        reset = 1;
        sw = 3'b000;
        btn_r = 1;
        btn_l = 0;

        #10;
        reset = 0;

        //watch, up
        #1000000;
        sw[0] = 0;
        sw[1] = 0;
        sw[2] = 0;
        #100000;
        sw[2] = 1;
        #100000;
        sw[2] = 0;
        #100000;
        sw[2] = 1;
        #100000;
        sw[2] = 0;        
        #100000;
        sw[2] = 1;
        #100000;
        sw[2] = 0;

        //watch, down
        #1000000;
        sw[0] = 1;
        sw[1] = 0;
        sw[2] = 0;
        #100000;
        sw[2] = 1;
        #100000;
        sw[2] = 0;
        #100000;
        sw[2] = 1;
        #100000;
        sw[2] = 0;
        #100000;
        sw[2] = 1;
        #100000;
        sw[2] = 0;

        //stopwatch, up, run -> stop -> run
        #1000000;
        sw[0] = 0;
        sw[1] = 1;
        sw[2] = 0;
        btn_l = 0;
        btn_r = 1;
        #10000000;
        btn_r = 0;
        #1000000;
        btn_r = 1;

        //stopwatch, down, run -> stop -> run
        #1000000;
        sw[0] = 1;
        sw[1] = 1;
        sw[2] = 0;
        btn_l = 0;
        btn_r = 1;
        #10000000;
        btn_r = 0;
        #1000000;
        btn_r = 1;

        //stopwatch, down, (stop, clear) -> (run , none)
        #1000000;
        sw[0] = 1;
        sw[1] = 1;
        sw[2] = 0;
        btn_l = 0;
        btn_r = 0;
        #1000000;
        btn_l = 1;
        #100000;
        btn_l = 0;
        btn_r = 1;
        
        #10000000;
        $stop;

    end


endmodule
