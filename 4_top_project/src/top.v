`timescale 1ns / 1ps

module top (
    input        clk,
    input        rst,
    input  [5:0] sw,
    input        btn_u,
    input        btn_d,
    input        btn_r,
    input        btn_l,
    input        uart_rx,
    inout        dht11_io,
    output       uart_tx,
    output       echo,
    output       trigger,
    output [3:0] fnd_digit,
    output [7:0] fnd_data,
    output [3:0] LED
);

    // tick for sensor
    wire w_tick_1MHz;
    // button
    wire o_btn_up, o_btn_down, o_btn_right, o_btn_left;
    // to top_stopwatch_watch
    wire [3:0] w_ASCII;
    wire w_btn_in_u, w_btn_in_d, w_btn_in_r, w_btn_in_l, w_btn_in_send;
    wire [5:0] w_sw;
    // MUX, fnd in data
    wire [31:0] w_data_watch, w_data_SR04;
    wire [15:0] w_data_humidity, w_data_temperature; 
    wire [31:0] w_data_fnd_in;
    // uart
    wire w_uart_rx, w_uart_tx;


    // button debounce
    btn_debounce U_BD_UP (
        .clk  (clk),
        .reset(rst),
        .i_btn(btn_u),
        .o_btn(o_btn_up)
    );
    btn_debounce U_BD_DOWN (
        .clk  (clk),
        .reset(rst),
        .i_btn(btn_d),
        .o_btn(o_btn_down)
    );
    btn_debounce U_BD_RIGHT (
        .clk  (clk),
        .reset(rst),
        .i_btn(btn_r),
        .o_btn(o_btn_right)
    );
    btn_debounce U_BD_LEFT (
        .clk  (clk),
        .reset(rst),
        .i_btn(btn_l),
        .o_btn(o_btn_left)
    );

    // tick 1MHz
    tick_gen_1MHz U_TICK_1MHz (
        .clk(clk),
        .reset(rst),
        .tick_us(w_tick_1MHz)
    );

    /* uart */
    uart_top U_TOP_UART (
        .clk(clk),
        .rst(rst),
        .fnd_in_data(w_data_fnd_in),
        .sw(sw),
        .btn_u(o_btn_up),
        .btn_d(o_btn_down),
        .btn_r(o_btn_right),
        .btn_l(o_btn_left),
        .uart_rx(uart_rx),
        .uart_tx(uart_tx),
        .sw_in(w_sw),
        .btn_in_u(w_btn_in_u),
        .btn_in_d(w_btn_in_d),
        .btn_in_r(w_btn_in_r),
        .btn_in_l(w_btn_in_l)
    );

    /* stopwatch_watch */
    top_stopwatch_watch U_TOP_STOPWATCH_WATCH (
        .clk(clk),
        .reset(rst),
        .sw(w_sw),
        .btn_u(w_btn_in_u),
        .btn_d(w_btn_in_d),
        .btn_r(w_btn_in_r),
        .btn_l(w_btn_in_l),
        .out_data(w_data_watch[23:0]),
        .LED(LED)
    );

    /* SR04 */
    SR04_controller U_SR04 (
        .clk(clk),
        .reset(rst),
        .tick_1MHz(w_tick_1MHz),
        .SR04_sw(w_sw[1]),
        .start(w_btn_in_r),
        .echo(echo),
        .trigger(trigger),
        .distance(w_data_SR04[11:0])
    );

    /* DHT11 */
    dht11_controller U_DHT11 (
        .clk(clk),
        .rst(rst),
        .DHT11_sw(w_sw[2]),
        .start(w_btn_in_r),
        .humidity(w_data_humidity),
        .temperature(w_data_temperature),
        .dht11_done(w_dht11_done),
        .dht11_valid(w_dht11_valid),
        .debug(),
        .dhtio(dht11_io)
    );

    // fnd_controller
    MUX_3X1 #(
        .BIT_WIDTH(32)
    ) U_MUX_3X1_FND (
        .sel({sw[2], sw[1]}),
        .i_sel_watch({8'b0, w_data_watch}),
        .i_sel_sr({20'b0, w_data_SR04}),
        .i_sel_dht({w_data_humidity, w_data_temperature}),
        .o_mux(w_data_fnd_in)
    );

    fnd_controller U_FND_CTRL (
        .clk(clk),
        .reset(rst),
        .sel_SR04(sw[1]),
        .sel_DHT11(sw[2]),
        .sel_display(sw[4]),
        .fnd_in_data(w_data_fnd_in),
        .fnd_digit(fnd_digit),
        .fnd_data(fnd_data)
    );

endmodule
