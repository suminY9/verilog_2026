`timescale 1ns / 1ps

module tb_dht11 ();

    reg clk, rst, start;
    reg dht11_sensor_io, sensor_io_sel;
    wire dhtio;

    assign dgtio = (sensor_io_sel) ? 1'bz : dht11_sensor_io;

    dht11_controller(
        .clk(clk),
        .rst(rst),
        .start(start),
        .humidity(),
        .tmperature(),
        .dht11_done(),
        .dht11_valid(),
        .debug(),
        .dhtio(dhtio)  //inout은 wire type
    );

    always #5 clk = ~clk;

    initial begin
        #0;
        clk             = 0;
        rst             = 1;
        start           = 0;
        dht11_sensor_io = 1'b0;
        sensor_io_sel   = 1'b1;     // 출력 나와야 하니까 연결을 끊어 놓음

        //reset
        #20;
        rst = 0;
        #20;
        start = 1;
        #10;
        start = 0;

        // 19msec + 30usec
        #(1900 * 10 * 1000 + 30_000);
        sensor_io_sel = 0;
        #1000;
        $stop;
    end

endmodule
