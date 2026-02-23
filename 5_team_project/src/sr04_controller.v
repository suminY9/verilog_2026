`timescale 1ns / 1ps

module top_sr04 (
    input clk,
    input rst,
    input start,
    input echo,
    output trigger,
    output [23:0] distance
);
    wire w_tick_1mhz;

    sr04_controller U_SR04_CONTROLLER (
        .clk(clk),
        .rst(rst),
        .i_tick(w_tick_1mhz),  // 1us
        .start(start),
        .echo(echo),
        .trigger(trigger),
        .distance(distance)
    );

    tick_gen U_TICK_GEN_1US (
        .clk(clk),  // 100Mhz
        .rst(rst),
        .o_tick(w_tick_1mhz)  // 1us (1Mhz)
    );
endmodule

module sr04_controller (
    input clk,
    input rst,
    input i_tick,  // 1us
    input start,  // tick
    input echo,
    output trigger,
    output [23:0] distance
);

    localparam IDLE = 3'd0, WAIT_TICK = 3'd1, RUN = 3'd2, WAIT_ECHO = 3'd3, CAL_ECHO=3'd4;
    reg [2:0] c_state, n_state;
    reg trigger_reg, trigger_next;
    reg [23:0] distance_reg, distance_next;
    reg [13:0] counter_reg, counter_next;

    assign trigger  = trigger_reg;
    assign distance = distance_reg;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            c_state <= IDLE;
            trigger_reg <= 1'b0;
            distance_reg <= 0;
            counter_reg <= 0;
        end else begin
            c_state <= n_state;
            trigger_reg <= trigger_next;
            distance_reg <= distance_next;
            counter_reg <= counter_next;
        end
    end

    always @(*) begin
        n_state = c_state;
        trigger_next = trigger_reg;
        distance_next = distance_reg;
        counter_next = counter_reg;
        case (c_state)
            IDLE: begin
                trigger_next = 1'b0;
                counter_next = 0;
                if (start) begin
                    n_state = WAIT_TICK;
                end
            end
            WAIT_TICK: begin
                if (i_tick) begin
                    n_state = RUN;
                    trigger_next = 1'b1;
                end
            end
            RUN: begin
                if (i_tick) begin
                    counter_next = counter_reg + 1;
                    // margin 1us
                    if (counter_reg == 11) begin
                        n_state = WAIT_ECHO;
                        trigger_next = 1'b0;
                        counter_next = 0;
                    end
                end
            end
            WAIT_ECHO: begin
                if (i_tick) begin
                    if (echo) begin
                        n_state = CAL_ECHO;
                    end
                end
            end
            CAL_ECHO: begin
                if (echo) begin
                    if (i_tick) counter_next = counter_reg + 1;
                end else begin
                    distance_next = counter_reg / 58;  // cm
                    counter_next = 0;
                    n_state = IDLE;
                end
            end
        endcase
    end
endmodule


module tick_gen (
    input      clk,    // 100Mhz
    input      rst,
    output reg o_tick  // 1us (1Mhz)
);
    reg [$clog2(100)-1:0] counter_r;
    always @(posedge clk, posedge rst) begin
        if (rst) begin
            counter_r <= 0;
            o_tick <= 0;
        end else begin
            counter_r <= counter_r + 1;
            if (counter_r == 99) begin
                counter_r <= 0;
                o_tick <= 1;
            end else o_tick <= 0;
        end
    end
endmodule
