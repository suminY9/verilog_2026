`timescale 1ns / 1ps

module tb_top_spi ();
    logic       clk;
    logic       reset;
    logic       cpol;
    logic       cpha;
    logic [7:0] tx_data;
    logic       start;
    logic [3:0] fnd_digit;
    logic [7:0] fnd_data;
    logic [7:0] led;

    top_spi dut ( .* );

    always #5 clk = ~clk;

    task spi_set_mode(logic [1:0] mode);
        {cpol, cpha} = mode;
        @(posedge clk);
    endtask

    task spi_send_data(logic [7:0] data);
        tx_data = data; 
        start   = 1'b1;
        @(posedge clk);
        start   = 1'b0;
        @(posedge clk);
        #2000;
    endtask

    initial begin
        clk   = 0;
        reset = 1;
        repeat (3) @(posedge clk);
        reset = 0;
        @(posedge clk);

        spi_set_mode(0);
        spi_send_data(8'haa);
        spi_send_data(8'h11);
        spi_send_data(8'hff);

        @(posedge clk);
        #20;
        $finish;
    end
endmodule
