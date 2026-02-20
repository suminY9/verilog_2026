`timescale 1ns / 1ps

module top_SR04 (
    input        clk,
    input        reset,
    input        btn_r,
    input        echo,
    output       trigger,
    output [3:0] fnd_digit,
    output [7:0] fnd_data
);

    // tick generator
    wire w_tick_1MHz;
    // button debouce
    wire w_btn_start;
    // distance (from SR04 controller to fnd_controller)
    wire [11:0] w_distance;

    btn_debounce U_BD_RIGHT (
        .clk  (clk),
        .reset(reset),
        .i_btn(btn_r),
        .o_btn(w_btn_start)
    );

    SR04_controller U_SR04_CTRL (
        .clk(clk),
        .reset(reset),
        .tick_1MHz(w_tick_1MHz),
        .start(w_btn_start),
        .echo(echo),
        .trigger(trigger),
        .distance(w_distance)
    );

    tick_gen_1MHz U_TICK_GEN (
        .clk(clk),
        .reset(reset),
        .tick_us(w_tick_1MHz)
    );

    fnd_controller_SR04 U_FND_CNTL_SR04 (
        .clk(clk),
        .reset(reset),
        .fnd_in_data(w_distance),
        .fnd_digit(fnd_digit),
        .fnd_data(fnd_data)
    );

endmodule

module SR04_controller (
    input             clk,
    input             reset,
    input             tick_1MHz,
    input             start,
    input             echo,
    output reg        trigger,
    output reg [11:0] distance
);

    localparam [1:0] IDLE = 2'b00, TRIGGER = 2'b01, ECHO = 2'b10;

    // FSM variable
    reg [1:0] current_st, next_st;
    // managing output variable
    reg [11:0]distance_reg;
    reg trigger_reg;
    // trigger counter
    reg [3:0] trigger_cnt_next, trigger_cnt_reg;
    // echo counter
    reg [15:0] echo_cnt_next, echo_cnt_reg;
    // echo signal synchronizer
    reg echo_reg1, echo_reg2;
    // tick resigter for detect rising edge
    reg tick_reg;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            current_st      <= 0;
            tick_reg        <= 0;
            trigger_cnt_reg <= 0;
            echo_cnt_reg    <= 0;
            echo_reg1       <= 0;
            echo_reg2       <= 0;
            distance_reg    <= 11'b0;
            trigger_reg     <= 0;
        end else begin
            current_st <= next_st;
            tick_reg <= tick_1MHz;   //register 값 변경은 clk에 동기해서!
            trigger_cnt_reg <= trigger_cnt_next;
            echo_cnt_reg <= echo_cnt_next;
            distance_reg <= distance;
            trigger_reg <= trigger;
            // 2-stage synchronizer
            echo_reg1 <= echo;
            echo_reg2 <= echo_reg1;
        end
    end

    always @(*) begin
        next_st          = current_st;
        distance         = distance_reg;
        trigger_cnt_next = trigger_cnt_reg;
        echo_cnt_next    = echo_cnt_reg;
        trigger          = trigger_reg;

        case (current_st)
            IDLE: begin
                // initialize counter
                trigger_cnt_next = 0;
                echo_cnt_next    = 0;
                if (start == 1) begin
                    next_st = TRIGGER;
                end
            end
            TRIGGER: begin
                if (tick_1MHz == 1'b1 && tick_reg == 1'b0) begin // rising edge detect
                    if (trigger_cnt_reg < 11) begin
                        trigger = 1'b1;
                        trigger_cnt_next = trigger_cnt_next + 1;
                    end else begin
                        trigger = 1'b0;
                        next_st = ECHO;
                    end
                end
            end
            ECHO: begin
                if (tick_1MHz == 1'b1 && tick_reg == 1'b0) begin // rising edge detect
                    if (echo_reg2 == 1) begin
                        echo_cnt_next = echo_cnt_next + 1;
                    end else if (echo_cnt_reg > 0 && echo_reg2 == 0) begin
                        distance = (echo_cnt_reg * 25'd1130) >> 16;
                        next_st  = IDLE;
                    end
                end
            end
        endcase
    end

endmodule

module tick_gen_1MHz (
    input clk,
    input reset,
    output reg tick_us
);

    // 1usec = 10^-6 sec -> 1_000_000 Hz = 1MHz
    // 100Mhz / 100
    //parameter F_COUNT = 100_000_000 / 100;
    parameter F_COUNT = 100;

    reg [$clog2(F_COUNT)-1:0] r_counter;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            r_counter <= 0;
            tick_us   <= 1'b0;
        end else begin
            r_counter <= r_counter + 1;
            if (r_counter == (F_COUNT - 1)) begin
                r_counter <= 0;
                tick_us   <= 1'b1;
            end else begin
                tick_us <= 1'b0;
            end
        end
    end

endmodule