`timescale 1ns / 1ps

module tb_uart_loop_back;

    parameter BAUD = 9600;
    parameter BAUD_PERIOD = (100_000_000 / BAUD) * 10;  // 104_160_000

    reg clk, rst, rx;
    wire tx;
    reg [7:0] test_data;

    integer i, j;

    top_uart dut (
        .clk(clk),
        .rst(rst),
        .uart_rx(rx),
        .uart_tx(tx)
    );

    always #5 clk = ~clk;

    task uart_sender();
        begin
            // uart test pattern
            // start
            rx = 0;
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
        clk = 1'b0;
        rst = 1'b1;
        rx = 1'b1;
        test_data = 8'h31;  // ascii '0'

        repeat (5) @(posedge clk);
        rst = 1'b0;

        // for (j = 0; j < 10; j = j + 1) begin
        //     test_data = 8'h30 + j;
        //     uart_sender();
        // end
        repeat (5) @(posedge clk);
        uart_sender();
        
        // hold uart tx output
        for (j = 0; j < 12; j = j + 1) begin
            #(BAUD_PERIOD);
        end
        $stop;
    end
endmodule
