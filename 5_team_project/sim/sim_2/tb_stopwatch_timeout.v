`timescale 1ns / 1ps

/*
* title   : <case 1: stopwatch down count time out>
* content : set stopwatch time at 00:00:01`00 by physical button
*/

/*
*         0/1
* sw[0] - up_count/down_count
* sw[1] - watch/stopwatch, SR04/dht11
* sw[2] - sec_msec/hour_min, humidity/temperature
* sw[3] - stopwatch_watch/sensor
* sw[4] - reset                   // acting only on board
* 
* <send to pc>
* uart input: 's'
* 
* <watch>
* { sw[3], sw[2], sw[1], sw[0] } = { 0 x 0 x }
* button - R(select right fnd)
*          L(select left fnd)
*          U(time +1)
*          D(time -1)
* 
* <stopwatch, up_count>
* { sw[3], sw[2], sw[1], sw[0] } = { 0 x 1 0 }
* button - R(run_stop - toggle)
*          C(clear)
* 
* <stopwatch, down_count>
* { sw[3], sw[2], sw[1], sw[0] } = { 0 x 1 1 }
* button - R(run_stop - toggle)
*          C(clear)
*          L(select left fnd)
*          U(time +1)
*          D(time -1)
* 
* <SR04>
* { sw[3], sw[2], sw[1], sw[0] } = { 1 x 0 x }
* button - R(start)
* 
* <DHT11>
* { sw[3], sw[2], sw[1], sw[0] } = { 1 x 1 x }
* button - R(start)
*/

module tb_stopwatch_timeout();

    reg clk, rst;
    reg [3:0] sw;
    reg btn_r, btn_c, btn_l, btn_u, btn_d;
    reg uart_rx, echo;
    wire uart_tx, trigger, dhtio;
    wire [3:0] fnd_digit;
    wire [7:0] fnd_data;
    wire dht11_valid;

    top_uart_wsw DUT (
        .clk(clk),
        .rst(rst),
        .sw(sw),
        .btn_r(btn_r),
        .btn_c(btn_c),
        .btn_l(btn_l),
        .btn_u(btn_u),
        .btn_d(btn_d),
        .uart_rx(uart_rx),
        .uart_tx(uart_tx),
        .echo(echo),
        .trigger(trigger),
        .dhtio(dhtio),
        .dht11_valid(dht11_valid),
        .fnd_digit(fnd_digit),
        .fnd_data(fnd_data)
    );

    always #5 clk = ~clk;

    initial begin
        // initializing
        #0;
        clk = 0;
        rst = 1;
        { btn_r, btn_l, btn_u, btn_d, btn_c } = 4'b00000;
        sw = 4'b0000;
        uart_rx = 0;
        echo = 0;

        // reset
        #29; rst = 0;


        // set stopwatch, down_count, time: 00:00:01`00
        sw = 4'b0011;
        #10_000; btn_l = 1; #100_000; btn_l = 0;

        #10_000; btn_u = 1; #100_000; btn_u = 0;
        #10_000; btn_u = 1; #100_000; btn_u = 0;
        #10_000; btn_u = 1; #100_000; btn_u = 0;
        #10_000; btn_u = 1; #100_000; btn_u = 0;
        #10_000; btn_u = 1; #100_000; btn_u = 0;
        #10_000; btn_u = 1; #100_000; btn_u = 0;
        #10_000; btn_u = 1; #100_000; btn_u = 0;
        #10_000; btn_u = 1; #100_000; btn_u = 0;
        #10_000; btn_u = 1; #100_000; btn_u = 0;
        #10_000; btn_u = 1; #100_000; btn_u = 0;


        // test start
        #10_000; btn_r = 1; #100_000; btn_r = 0;

        // wait 10sec
        #10_000_000_000;

        #10_000_000;
        $stop;
    end

endmodule
