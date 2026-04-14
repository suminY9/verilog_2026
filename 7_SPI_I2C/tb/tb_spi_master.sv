`timescale 1ns / 1ps

module tb_spi_master ();
    logic       clk;
    logic       reset;
    logic [7:0] clk_div;
    logic [7:0] tx_data;
    logic       start;
    logic [7:0] rx_data;
    logic       done;
    logic       busy;
    logic       sclk;
    logic       mosi;
    logic       miso;
    logic       cs_n;

    always #5 clk = ~clk;

    assign miso = mosi;

    spi_master dut (
        .clk(clk),
        .reset(reset),
        .clk_div(clk_div),
        .tx_data(tx_data),
        .start(start),
        .rx_data(rx_data),
        .done(done),
        .busy(busy),
        .sclk(sclk),
        .mosi(mosi),
        .miso(miso),
        .cs_n(cs_n)
    );

    initial begin
        clk   = 0;
        reset = 1;
        repeat (3) @(posedge clk);
        reset = 0;
        @(posedge clk);

        clk_div = 4;    // 0~4
        // miso    = 1'b0;
        @(posedge clk);

        // send data
        tx_data = 8'haa;
        start   = 1'b1;
        @(posedge clk);
        start   = 1'b0;
        @(posedge clk);
        wait(done);
        @(posedge clk);

        #20;
        $finish;
    end
endmodule
