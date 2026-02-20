`timescale 1ns / 1ps

module uart_top (
    input        clk,
    input        rst,
    input [31:0] fnd_in_data,
    input  [5:0] sw,
    input        btn_u,
    input        btn_d,
    input        btn_r,
    input        btn_l,
    input        uart_rx,
    output       uart_tx,
    output [5:0] sw_in,
    output       btn_in_u,
    output       btn_in_d,
    output       btn_in_r,
    output       btn_in_l
);

    // recieve ASCII control variable
    wire [3:0] w_ASCII;
    // uart_rx
    wire w_rx_done;
    wire [7:0] w_rx_data;
    // uart_tx
    wire w_b_tick;
    wire w_tx_busy;
    wire w_tx_done;
    // fifo rx
    wire [7:0] w_fifo_rx_out;
    wire w_fifo_rx_empty;
    wire w_fifo_rx_pop;
    // fifo tx
    wire w_tx_start_from_sender;
    wire [7:0] w_tx_data_from_sender;
    wire [7:0] w_fifo_tx_out;
    wire w_fifo_tx_empty;
    wire w_fifo_tx_pop;

    // data
    wire [23:0] w_data_watch;

    assign w_fifo_rx_pop = !w_fifo_rx_empty;

    // uart ASCII to stopwatch_watch
    signal_select_unit U_SIGNAL_SEL (
        .ASCII(w_ASCII),
        .btn_in_up(btn_u),
        .btn_in_down(btn_d),
        .btn_in_right(btn_r),
        .btn_in_left(btn_l),
        .sw_in(sw),
        .btn_out_up(btn_in_u),
        .btn_out_down(btn_in_d),
        .btn_out_right(btn_in_r),
        .btn_out_left(btn_in_l),
        .btn_send(btn_in_send),
        .sw_out(sw_in)
    );

    // ASCII decoder
    ASCII_decoder U_ASCII_DECODER (
        .in_data(w_fifo_rx_out),
        .done(w_fifo_rx_pop),
        .ASCII(w_ASCII)
    );

    // ASCII sender
    ASCII_sender U_ASCII_SENDER (
        .clk(clk),
        .rst(rst),
        .fnd_sel({sw[2], sw[1], sw[0]}),
        .fnd_data(fnd_in_data),
        .send_start(btn_in_send),
        .tx_done(w_tx_done),
        .tx_start(w_tx_start_from_sender),
        .tx_data(w_tx_data_from_sender)
    );

    // fifo
    // between ASCII sender <-> tx
    fifo #(
        .DEPTH(16),
        .BIT_WIDTH(8)
    ) U_FIFO_SENDER_TX (
        .clk(clk),
        .rst(rst),
        .push(w_tx_start_from_sender),
        .pop(w_fifo_tx_pop),
        .push_data(w_tx_data_from_sender),
        .pop_data(w_fifo_tx_out),
        .full(),
        .empty(w_fifo_tx_empty)
    );
    // between ASCII decoder <-> rx
    fifo #(
        .DEPTH(4),
        .BIT_WIDTH(8)
    ) U_FIFO_DECODER_RX (
        .clk(clk),
        .rst(rst),
        .push(w_rx_done),
        .pop(w_fifo_rx_pop),
        .push_data(w_rx_data),
        .pop_data(w_fifo_rx_out),
        .full(),
        .empty(w_fifo_rx_empty)
    );

    // uart rx
    uart_rx U_UART_RX (
        .clk(clk),
        .rst(rst),
        .rx(uart_rx),
        .b_tick(w_b_tick),
        .rx_data(w_rx_data),
        .rx_done(w_rx_done)
    );

    // uart tx
    uart_tx U_UART_TX (
        .clk(clk),
        .rst(rst),
        .tx_start(w_fifo_tx_pop),
        .b_tick(w_b_tick),
        .tx_data(w_fifo_tx_out),
        .tx_busy(w_tx_busy),
        .tx_done(w_tx_done),
        .uart_tx(uart_tx)
    );

    // 9600 x 16 baud tick
    baud_tick U_BOUD_TICK (
        .clk(clk),
        .reset(rst),
        .b_tick(w_b_tick)
    );

endmodule





module signal_select_unit (
    input      [3:0] ASCII,
    input            btn_in_up,
    input            btn_in_down,
    input            btn_in_right,
    input            btn_in_left,
    input      [5:0] sw_in,
    output reg       btn_out_up,
    output reg       btn_out_down,
    output reg       btn_out_right,
    output reg       btn_out_left,
    output reg       btn_send,
    output     [5:0] sw_out
);

    // swtich
    assign sw_out = sw_in;


    always @(*) begin
        btn_out_up = 1'b0;
        btn_out_down = 1'b0;
        btn_out_right = 1'b0;
        btn_out_left = 1'b0;
        btn_send = 1'b0;
        // button
        if ((ASCII == 4'b0001) | (btn_in_right)) btn_out_right = 1'b1;
        else if ((ASCII == 4'b0010) | (btn_in_left)) btn_out_left = 1'b1;
        else if ((ASCII == 4'b0011) | (btn_in_up)) btn_out_up = 1'b1;
        else if ((ASCII == 4'b0100) | (btn_in_down)) btn_out_down = 1'b1;
        // state
        if (ASCII == 4'b1000) btn_send = 1'b1;
    end

endmodule

module ASCII_sender (
    input            clk,
    input            rst,
    input      [2:0] fnd_sel,      // 001: watch, 010: SR04, 100: DHT11
    input     [31:0] fnd_data,
    input            send_start,
    input            tx_done,
    output reg       tx_start,
    output reg [7:0] tx_data
);

    // fnd_sel parameter
    localparam WATCH = 3'b001, SR04 = 3'b010, DHT11 = 3'b100;

    // state
    localparam IDLE = 0, FND_SELECT = 1, START = 2, SENDING = 3, WAIT = 4;
    reg [2:0] c_state, n_state;
    // data buffer
    reg [31:0] data_buf;
    // tx sending count 0~12
    reg [3:0] tx_send_cnt_reg, tx_send_cnt_next;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            c_state         <= 0;
            data_buf        <= 0;
            tx_send_cnt_reg <= 0;
        end else begin
            c_state         <= n_state;
            tx_send_cnt_reg <= tx_send_cnt_next;
        end
    end

    always @(*) begin
        n_state = c_state;
        tx_start = 0;
        tx_data = 8'd0;
        tx_send_cnt_next = tx_send_cnt_reg;

        case (c_state)
            IDLE: begin
                if (send_start) begin
                    n_state = FND_SELECT;
                end
            end
            FND_SELECT: begin
                case (fnd_sel)
                    WATCH: begin
                        case (tx_send_cnt_reg)
                            0: tx_data = {4'b0, data_buf[31:28]};   //hour
                            1: tx_data = {4'b0, data_buf[27:24]};
                            2: tx_data = 8'h3A;                     // :
                            3: tx_data = {4'b0, data_buf[23:20]};   // min
                            4: tx_data = {4'b0, data_buf[19:16]};
                            5: tx_data = 8'h3A;                     // :
                            6: tx_data = {4'b0, data_buf[15:12]};   // sec
                            7: tx_data = {4'b0, data_buf[11:8]};
                            8: tx_data = 8'h27;                     // '
                            9: tx_data = {4'b0, data_buf[7:4]};     //msec
                            10: tx_data = {4'b0, data_buf[3:0]};
                            default: tx_data = 0;
                        endcase
                    end
                    SR04: begin
                        case (tx_send_cnt_reg)
                            0: tx_data = {4'b0, data_buf[11:8]};
                            1: tx_data = {4'b0, data_buf[7:4]};
                            2: tx_data = {4'b0, data_buf[3:0]};
                            3: tx_data = 8'h63;                      // c
                            4: tx_data = 8'h6D;                      // m
                            default: tx_data = 0;
                        endcase
                    end
                    DHT11: begin
                        case (tx_send_cnt_reg)
                            0: tx_data = {4'b0, data_buf[31:28]};
                            1: tx_data = {4'b0, data_buf[27:24]};
                            2: tx_data = 8'h2E;                      // .
                            3: tx_data = {4'b0, data_buf[23:20]};
                            4: tx_data = {4'b0, data_buf[19:16]};
                            5: tx_data = 8'h43;                      //C
                            6: tx_data = 8'h20;                      // SPACE
                            7: tx_data = {4'b0, data_buf[15:12]};
                            8: tx_data = {4'b0, data_buf[11:8]};
                            9: tx_data = 8'h2E;                      // .
                            10: tx_data = {4'b0, data_buf[7:4]};
                            11: tx_data = {4'b0, data_buf[3:0]};
                            12: tx_data = 8'h25;                     // %
                            default: tx_data = 0;
                        endcase
                    end
                    //default:
                endcase

                // 0~9 숫자 인풋, ASCII 문자로 변환
                tx_data = tx_data + 8'h30;

                n_state = START;
            end
            START: begin
                // uart_tx <- 전송 가능 상태로 전환
                tx_start = 1;
                n_state  = SENDING;
            end
            SENDING: begin
                if (tx_done) begin  // uart_tx <- 전송 done check
                    n_state = WAIT;
                end
            end
            WAIT: begin
                tx_send_cnt_next = tx_send_cnt_reg + 1;

                case (fnd_sel)
                    WATCH: begin
                        if (tx_send_cnt_reg == 11) begin
                            n_state = IDLE;
                        end else begin
                            n_state = FND_SELECT;
                        end
                    end
                    SR04: begin
                        if (tx_send_cnt_reg == 6) begin
                            n_state = IDLE;
                        end else begin
                            n_state = FND_SELECT;
                        end
                    end
                    DHT11: begin
                        if (tx_send_cnt_reg == 13) begin
                            n_state = IDLE;
                        end else begin
                            n_state = FND_SELECT;
                        end
                    end
                    //default:
                endcase
            end
            default: n_state = IDLE;
        endcase
    end

endmodule

module ASCII_decoder (
    input      [7:0] in_data,
    input            done,
    output reg [3:0] ASCII
);

    always @(*) begin
        ASCII = 4'b0000;
        if (done) begin
            case (in_data)
                8'b0111_0010: ASCII = 4'b0001;  //r
                8'h6c: ASCII = 4'b0010;  //l
                8'b0111_0101: ASCII = 4'b0011;  //u
                8'b0110_0100: ASCII = 4'b0100;  //d
                8'b0011_0000: ASCII = 4'b0101;  //0
                8'b0011_0001: ASCII = 4'b0110;  //1
                8'b0011_0010: ASCII = 4'b0111;  //2
                8'b0111_0011: ASCII = 4'b1000;  //s
                default: ASCII = 4'b0000;
            endcase
        end
    end

endmodule


module uart_rx (
    input        clk,
    input        rst,
    input        rx,
    input        b_tick,
    output [7:0] rx_data,
    output       rx_done
);

    // FSM state
    localparam IDLE = 2'd0, START = 2'd1, DATA = 2'd2, STOP = 2'd3;
    reg [1:0] c_state, n_state;
    // x16 tick counter
    reg [4:0] b_tick_cnt_reg, b_tick_cnt_next;
    // uart 8-bit data counter
    reg [2:0] bit_cnt_next, bit_cnt_reg;
    // uart done, rx data
    reg done_reg, done_next;
    reg [7:0] buf_reg, buf_next;

    assign rx_data = buf_reg;
    assign rx_done = done_reg;

    // state register
    always @(posedge clk, posedge rst) begin
        if (rst) begin
            c_state        <= 2'd0;
            b_tick_cnt_reg <= 5'd0;
            bit_cnt_reg    <= 3'd0;
            done_reg       <= 1'b0;
            buf_reg        <= 8'd0;
        end else begin
            c_state        <= n_state;
            b_tick_cnt_reg <= b_tick_cnt_next;
            bit_cnt_reg    <= bit_cnt_next;
            done_reg       <= done_next;
            buf_reg        <= buf_next;
        end
    end

    // next, output
    always @(*) begin
        n_state         = c_state;
        b_tick_cnt_next = b_tick_cnt_reg;
        bit_cnt_next    = bit_cnt_reg;
        done_next       = done_reg;
        buf_next        = buf_reg;

        case (c_state)
            IDLE: begin
                bit_cnt_next    = 3'd0;
                b_tick_cnt_next = 5'd0;
                done_next       = 1'b0;
                buf_next        = 8'd0;
                if (b_tick & !rx) begin
                    buf_next = 8'd0;
                    n_state  = START;
                end
            end
            START: begin
                if (b_tick) begin
                    if (b_tick_cnt_reg == 7) begin
                        b_tick_cnt_next = 5'd0;
                        n_state = DATA;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end
            DATA: begin
                if (b_tick) begin
                    if (b_tick_cnt_reg == 4'd15) begin
                        b_tick_cnt_next = 4'd0;
                        buf_next = {rx, buf_reg[7:1]};
                        if (bit_cnt_reg == 7) begin
                            n_state = STOP;
                        end else begin
                            bit_cnt_next = bit_cnt_reg + 1;
                        end
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end
            STOP: begin
                if (b_tick) begin
                    if (b_tick_cnt_reg == 15) begin
                        n_state   = IDLE;
                        done_next = 1'b1;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end
        endcase
    end

endmodule


module uart_tx (
    input        clk,
    input        rst,
    input        tx_start,
    input        b_tick,
    input  [7:0] tx_data,
    output       tx_busy,   //안전한 출력을 위해
    output       tx_done,
    output       uart_tx
);

    localparam IDLE = 2'd0, START = 2'd1, DATA = 2'd2, STOP = 2'd3;

    //state reg
    reg [1:0] c_state, n_state;
    reg
        tx_reg,
        tx_next;           //출력을 순차논리를 이용해 노이즈 제거하기 위해

    //BIT_CNT
    reg [2:0]
        bit_cnt_reg,
        bit_cnt_next;  //카운터를 피드백 구조 래치방지
    //tick_count
    reg [3:0] b_tick_cnt_reg, b_tick_cnt_next;
    //busy,done
    reg busy_reg, busy_next;
    reg done_reg, done_next;
    //buffer
    reg [7:0] data_in_buf_reg, data_in_buf_next;

    assign tx_busy = busy_reg;
    assign tx_done = done_reg;
    assign uart_tx = tx_reg;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            c_state <= IDLE;
            tx_reg <= 1'b1;
            bit_cnt_reg <= 1'b0;
            busy_reg <= 0;
            done_reg <= 0;
            data_in_buf_reg <= 0;
            b_tick_cnt_reg <= 0;
        end else begin
            c_state <= n_state;
            tx_reg <= tx_next;
            bit_cnt_reg <= bit_cnt_next;
            busy_reg <= busy_next;
            done_reg <= done_next;
            data_in_buf_reg <= data_in_buf_next;
            b_tick_cnt_reg <= b_tick_cnt_next;
        end
    end

    always @(*) begin
        //initialize
        n_state          = c_state;
        tx_next          = tx_reg;
        bit_cnt_next     = bit_cnt_reg;
        b_tick_cnt_next  = b_tick_cnt_reg;
        busy_next        = busy_reg;
        done_next        = done_reg;
        data_in_buf_next = data_in_buf_reg;

        case (c_state)
            IDLE: begin
                tx_next = 1'b1;
                bit_cnt_next = 0;
                b_tick_cnt_next = 4'h0;
                busy_next = 0;
                done_next = 0;
                if (tx_start == 1) begin
                    n_state = START;
                    busy_next = 1'b1;
                    data_in_buf_next = tx_data;
                end
            end
            START: begin
                tx_next = 1'b0;
                if (b_tick == 1) begin
                    if (b_tick_cnt_reg == 15) begin
                        n_state = DATA;
                        b_tick_cnt_next = 0;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end
            DATA: begin
                tx_next = data_in_buf_reg[0];
                if (b_tick) begin
                    if (b_tick_cnt_reg == 15) begin
                        b_tick_cnt_next = 4'h0;
                        if (bit_cnt_reg == 7) begin
                            n_state = STOP;
                        end else begin
                            b_tick_cnt_next = 4'h0;
                            bit_cnt_next = bit_cnt_reg + 1;
                            n_state = DATA;
                            data_in_buf_next = {1'b0, data_in_buf_reg[7:1]};
                        end
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end
            STOP: begin
                tx_next = 1'b1;
                if (b_tick == 1) begin
                    if (b_tick_cnt_reg == 15) begin
                        done_next = 1;
                        busy_next = 1'b0;
                        n_state   = IDLE;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end
        endcase
    end

endmodule


module baud_tick (
    input clk,
    input reset,
    output reg b_tick
);

    parameter BAUDRATE = 9600 * 16;
    parameter F_COUNT = 100_000_000 / BAUDRATE;

    reg [$clog2(F_COUNT)-1 : 0] count_reg;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            count_reg <= 0;
            b_tick <= 1'b0;
        end else begin
            if (count_reg == (F_COUNT - 1)) begin
                b_tick <= 1;
                count_reg <= 0;
            end else begin
                count_reg <= count_reg + 1;
                b_tick <= 0;
            end
        end
    end

endmodule
