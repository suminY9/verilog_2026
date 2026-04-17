`timescale 1ns / 1ps

module board_top_spi_slave (
    // global input
    input logic clk,
    input logic reset,
    // spi protocol
    input logic sclk,
    input logic mosi,
    input logic cs_n,
    output logic miso,
    // fnd output
    output logic [7:0] fnd_data,
    output logic [3:0] fnd_digit
);

    // 2-stage Synchronizer signals
    logic sclk_reg1, sclk_sync;
    logic mosi_reg1, mosi_sync;
    logic cs_n_reg1, cs_n_sync;

    // 외부 입력을 슬레이브 보드의 시스템 클락에 동기화
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            {sclk_reg1, sclk_sync} <= 2'b00;
            {mosi_reg1, mosi_sync} <= 2'b00;
            {cs_n_reg1, cs_n_sync} <= 2'b11; // CS_N은 평소에 High
        end else begin
            sclk_reg1 <= sclk;      sclk_sync <= sclk_reg1;
            mosi_reg1 <= mosi;      mosi_sync <= mosi_reg1;
            cs_n_reg1 <= cs_n;      cs_n_sync <= cs_n_reg1;
        end
    end

    slave_FND U_SLAVE_FND (
        .clk(clk),
        .reset(reset),
        .sclk(sclk_sync),
        .mosi(mosi_sync),
        .miso(miso),
        .cs_n(cs_n_sync),
        .fnd_data(fnd_data),
        .fnd_digit(fnd_digit)
    );
endmodule
