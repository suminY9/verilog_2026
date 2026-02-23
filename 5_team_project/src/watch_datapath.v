`timescale 1ns / 1ps

module watch_datapath (
    input clk,
    input reset,
    input mode,
    input clear,
    input sw_1,
    input sel_display,  // sw[2] 1: hour_min, 0: s_ms
    input digit_l,
    input digit_r,
    input time_up,
    input time_down,
    output [6:0] msec,
    output [5:0] sec,
    output [5:0] min,
    output [4:0] hour
);
    wire w_tick_100hz, w_sec_tick, w_min_tick, w_hour_tick;
    wire [3:0] w_digit_sel;

    digit_sel U_DIGIT_SEL (
        .sel_display(sel_display),
        .digit_l(digit_l),
        .digit_r(digit_r),
        .digit_sel(w_digit_sel)
    );

    tick_counter_watch #(
        .BIT_WIDTH(5),
        .TIMES(24),
        .INIT_TIME(12)
    ) hour_counter (
        .clk(clk),
        .reset(reset),
        .i_tick(w_hour_tick),
        .mode(mode),
        .clear(clear),
        .sw_1(sw_1),
        .digit_sel(w_digit_sel[3]),
        .time_up(time_up),
        .time_down(time_down),
        .o_count(hour),
        .o_tick()
    );
    tick_counter_watch #(
        .BIT_WIDTH(6),
        .TIMES(60),
        .INIT_TIME(0)
    ) min_counter (
        .clk(clk),
        .reset(reset),
        .i_tick(w_min_tick),
        .mode(mode),
        .clear(clear),
        .sw_1(sw_1),
        .digit_sel(w_digit_sel[2]),
        .time_up(time_up),
        .time_down(time_down),
        .o_count(min),
        .o_tick(w_hour_tick)
    );
    tick_counter_watch #(
        .BIT_WIDTH(6),
        .TIMES(60),
        .INIT_TIME(0)
    ) sec_counter (
        .clk(clk),
        .reset(reset),
        .i_tick(w_sec_tick),
        .mode(mode),
        .clear(clear),
        .sw_1(sw_1),
        .digit_sel(w_digit_sel[1]),
        .time_up(time_up),
        .time_down(time_down),
        .o_count(sec),
        .o_tick(w_min_tick)
    );
    tick_counter_watch #(
        .BIT_WIDTH(7),
        .TIMES(100),
        .INIT_TIME(0)
    ) msec_counter (
        .clk(clk),
        .reset(reset),
        .i_tick(w_tick_100hz),
        .mode(mode),
        .clear(clear),
        .sw_1(sw_1),
        .digit_sel(w_digit_sel[0]),
        .time_up(time_up),
        .time_down(time_down),
        .o_count(msec),
        .o_tick(w_sec_tick)
    );

    tick_gen_100hz U_TICK_10HZ (
        .clk(clk),  // 100MHz
        .reset(reset),
        .i_run_stop(1),
        .o_tick_100hz(w_tick_100hz)  // 10Hz
    );
endmodule

module digit_sel (
    input sel_display,
    input digit_l,
    input digit_r,
    output reg [3:0] digit_sel
);
    reg digit_reg;
    always @(*) begin
        digit_sel = 4'b0001;
        // digit_reg = 1'b0;

        if (digit_l) digit_reg = 1'b1;
        else if (digit_r) digit_reg = 1'b0;
        else digit_reg = digit_reg;

        // case (sel_display)
        //     1'b0: begin
        //         if (digit_reg == 1'b0) digit_sel = 4'b0001;
        //         else digit_sel = 4'b0010;
        //     end
        //     1'b1: begin
        //         if (digit_reg == 1'b0) digit_sel = 4'b0100;
        //         else digit_sel = 4'b1000;
        //     end
        //     default: digit_sel = digit_sel;
        // endcase


        case ({
            sel_display, digit_reg
        })
            2'b00: digit_sel = 4'b0001;
            2'b01: digit_sel = 4'b0010;
            2'b10: digit_sel = 4'b0100;
            2'b11: digit_sel = 4'b1000;
        endcase
    end
endmodule

// msec, sec, min, hour
module tick_counter_watch #(
    parameter BIT_WIDTH = 7,
    TIMES = 100,
    INIT_TIME = 0
) (
    input                      clk,
    input                      reset,
    input                      i_tick,
    input                      mode,
    input                      clear,
    input                      sw_1,
    input                      digit_sel,
    input                      time_up,
    input                      time_down,
    output     [BIT_WIDTH-1:0] o_count,
    output reg                 o_tick
);
    // counter reg
    reg [BIT_WIDTH-1:0] counter_reg, counter_next;

    assign o_count = counter_reg;

    // State reg SL
    always @(posedge clk, posedge reset) begin
        if (reset || clear) begin
            counter_reg <= INIT_TIME;
        end else begin
            counter_reg <= counter_next;
        end
    end
    // next state + output CL
    always @(*) begin
        counter_next = counter_reg;
        o_tick = 1'b0;

        // sw_1 : 0 (watch)
        if (!sw_1 && digit_sel) begin
            if (time_up) begin
                if (counter_reg == TIMES - 1) counter_next = 1'b0;
                else counter_next = counter_reg + 1;
            end
            if (time_down) begin
                if (counter_reg == 0) counter_next = TIMES - 1;
                else counter_next = counter_reg - 1;
            end
        end

        if (i_tick) begin
            if (mode) begin
                // down
                if (counter_reg == 0) begin
                    counter_next = TIMES - 1;
                    o_tick = 1'b1;
                end else begin
                    counter_next = counter_reg - 1;
                    o_tick = 1'b0;
                end
            end else begin
                // up
                if (counter_reg == TIMES - 1) begin
                    counter_next = 1'b0;
                    o_tick = 1'b1;
                end else begin
                    counter_next = counter_reg + 1;
                    o_tick = 1'b0;
                end
            end
        end
    end
endmodule



