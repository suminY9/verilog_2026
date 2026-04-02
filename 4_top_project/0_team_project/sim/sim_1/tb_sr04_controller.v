`timescale 1ns / 1ps

module tb_sr04_controller;

    reg clk, rst, start, echo;
    wire trigger;
    wire [23:0] distance;

    top_sr04 dut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .echo(echo),
        .trigger(trigger),
        .distance(distance)
    );

    // 100Mhz clk
    always #5 clk = ~clk;

    initial begin
        #0;
        clk   = 0;
        rst   = 1;
        start = 0;
        echo  = 0;

        @(negedge clk);
        rst = 0;

        #1_000_000;
        #1_000_000;
        @(negedge clk);
        @(negedge clk);
        start = 1;
        @(negedge clk);
        @(negedge clk);
        @(negedge clk);
        start = 0;

        repeat (15) #1_000_000;

        echo = 1;
        #1_000_000;
        #1_000_000;
        #1_000_000;
        echo = 0;

        repeat (5) @(negedge clk);


        #10;
        start = 1;
        #10;
        start = 0;

        repeat (10) #1_000_000;

        echo = 1;
        #100_000;  // 100us
        echo = 0;
        #100;


        $stop;

    end
endmodule
