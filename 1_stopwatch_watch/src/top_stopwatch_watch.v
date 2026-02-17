`timescale 1ns / 1ps

module top_stopwatch_watch (
    input        clk,
    input        reset,
    input  [3:0] sw,         // sw[0]: down/up, sw[1]: stopwatch/watch, sw[2]: hour/sec, sw[3]: watch_edit/none
    input        btn_u,      // sw[1]=0,sw[3]=1 - up
    input        btn_d,      // sw[1]=0,sw[3]=1 - down
    input        btn_r,      // sw[1]=1,sw[3]=0 - run/stop,   sw[1]=0,sw[3]=1 - right
    input        btn_l,      // sw[1]=1,sw[3]=0 - clear/none, sw[1]=0,sw[3]=1 - left
    output [3:0] fnd_digit,
    output [7:0] fnd_data,
    output [3:0] LED         // LED[0]~[3]: editing msec, sec, min, hour
);

    wire [13:0] w_counter;
    wire w_run_stop, w_clear, w_mode;
    wire o_btn_up, o_btn_down, o_btn_right, o_btn_left;
    wire [23:0] w_watch_time;
    wire [23:0] w_stopwatch_time;
    wire [23:0] w_mux_2x1_24bit_out;
    
        btn_debounce U_BD_RUNSTOP (
        .clk  (clk),
        .reset(reset),
        .i_btn(btn_u),
        .o_btn(o_btn_up)
    );
    
    btn_debounce U_BD_DOWN (
        .clk  (clk),
        .reset(reset),
        .i_btn(btn_d),
        .o_btn(o_btn_down)
    );

    btn_debounce U_BD_RIGHT (
        .clk  (clk),
        .reset(reset),
        .i_btn(btn_r),
        .o_btn(o_btn_right)
    );

    btn_debounce U_BD_LEFT (
        .clk  (clk),
        .reset(reset),
        .i_btn(btn_l),
        .o_btn(o_btn_left)
    );

    control_unit U_CONTROL_UNIT (
        .clk(clk),
        .reset(reset),
        .i_mode(sw[0]),
        .i_run_stop(o_btn_right),
        .i_clear(o_btn_left),
        .o_mode(w_mode),
        .o_run_stop(w_run_stop),
        .o_clear(w_clear)
    );

    MUX_2x1_24BIT U_MUX_WATCH_STOPWATCH (
        .sel(sw[1]),
        .i_sel0(w_watch_time),
        .i_sel1(w_stopwatch_time),
        .o_mux(w_mux_2x1_24bit_out)
    );

    watch_datapath U_WATCH_DATAPATH (
        .clk(clk),
        .reset(reset),
        .mode(w_mode),
        .stopwatch(sw[1]),
        .edit(sw[3]),
        .up(o_btn_up),
        .down(o_btn_down),
        .right(o_btn_right),
        .left(o_btn_left),
        .msec(w_watch_time[6:0]),     // 7-bit
        .sec(w_watch_time[12:7]),     // 6-bit
        .min(w_watch_time[18:13]),     // 6-bit
        .hour(w_watch_time[23:19]),    // 5-bit
        .LED(LED)
    );

    stopwatch_datapath U_STOPWATCH_DATAPATH (
        .clk(clk),
        .reset(reset),
        .mode(w_mode),
        .stopwatch(sw[1]),
        .clear(w_clear),
        .run_stop(w_run_stop),
        .msec(w_stopwatch_time[6:0]),   // 7-bit
        .sec(w_stopwatch_time[12:7]),   // 6-bit
        .min(w_stopwatch_time[18:13]),   // 6-bit
        .hour(w_stopwatch_time[23:19])  // 5-bit
    );

    fnd_controller U_FND_CNTL (
        .clk(clk),
        .reset(reset),
        .sel_display(sw[2]),
        .fnd_in_data(w_mux_2x1_24bit_out),
        .fnd_digit(fnd_digit),
        .fnd_data(fnd_data)
    );
endmodule

module MUX_2x1_24BIT (
    input sel,
    input [23:0] i_sel0,
    input [23:0] i_sel1,
    output [23:0] o_mux
);

    assign o_mux = (sel) ? i_sel1 : i_sel0;

endmodule

module watch_datapath (
    input        clk,
    input        reset,
    input        mode,
    input        stopwatch,
    input        edit,
    input        up,
    input        down,
    input        right,
    input        left,
    output [6:0] msec,
    output [5:0] sec,
    output [5:0] min,
    output [4:0] hour,
    output reg [3:0] LED
);

    wire w_tick_100hz_watch, w_sec_tick_watch, w_min_tick_watch, w_hour_tick_watch;
    reg [1:0] w_hour_edit, w_min_edit, w_sec_edit, w_msec_edit;
    localparam MSEC = 2'b00, SEC = 2'b01, MIN = 2'b10, HOUR = 2'b11;

// reg variable
    reg [1:0] current_st, next_st;

    // state register SL
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            current_st <= MSEC;
        end else if ((stopwatch == 0) & (edit == 1)) begin
            current_st <= next_st;
        end
    end

    always @(*) begin
        //initialize
        next_st = current_st;
        w_hour_edit = 2'b00;
        w_min_edit = 2'b00;
        w_sec_edit = 2'b00;
        w_msec_edit = 2'b00;
        LED = 4'b0000;

        case(current_st)
        MSEC: begin
            LED = 4'b0001;
            if(up) begin
                w_msec_edit = 2'b01;
            end else if (down) begin
                w_msec_edit = 2'b10;
            end else if (right) begin
                next_st = HOUR;
            end else if (left) begin
                next_st = SEC;
            end
        end
        SEC: begin
            LED = 4'b0010;
            if(up) begin
                w_sec_edit = 2'b01;
            end else if (down) begin
                w_sec_edit = 2'b10;
            end else if (right) begin
                next_st = MSEC;
            end else if (left) begin
                next_st = MIN;
            end
        end
        MIN: begin
            LED = 4'b0100;
            if(up) begin
                w_min_edit = 2'b01;
            end else if (down) begin
                w_min_edit = 2'b10;
            end else if (right) begin
                next_st = SEC;
            end else if (left) begin
                next_st = HOUR;
            end
        end
        HOUR: begin
            LED = 4'b1000;
            if(up) begin
                w_hour_edit = 2'b01;
            end else if (down) begin
                w_hour_edit = 2'b10;
            end else if (right) begin
                next_st = MIN;
            end else if (left) begin
                next_st = MSEC;
            end
        end
        endcase
    end

    tick_counter #(
        .BIT_WIDTH(5),
        .TIMES(24)
    ) hour_counter_watch (
        .clk(clk),
        .reset(reset),
        .i_tick(w_hour_tick_watch),
        .mode(mode),
        .stopwatch(stopwatch),
        .edit_sign(w_hour_edit),
        .clear(1'b0),
        .run_stop(1'b1),
        .o_count(hour),
        .o_tick()
    );
    tick_counter #(
        .BIT_WIDTH(6),
        .TIMES(60)
    ) min_counter_watch (
        .clk(clk),
        .reset(reset),
        .i_tick(w_min_tick_watch),
        .mode(mode),
        .stopwatch(stopwatch),
        .edit_sign(w_min_edit),
        .clear(1'b0),
        .run_stop(1'b1),
        .o_count(min),
        .o_tick(w_hour_tick_watch)
    );
    tick_counter #(
        .BIT_WIDTH(6),
        .TIMES(60)
    ) sec_counter_watch (
        .clk(clk),
        .reset(reset),
        .i_tick(w_sec_tick_watch),
        .mode(mode),
        .stopwatch(stopwatch),
        .edit_sign(w_sec_edit),
        .clear(1'b0),
        .run_stop(1'b1),
        .o_count(sec),
        .o_tick(w_min_tick_watch)
    );
    tick_counter #(
        .BIT_WIDTH(7),
        .TIMES(100)
    ) msec_counter_watch (
        .clk(clk),
        .reset(reset),
        .i_tick(w_tick_100hz_watch),
        .mode(mode),
        .stopwatch(stopwatch),
        .edit_sign(w_msec_edit),
        .clear(1'b0),
        .run_stop(1'b1),
        .o_count(msec),
        .o_tick(w_sec_tick_watch)
    );

    tick_gen_100Hz U_TICK_GEN (
        .clk(clk),
        .reset(reset),
        .i_run_stop(1'b1),
        .o_tick_100hz(w_tick_100hz_watch)
    );

endmodule

module stopwatch_datapath (
    input        clk,
    input        reset,
    input        mode,
    input        stopwatch,
    input        clear,
    input        run_stop,
    output [6:0] msec,
    output [5:0] sec,
    output [5:0] min,
    output [4:0] hour
);

    wire w_tick_100hz, w_sec_tick, w_min_tick, w_hour_tick;

    tick_counter #(
        .BIT_WIDTH(5),
        .TIMES(24)
    ) hour_counter (
        .clk(clk),
        .reset(reset),
        .i_tick(w_hour_tick),
        .mode(mode),
        .stopwatch(stopwatch),
        .edit_sign(),
        .clear(clear),
        .run_stop(run_stop),
        .o_count(hour),
        .o_tick()
    );
    tick_counter #(
        .BIT_WIDTH(6),
        .TIMES(60)
    ) min_counter (
        .clk(clk),
        .reset(reset),
        .i_tick(w_min_tick),
        .mode(mode),
        .stopwatch(stopwatch),
        .edit_sign(),
        .clear(clear),
        .run_stop(run_stop),
        .o_count(min),
        .o_tick(w_hour_tick)
    );
    tick_counter #(
        .BIT_WIDTH(6),
        .TIMES(60)
    ) sec_counter (
        .clk(clk),
        .reset(reset),
        .i_tick(w_sec_tick),
        .mode(mode),
        .stopwatch(stopwatch),
        .edit_sign(),
        .clear(clear),
        .run_stop(run_stop),
        .o_count(sec),
        .o_tick(w_min_tick)
    );
    tick_counter #(  // instance할 때 parameter 값도
        .BIT_WIDTH(7),     // 괄호 쳐서 전달해야 함에 주의
        .TIMES(100)
    ) msec_counter (
        .clk(clk),
        .reset(reset),
        .i_tick(w_tick_100hz),
        .mode(mode),
        .stopwatch(stopwatch),
        .edit_sign(),
        .clear(clear),
        .run_stop(run_stop),
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

// msec, sec, min, hour
// tick counter
module tick_counter #(
    parameter BIT_WIDTH = 7,
    TIMES = 100
) (
    input                      clk,
    input                      reset,
    input                      i_tick,
    input                      mode,
    input                [1:0] edit_sign,
    input                      stopwatch,
    input                      clear,
    input                      run_stop,
    output     [BIT_WIDTH-1:0] o_count,
    output reg                 o_tick
);

    // counter reg
    reg [BIT_WIDTH - 1:0] counter_reg, counter_next;

    assign o_count = counter_reg;

    // state register SL
    always @(posedge clk, posedge reset) begin
        if (reset | clear) begin
            if(BIT_WIDTH == 5 & stopwatch == 0) begin
                counter_reg <= 12;
            end else begin
                counter_reg <= 0;
            end
         end else begin
            counter_reg <= counter_next;
        end
    end

    // next combinational logic (CL)
    always @(*) begin
        counter_next = counter_reg;
        o_tick = 1'b0;                          // reg type 이므로 latch를 방지해 주기 위해 초기화
        if (i_tick & run_stop) begin
            if (mode == 1'b1) begin
                // down
                if (counter_reg == 0) begin
                    counter_next = (TIMES - 1);
                    o_tick = 1'b1;
                end else begin
                    counter_next = counter_reg - 1;
                    o_tick = 1'b0;
                end
            end else begin
                // up
                if (counter_reg == (TIMES - 1)) begin
                    counter_next = 0;
                    o_tick = 1'b1;
                end else begin
                    counter_next = counter_reg + 1;
                    o_tick = 1'b0;
                end
            end
        end
    end

endmodule

module tick_gen_100Hz (
    input clk,
    input reset,
    input i_run_stop,
    output reg o_tick_100hz  // always의 출력은 항상 reg
);

    parameter F_COUNT = 100_000_000 / 100;

    reg [$clog2(F_COUNT)-1:0] r_counter;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            r_counter <= 0;
            o_tick_100hz <= 1'b0;
        end else begin
            if (i_run_stop) begin
                r_counter <= r_counter + 1;
                if (r_counter == (F_COUNT - 1)) begin
                    r_counter <= 0;
                    o_tick_100hz <= 1'b1;
                end else begin
                    o_tick_100hz <= 1'b0;
                end
            end
        end
    end
endmodule

