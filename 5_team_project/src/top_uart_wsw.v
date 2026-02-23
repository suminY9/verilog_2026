`timescale 1ns / 1ps

module top_uart_wsw (
    input        clk,
    input        rst,
    input  [3:0] sw,          // sw[0] up/down
    input        btn_r,       // i_run_stop or digit_right
    input        btn_c,       // i_clear
    input        btn_l,       // digit_left
    input        btn_u,       // time_up
    input        btn_d,       // time_down
    input        uart_rx,
    input        echo,
    output       trigger,
    output       uart_tx,
    output [3:0] fnd_digit,
    output [7:0] fnd_data,
    inout        dhtio,
    output       dht11_valid
    // output [3:0] dht11_debug

    // output       test_echo,
    // output       test_trigger
);
    // wire w_echo, w_trigger, debug_echo, debug_trigger;

    // // assign echo = w_echo;
    // assign test_echo = debug_echo;
    // assign trigger = w_trigger;
    // assign test_trigger = debug_trigger;


    wire [ 3:0] w_cmd_tick;
    wire [ 3:0] w_cmd_switch;
    wire [15:0] w_display_data;
    wire [15:0] w_watch_data;
    wire w_time_out;

    

    top_uart U_UART (
        .clk         (clk),
        .rst         (rst),
        .uart_rx     (uart_rx),
        .display_data(w_display_data),
        .watch_data(w_watch_data),
        .time_out    (w_time_out),
        .sw_3_1      ({w_cmd_switch[3] | sw[3], (w_cmd_switch[1] | sw[1])}),
        .uart_tx     (uart_tx),
        .cmd_tick    (w_cmd_tick),
        .cmd_switch  (w_cmd_switch)
    );

    top_stopwatch_watch U_STOPWATCH_WATCH (
        .clk         (clk),
        .reset       (rst),
        .sw          (sw),              // sw[0] up/down
        .btn_r       (btn_r),           // i_run_stop or digit_right
        .btn_c       (btn_c),           // i_clear
        .btn_l       (btn_l),           // digit_left
        .btn_u       (btn_u),           // time_up
        .btn_d       (btn_d),           // time_down
        .cmd_tick    (w_cmd_tick),
        .cmd_switch  (w_cmd_switch),
        .echo        (echo),
        .fnd_digit   (fnd_digit),
        .fnd_data    (fnd_data),
        .display_data(w_display_data),
        .watch_data(w_watch_data),
        .trigger     (trigger),
        .dhtio       (dhtio),
        .dht11_valid (dht11_valid),
        .dht11_debug (),
        .time_out    (w_time_out)
        // .dht11_debug (dht11_debug)
        // .trigger     (w_trigger)
    );

    // debug_echo_trigger U_DEBUG_E_T (
    //     .clk(clk),
    //     .rst(rst),
    //     .i_echo(echo),
    //     .i_trigger(w_trigger),
    //     .o_echo(debug_echo),
    //     .o_trigger(debug_trigger)
    // );

endmodule


module debug_echo_trigger (
    input clk,
    input rst,
    input i_echo,
    input i_trigger,
    output reg o_echo,
    output reg o_trigger
);

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            o_echo <= 0;
            o_trigger <= 0;
        end else begin
            if (i_echo) o_echo <= 1'b1;
            if (i_trigger) o_trigger <= 1'b1;
        end
    end
endmodule
