`timescale 1ns / 1ps

module tb_SR04();

    reg clk, reset, btn_r, echo;
    wire trigger;
    wire [3:0] fnd_digit;
    wire [7:0] fnd_data;

    top_SR04 dut (
        .clk(clk),
        .reset(reset),
        .btn_r(btn_r),
        .echo(echo),
        .trigger(trigger),
        .fnd_digit(fnd_digit),
        .fnd_data(fnd_data)
    );

    always #5 clk = ~clk;

    initial begin
        #0;
        clk = 0;
        reset = 1;
        btn_r = 0;
        echo = 0;

        #10;
        reset = 0;
        #5_000_000;

        #10_000_000;
        btn_r = 1;
        #10_000_000;
        btn_r = 0;
        #10_000_000;

        #200_000_000;
        echo = 1;
        #1500_000_000;
        
        echo = 0;
        #100_000_000;

        $stop;

    end

endmodule
