`timescale 1ns / 1ps

module tb_top_uart_wsw_sr04;

    parameter BAUD = 9600;
    parameter BAUD_PERIOD = (100_000_000 / BAUD) * 10;

    reg        clk;
    reg        rst;
    reg  [3:0] sw;  // sw[0] up/down
    reg        btn_r;  // i_run_stop or digit_right
    reg        btn_c;  // i_clear
    reg        btn_l;  // digit_left
    reg        btn_u;  // time_up
    reg        btn_d;  // time_down
    reg        uart_rx;
    reg        echo;
    wire       trigger;
    wire       uart_tx;
    wire [3:0] fnd_digit;
    wire [7:0] fnd_data;

    top_uart_wsw dut (
        .clk      (clk),
        .rst      (rst),
        .sw       (sw),         // sw[0] up/down
        .btn_r    (btn_r),      // i_run_stop or digit_right
        .btn_c    (btn_c),      // i_clear
        .btn_l    (btn_l),      // digit_left
        .btn_u    (btn_u),      // time_up
        .btn_d    (btn_d),      // time_down
        .uart_rx  (uart_rx),
        .echo     (echo),
        .trigger  (trigger),
        .uart_tx  (uart_tx),
        .fnd_digit(fnd_digit),
        .fnd_data (fnd_data)
    );

    always #5 clk = ~clk;

    reg [7:0] test_data;
    integer i, j;

    task uart_sender();
        begin
            //uart test pattern
            //start
            uart_rx = 1'b0;
            #(BAUD_PERIOD);

            //data
            for (i = 0; i < 8; i = i + 1) begin
                uart_rx = test_data[i];
                #(BAUD_PERIOD);
            end
            //stop
            uart_rx = 1'b1;
            #(BAUD_PERIOD);
        end
    endtask


    initial begin
        #0;
        clk = 0;
        rst = 1;
        sw = 0;
        btn_r = 0;
        btn_c = 0;
        btn_l = 0;
        btn_u = 0;
        btn_d = 0;
        // uart_rx = 1;
        echo = 0;

        uart_rx = 1'b1;
        repeat (5) @(posedge clk);
        rst = 1'b0;
        #(BAUD_PERIOD);

        // #5;
        // rst = 0;



        #10_000_000;
        // ascii s  state (current time)
        test_data = 8'h73;
        uart_sender();

        // uart_tx_out
        for (j = 0; j < 60; j = j + 1) begin
            #(BAUD_PERIOD);
        end



        #1_000_000;
        #1_000_000;
        @(negedge clk);
        @(negedge clk);
        sw[3] = 1;
        @(negedge clk);
        @(negedge clk);
        @(negedge clk);
        // sw[3] = 0;

        repeat (15) #1_000_000;

        // echo = 1;
        // #1_000_000;
        // #1_000_000;
        // #1_000_000;
        // echo = 0;

        repeat (5) @(negedge clk);


        // #10;
        // sw[3] = 1;
        // #10;
        // sw[3] = 0;


        #10_000_000;
        // ascii r
        test_data = 8'h72;
        uart_sender();

        // uart_tx_out
        for (j = 0; j < 60; j = j + 1) begin
            #(BAUD_PERIOD);
        end

        repeat (11) #1_000_000;

        // echo = 1;
        // #100_000;  // 100us
        // echo = 0;
        // #100;

        echo = 1;
        #1_000_000;
        #1_000_000;
        #1_000_000;
        echo = 0;



        $stop;
    end

endmodule
