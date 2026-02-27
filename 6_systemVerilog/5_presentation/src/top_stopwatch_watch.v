`timescale 1ns / 1ps

module top_stopwatch_watch (
    input        clk,
    input        reset,
    input  [3:0] sw,
    input        btn_u,
    input        btn_d,
    input        btn_r,
    input        btn_l,
    output [3:0] fnd_digit,
    output [7:0] fnd_data,
    output [3:0] LED
);

    // stopwatch signal
    wire w_run_stop, w_clear;
    // watch signal
    wire [1:0] w_edit_msec, w_edit_sec, w_edit_min, w_edit_hour;
    // time bitstream
    wire [23:0] w_watch_time;
    wire [23:0] w_stopwatch_time;
    wire [23:0] w_mux_2x1_24bit_out;

    // control unit
    control_unit U_CTRL_UNIT (
        .clk(clk),
        .reset(reset),
        .i_up(btn_u),
        .i_down(btn_d),
        .i_right(btn_r),
        .i_left(btn_l),
        //.i_count_mode(sw[0]),
        .i_watch_select(sw[1]),
        .i_edit(sw[3]),
        //.o_count_mode(),
        .o_run_stop(w_run_stop),
        .o_clear(w_clear),
        .o_edit_msec(w_edit_msec),
        .o_edit_sec(w_edit_sec),
        .o_edit_min(w_edit_min),
        .o_edit_hour(w_edit_hour),
        .LED(LED)
    );

    // watch datapath
    watch_datapath U_WATCH_DATAPATH (
        .clk(clk),
        .reset(reset),
        .count_mode(sw[0]),
        .edit_msec(w_edit_msec),
        .edit_sec(w_edit_sec),
        .edit_min(w_edit_min),
        .edit_hour(w_edit_hour),
        .msec(w_watch_time[6:0]),
        .sec(w_watch_time[12:7]),
        .min(w_watch_time[18:13]),
        .hour(w_watch_time[23:19])
    );


    // stopwatch datapath
    stopwatch_datapath U_STOPWATCH_DATAPATH (
        .clk(clk),
        .reset(reset),
        .count_mode(sw[0]),
        .run_stop(w_run_stop),
        .clear(w_clear),
        .msec(w_stopwatch_time[6:0]),
        .sec(w_stopwatch_time[12:7]),
        .min(w_stopwatch_time[18:13]),
        .hour(w_stopwatch_time[23:19])
    );


    // 2x1 MUX: watch or stopwatch to fnd
    MUX_2x1_24bit U_MUX_WATCH_STOPWATCH (
        .sel(sw[1]),
        .i_sel0(w_watch_time),
        .i_sel1(w_stopwatch_time),
        .o_mux(w_mux_2x1_24bit_out)
    );


    // fnd controller
    fnd_controller U_FND_CNTL (
        .clk(clk),
        .reset(reset),
        .sel_display(sw[2]),
        .fnd_in_data(w_mux_2x1_24bit_out),
        .fnd_digit(fnd_digit),
        .fnd_data(fnd_data)
    );

endmodule


module watch_datapath (
    input        clk,
    input        reset,
    input        count_mode,
    input  [1:0] edit_msec,
    input  [1:0] edit_sec,
    input  [1:0] edit_min,
    input  [1:0] edit_hour,
    output [6:0] msec,
    output [5:0] sec,
    output [5:0] min,
    output [4:0] hour
);

    wire w_tick_100hz, w_sec_tick, w_min_tick, w_hour_tick;

    tick_counter #(
        .BIT_WIDTH(5),
        .TIMES(24),
        .INIT_CNT(12)
    ) hour_counter (
        .clk(clk),
        .reset(reset),
        .i_tick(w_hour_tick),
        .count_mode(count_mode),
        .run_stop(),
        .clear(1'b0),
        .edit_sign(edit_hour),
        .o_count(hour),
        .o_tick()
    );
    tick_counter #(
        .BIT_WIDTH(6),
        .TIMES(60),
        .INIT_CNT(0)
    ) min_counter (
        .clk(clk),
        .reset(reset),
        .i_tick(w_min_tick),
        .count_mode(count_mode),
        .run_stop(),
        .clear(1'b0),
        .edit_sign(edit_min),
        .o_count(min),
        .o_tick(w_hour_tick)
    );
    tick_counter #(
        .BIT_WIDTH(6),
        .TIMES(60),
        .INIT_CNT(0)
    ) sec_counter (
        .clk(clk),
        .reset(reset),
        .i_tick(w_sec_tick),
        .count_mode(count_mode),
        .run_stop(),
        .clear(1'b0),
        .edit_sign(edit_sec),
        .o_count(sec),
        .o_tick(w_min_tick)
    );
    tick_counter #(
        .BIT_WIDTH(7),
        .TIMES(100),
        .INIT_CNT(0)
    ) msec_counter (
        .clk(clk),
        .reset(reset),
        .i_tick(w_tick_100hz),
        .count_mode(count_mode),
        .run_stop(),
        .clear(1'b0),
        .edit_sign(edit_msec),
        .o_count(msec),
        .o_tick(w_sec_tick)
    );

    tick_gen_100Hz U_TICK_GEN (
        .clk(clk),
        .reset(reset),
        .i_run_stop(1'b1),
        .o_tick_100hz(w_tick_100hz)
    );

endmodule


module stopwatch_datapath (
    input        clk,
    input        reset,
    input        count_mode,
    input        run_stop,
    input        clear,
    output [6:0] msec,
    output [5:0] sec,
    output [5:0] min,
    output [4:0] hour
);

    wire w_tick_100hz, w_sec_tick, w_min_tick, w_hour_tick;

    tick_counter #(
        .BIT_WIDTH(5),
        .TIMES(24),
        .INIT_CNT(0)
    ) hour_counter (
        .clk(clk),
        .reset(reset),
        .i_tick(w_hour_tick),
        .count_mode(count_mode),
        .run_stop(run_stop),
        .clear(clear),
        .edit_sign(2'b0),
        .o_count(hour),
        .o_tick()
    );
    tick_counter #(
        .BIT_WIDTH(6),
        .TIMES(60),
        .INIT_CNT(0)
    ) min_counter (
        .clk(clk),
        .reset(reset),
        .i_tick(w_min_tick),
        .count_mode(count_mode),
        .run_stop(run_stop),
        .clear(clear),
        .edit_sign(2'b0),
        .o_count(min),
        .o_tick(w_hour_tick)
    );
    tick_counter #(
        .BIT_WIDTH(6),
        .TIMES(60),
        .INIT_CNT(0)
    ) sec_counter (
        .clk(clk),
        .reset(reset),
        .i_tick(w_sec_tick),
        .count_mode(count_mode),
        .run_stop(run_stop),
        .clear(clear),
        .edit_sign(2'b0),
        .o_count(sec),
        .o_tick(w_min_tick)
    );
    tick_counter #(
        .BIT_WIDTH(7),
        .TIMES(100),
        .INIT_CNT(0)
    ) msec_counter (
        .clk(clk),
        .reset(reset),
        .i_tick(w_tick_100hz),
        .count_mode(count_mode),
        .run_stop(run_stop),
        .clear(clear),
        .edit_sign(2'b0),
        .o_count(msec),
        .o_tick(w_sec_tick)
    );

    tick_gen_100Hz U_TICK_GEN (
        .clk(clk),
        .reset(reset),
        .i_run_stop(run_stop),
        .o_tick_100hz(w_tick_100hz)
    );

endmodule


module MUX_2x1_24bit (
    input         sel,
    input  [23:0] i_sel0,
    input  [23:0] i_sel1,
    output [23:0] o_mux
);
    assign o_mux = (sel) ? i_sel1 : i_sel0;

endmodule


module tick_counter #(
    parameter BIT_WIDTH = 7,
              TIMES     = 100,
              INIT_CNT  = 0
) (
    input                      clk,
    input                      reset,
    input                      i_tick,
    input                      count_mode,
    input                      run_stop,
    input                      clear,
    input                [1:0] edit_sign,
    output     [BIT_WIDTH-1:0] o_count,
    output reg                 o_tick
);

    // counter reg
    reg [BIT_WIDTH - 1:0] counter_reg, counter_next;

    assign o_count = counter_reg;

    // state register SL
    always @(posedge clk, posedge reset) begin
        if (reset | clear) begin
            counter_reg <= INIT_CNT;
        end else begin
            counter_reg <= counter_next;
        end
    end

    // next combinational logic (CL)
    always @(*) begin
        counter_next = counter_reg;
        o_tick       = 1'b0;

        case (edit_sign)
        2'b01:          // edit mode: up
            if(counter_reg == (TIMES - 1)) begin
                counter_next = 0;
            end else begin
                counter_next = counter_reg + 1;
            end
        2'b11:         // edit mode: down
            if(counter_reg == 0) begin
                counter_next = (TIMES - 1);
            end else begin
                counter_next = counter_reg - 1;
            end
        default:        // edit mode off
            // up count
            if (i_tick & (count_mode == 0)) begin
                if (counter_reg == (TIMES - 1)) begin
                    counter_next = 0;
                    o_tick       = 1'b1;
                end else begin
                    counter_next = counter_reg + 1;
                    o_tick       = 1'b0;
                end
            // down count
            end else if(i_tick & (count_mode == 1)) begin
                if (counter_reg == 0) begin
                    counter_next = (TIMES - 1);
                    o_tick       = 1'b1;
                end else begin
                    counter_next = counter_reg - 1;
                    o_tick       = 1'b0;
                end
            end
        endcase
    end

endmodule


module tick_gen_100Hz (
    input      clk,
    input      reset,
    input      i_run_stop,
    output reg o_tick_100hz
);

    parameter F_COUNT = 100_000_000 / 100;

    reg [$clog2(F_COUNT)-1:0] r_counter;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            r_counter    <= 0;
            o_tick_100hz <= 1'b0;
        end else begin
            if (i_run_stop) begin
                r_counter <= r_counter + 1;
                if (r_counter == (F_COUNT - 1)) begin
                    r_counter    <= 0;
                    o_tick_100hz <= 1'b1;
                end else begin
                    o_tick_100hz <= 1'b0;
                end
            end
        end
    end

endmodule
