`timescale 1ns / 1ps

module top_dht11 (
    input        clk,
    input        rst,
    input        btn_r,
    input        sw,
    inout        dht11_io,
    output [3:0] fnd_digit,
    output [7:0] fnd_data
);

    // button
    wire o_btn_r;
    // dht11 output
    wire [15:0] w_humidity, w_temperature;

    btn_debounce U_BD_R (
        .clk(clk),
        .reset(rst),
        .i_btn(btn_r),
        .o_btn(o_btn_r)
    );

    dht11_controller U_DHT11_CTRL (
        .clk(clk),
        .rst(rst),
        .start(o_btn_r),
        .humidity(w_humidity),
        .temperature(w_temperature),
        .dht11_done(),
        .dht11_valid(),
        .debug(),
        .dhtio(dht11_io)
    );

    fnd_controller_dht11 U_FND_CTRL_DHT11 (
        .clk(clk),
        .reset(rst),
        .sel_display(sw),
        .fnd_in_data({w_humidity, w_temperature}),
        .fnd_digit(fnd_digit),
        .fnd_data(fnd_data)
    );
endmodule

module dht11_controller (
    input         clk,
    input         rst,
    input         start,
    output [15:0] humidity,
    output [15:0] temperature,
    output        dht11_done,
    output        dht11_valid,
    output [ 3:0] debug,
    inout         dhtio
);

    wire tick_10u;

    tick_gen_10u U_TICK_10u (
        .clk(clk),
        .rst(rst),
        .tick_10u(tick_10u)
    );

    //STATE
    parameter IDLE      = 0,
              START     = 1,
              WAIT      = 2,
              SYNC_L    = 3,
              SYNC_H    = 4,
              DATA_SYNC = 5,
              DATA_C    = 6,
              STOP      = 7;
    reg [2:0] c_state, n_state;

    // sensor state control
    reg dhtio_reg, dhtio_next;
    reg
        io_sel_reg,
        io_sel_next;  // FSM 안에서 제어. 조합으로 내보냄.
    reg done_reg, done_next;
    reg valid_reg, valid_next;

    // sensor data control
    reg [5:0] bit_cnt_reg, bit_cnt_next;  // to count 40
    reg [39:0] data_reg, data_next;  // 40-bit data

    // tick counter in FSM
    // for 19msec count by 10usec tick
    reg [$clog2(1900)-1:0]
        tick_cnt_reg,
        tick_cnt_next; // 내부에서 쓰는 것은 무조건 F/F으로 가야함

    // data update
    reg [15:0] humidity_reg, humidity_next;
    reg [15:0] temperature_reg, temperature_next;

    assign dhtio = (io_sel_reg) ? dhtio_reg : 1'bz;  //tri-state buffer
    assign debug = c_state;
    assign dht11_done = done_reg;
    assign dht11_valid = valid_reg;
    assign humidity = humidity_reg;
    assign temperature = temperature_reg;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            c_state         <= 3'b000;
            dhtio_reg       <= 1'b1;
            io_sel_reg      <= 1'b1;
            done_reg        <= 0;
            valid_reg       <= 0;
            tick_cnt_reg    <= 0;
            bit_cnt_reg     <= 0;
            data_reg        <= 0;
            humidity_reg    <= 0;
            temperature_reg <= 0;
        end else begin
            c_state         <= n_state;
            dhtio_reg       <= dhtio_next;
            io_sel_reg      <= io_sel_next;
            done_reg        <= done_next;
            valid_reg       <= valid_next;
            tick_cnt_reg    <= tick_cnt_next;
            bit_cnt_reg     <= bit_cnt_next;
            data_reg        <= data_next;
            humidity_reg    <= humidity_next;
            temperature_reg <= temperature_next;
        end
    end

    // next, output
    always @(*) begin
        n_state          = c_state;
        tick_cnt_next    = tick_cnt_reg;
        dhtio_next       = dhtio_reg;
        io_sel_next      = io_sel_reg;
        done_next        = done_reg;
        valid_next       = valid_reg;
        bit_cnt_next     = bit_cnt_reg;
        data_next        = data_reg;
        humidity_next    = humidity_reg;
        temperature_next = temperature_reg;

        case (c_state)
            IDLE: begin
                bit_cnt_next = 0;
                done_next = 1'b0;
                valid_next = 1'b0;
                if (start) begin
                    n_state = START;
                end
            end
            START: begin
                dhtio_next = 1'b0;
                if (tick_10u) begin
                    tick_cnt_next = tick_cnt_reg + 1;
                    if (tick_cnt_reg == 1900) begin
                        tick_cnt_next = 0; // 재활용 할거기 때문에 state 이동 전에 초기화
                        n_state = WAIT;
                    end
                end
            end
            WAIT: begin
                dhtio_next = 1'b1;
                if (tick_10u) begin
                    tick_cnt_next = tick_cnt_reg + 1;
                    if (tick_cnt_reg == 3) begin    // 30us 정도는 끌어주는 것이 좋더라!
                        // for output to high-z
                        n_state       = SYNC_L;
                        tick_cnt_next = 0;
                        io_sel_next   = 1'b0;  // io_sel 의 출력을 끊음
                    end
                end
            end
            SYNC_L: begin
                if(tick_10u) begin  // 100MHz가 아닌 10u tick일때만 count -> metastable 확률을 확 줄임.
                    if (dhtio == 0) begin
                        //edge detection을 활용하는 방식으로 할 수도 있음.
                        //지금은 state를 나누고 tick 신호마다 읽어서 LOW, HIGH이느냐를 판별하는 방식.
                        n_state = SYNC_H;
                    end
                end
            end
            SYNC_H: begin
                if (tick_10u) begin
                    if (dhtio == 0) begin    // SYNC_L, SYNC_H로 나눠서 설계하는 로직의 위험성: noise!
                        n_state = DATA_SYNC; // noise를 잡고 싶으면 dhtio 앞단에 synchronizer를 추가하면 됨.
                    end
                end
            end
            DATA_SYNC: begin
                if (tick_10u) begin
                    if (dhtio == 1) begin
                        n_state = DATA_C;
                    end
                end
            end
            DATA_C: begin
                if (tick_10u) begin
                    if (dhtio == 1) begin
                        tick_cnt_next = tick_cnt_reg + 1;
                    end else begin
                        // dhtio가 LOW일 때 40us보다 짧으면 0
                        if (tick_cnt_reg < 4) begin
                            data_next = {data_reg[38:0], 1'b0};
                            // 40us보다 길면 1
                        end else begin
                            data_next = {data_reg[38:0], 1'b1};
                        end
                        tick_cnt_next = 0;

                        // 40-bit 모두 채우면 STOP state로 이동
                        // 모두 채우지 못했을 경우 DATA_SYNC로 이동
                        if (bit_cnt_reg == 39) begin
                            n_state = STOP;
                        end else begin
                            bit_cnt_next = bit_cnt_next + 1;
                            n_state = DATA_SYNC;
                        end
                    end
                end
            end
            STOP: begin
                if (tick_10u) begin
                    tick_cnt_next = tick_cnt_reg + 1;
                    if (tick_cnt_reg == 5) begin
                        done_next = 1'b1;
                        if(data_reg[39:32] + data_reg[31:24] + data_reg[23:16] + data_reg[15:8] == data_reg[7:0]) begin
                            humidity_next    = {data_reg[39:24]};
                            temperature_next = {data_reg[23:8]};
                            valid_next = 1'b1;
                        end else begin
                            valid_next = 1'b0;
                        end
                        // output mode (to IDLE)
                        dhtio_next    = 1'b1;
                        io_sel_next   = 1'b1;
                        n_state       = IDLE;
                        tick_cnt_next = 0;
                    end
                end
            end
        endcase
    end

endmodule

module tick_gen_10u (
    input      clk,
    input      rst,
    output reg tick_10u
);

    parameter F_COUNT = 100_000_000 / 100_000;
    reg [$clog2(F_COUNT)-1:0] counter_reg;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            counter_reg <= 0;
            tick_10u    <= 1'b0;
        end else begin
            counter_reg <= counter_reg + 1;
            if (counter_reg == F_COUNT - 1) begin
                counter_reg <= 0;
                tick_10u    <= 1'b1;
            end else begin
                tick_10u <= 1'b0;
            end
        end
    end

endmodule
