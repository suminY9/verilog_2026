// simulation case 4

`timescale 1ns / 1ps

module tb_top_uart();

    reg clk, rst, rx;
    reg [3:0] sw;
    reg btn_u, btn_d, btn_r, btn_l;
    wire [3:0] fnd_digit;
    wire [7:0] fnd_data;
    wire [3:0] LED;
    integer i, j;
    reg [7:0] test_data;

    parameter BAUD = 9600;
    parameter BAUD_PERIOD = (100_000_000 / BAUD) * 10;  //104_160

    uart_top dut (
        .clk(clk),
        .rst(rst),
        .sw(sw),
        .btn_u(btn_u),
        .btn_d(btn_d),
        .btn_r(btn_r),
        .btn_l(btn_l),
        .uart_rx(rx),
        .uart_tx(uart_tx),
        .fnd_digit(fnd_digit),
        .fnd_data(fnd_data),
        .LED(LED)
    );

    always #5 clk = ~clk;

    task uart_sender(input [7:0] data);
        begin
            // uart test pattern
            // start
            rx = 0;  //stop
            #(BAUD_PERIOD);

            // data
            for (i = 0; i < 8; i = i + 1) begin
                rx = test_data[i];
                #(BAUD_PERIOD);
            end

            // stop
            rx = 1'b1;
            #(BAUD_PERIOD);
        end
    endtask

    initial begin
        #0;
        clk = 0;
        rst = 1;
        sw = 4'b0000;
        btn_u = 0;
        btn_d = 0;
        btn_r = 0;
        btn_l = 0;
        rx = 1;
        test_data = 8'b0111_0010;  // ascii 'r'

        #10000;
        rst = 0;

        //watch
        sw[0] = 0;
        sw[1] = 0;
        sw[2] = 1;
        sw[3] = 1;
        #10000;

        repeat (5) @(posedge clk);  // rising edge 5번 반복
        uart_sender(test_data);

        repeat (5) @(posedge clk);  // rising edge 5번 반복
        uart_sender(test_data);

        test_data = 8'b0111_0101;  // ascii 'u'
        repeat (5) @(posedge clk);  // rising edge 5번 반복
        uart_sender(test_data);

        repeat (5) @(posedge clk);  // rising edge 5번 반복

        #1000_000;
        $stop;

    end

endmodule

