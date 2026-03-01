`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: suminY9
// Create Date: 2026/03/01 13:59:54
// Design Name: top module
// Module Name: top
// Project Name: sv_verification
// Target Devices: Basys3
// Tool Versions: Vivado 2020.2
// Revision:
// Revision 0.01 - File Created
//////////////////////////////////////////////////////////////////////////////////


module top (
    input        clk,
    input        rst,
    input  [3:0] sw,
    input        btn_u,
    input        btn_d,
    input        btn_r,
    input        btn_l,
    input        uart_rx,
    output       uart_tx,
    output [3:0] fnd_digit,
    output [7:0] fnd_data,
    output [3:0] LED
);

    // uart to stopwatch_watch
    wire [3:0] w_control;
    wire w_btn_u, w_btn_d, w_btn_r, w_btn_l, w_send;
    wire [3:0] w_sw;
    // stopwatch_watch to uart
    wire [31:0] w_sender_data;

/******************* uart *******************/
    top_uart U_TOP_UART(
        .clk(clk),
        .rst(rst),
        .i_sw(sw),
        .i_btn_u(btn_u),
        .i_btn_d(btn_d),
        .i_btn_r(btn_r),
        .i_btn_l(btn_l),
        .o_btn_u(w_btn_u),
        .o_btn_d(w_btn_d),
        .o_btn_r(w_btn_r),
        .o_btn_l(w_btn_l),
        .o_sw(w_sw),
        .send(w_send),
        .sender_data(w_sender_data),
        .uart_rx(uart_rx),
        .uart_tx(uart_tx)
    );

/************** stopwatch/watch **************/
    top_stopwatch_watch U_TOP_STOPWATCH_WATCH (
        .clk(clk),
        .reset(rst),
        .sw(w_sw),
        .btn_u(w_btn_u),
        .btn_d(w_btn_d),
        .btn_r(w_btn_r),
        .btn_l(w_btn_l),
        .send(w_send),
        .fnd_digit(fnd_digit),
        .fnd_data(fnd_data),
        .sender_data(w_sender_data),
        .LED(LED)
    );

endmodule
