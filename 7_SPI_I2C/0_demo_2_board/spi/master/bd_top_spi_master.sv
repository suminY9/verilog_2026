`timescale 1ns / 1ps

module board_top_spi_master (
    // master input
    input logic clk,
    input logic reset,
    input logic cpol,            // sw[15]
    input logic cpha,            // sw[14]
    input logic [7:0] tx_data,   // sw[7:0]
    input logic start,           // btn r
    // spi protocol
    input logic miso,
    output logic sclk,
    output logic mosi,
    output logic cs_n,
    // led output
    output logic [7:0] led       // led[7:0]
);

    // button
    logic btn_start;
    // spi protocol
    logic m_done, m_busy;
    logic [7:0] rx_data;

    assign led = rx_data;

    btn_debounce U_BTN_DEB(
        .clk(clk),
        .reset(reset),
        .i_btn(start),
        .o_btn(btn_start)
    );
    spi_master U_SPI_MASTER (
        .clk(clk),
        .reset(reset),
        .cpol(cpol),
        .cpha(cpha),
        .clk_div(8'd4),
        .tx_data(tx_data),
        .start(btn_start),
        .rx_data(rx_data),
        .done(m_done),
        .busy(m_busy),
        .sclk(sclk),
        .mosi(mosi),
        .miso(miso),
        .cs_n(cs_n)
    );
endmodule
