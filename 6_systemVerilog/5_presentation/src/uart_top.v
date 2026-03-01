`timescale 1ns / 1ps

module top_uart (
    input        clk,
    input        rst,
    input  [3:0] i_sw,
    input        i_btn_u,
    input        i_btn_d,
    input        i_btn_r,
    input        i_btn_l,
    input        uart_rx,
    input [31:0] sender_data,
    output       uart_tx,
    output [3:0] o_sw,
    output       o_btn_u,
    output       o_btn_d,
    output       o_btn_r,
    output       o_btn_l,
    output       send
);

    // button_debounce
    wire o_btn_up, o_btn_down, o_btn_right, o_btn_left;
    // uart_rx, rx_fifo
    wire w_rx_done;
    wire [7:0] w_rx_data, w_rx_fifo_data;
    wire w_rx_fifo_full, w_rx_fifo_empty;
    // ascii_decoder
    wire [3:0] w_control;
    //reg r_decoder_wake;
    // ascii_sender
    wire [7:0] w_sender_data_out;
    // uart_tx
    wire w_b_tick;
    wire w_tx_done, w_tx_busy;
    wire [7:0] w_tx_fifo_data;
    wire w_tx_fifo_push, w_tx_fifo_full, w_tx_fifo_empty;

    //always @(posedge clk) begin
    //    if(rst) r_decoder_wake <= 0;
    //    else    r_decoder_wake <= !w_rx_fifo_empty;
    //end

    // button debounce
    btn_debounce U_BD_UP (
        .clk  (clk),
        .reset(rst),
        .i_btn(i_btn_u),
        .o_btn(o_btn_up)
    );
    btn_debounce U_BD_DOWN (
        .clk  (clk),
        .reset(rst),
        .i_btn(i_btn_d),
        .o_btn(o_btn_down)
    );
    btn_debounce U_BD_RIGHT (
        .clk  (clk),
        .reset(rst),
        .i_btn(i_btn_r),
        .o_btn(o_btn_right)
    );
    btn_debounce U_BD_LEFT (
        .clk  (clk),
        .reset(rst),
        .i_btn(i_btn_l),
        .o_btn(o_btn_left)
    );

    // uart control to stopwatch_watch
    signal_select_unit U_SIGNAL_SEL (
        .control(w_control),
        .btn_in_up(o_btn_up),
        .btn_in_down(o_btn_down),
        .btn_in_right(o_btn_right),
        .btn_in_left(o_btn_left),
        .i_sw(i_sw),
        .btn_out_up(o_btn_u),
        .btn_out_down(o_btn_d),
        .btn_out_right(o_btn_r),
        .btn_out_left(o_btn_l),
        .btn_send(send),
        .o_sw(o_sw)
    );

    ASCII_decoder U_ASCII_DECODER (
        .in_data(w_rx_fifo_data),
        .done(!w_rx_fifo_empty),
        .control(w_control)
    );

    fifo #(
        .DEPTH(4),
        .BIT_WIDTH(8)
    ) fifo_rx (
        .clk(clk),
        .rst(rst),
        .push(w_rx_done && !w_rx_fifo_full),
        .pop(!w_rx_fifo_empty),
        .push_data(w_rx_data),
        .pop_data(w_rx_fifo_data),
        .full(w_rx_fifo_full),
        .empty(w_rx_fifo_empty)
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

    ASCII_sender U_ASCII_SENDER (
        .clk(clk),
        .rst(rst),
        .module_sel(3'b001),     // 0: watch, 1: SR04, 2: DHT11
        .data_in(sender_data),
        .send_start(send),
        .fifo_full(w_tx_fifo_full),
        .fifo_push(w_tx_fifo_push),
        .data_out(w_sender_data_out)
    );

    fifo #(
        .DEPTH(16),
        .BIT_WIDTH(8)
    ) fifo_tx (
        .clk(clk),
        .rst(rst),
        .push(w_tx_fifo_push),
        .pop(!w_tx_busy && !w_tx_fifo_empty),
        .push_data(w_sender_data_out),
        .pop_data(w_tx_fifo_data),
        .full(w_tx_fifo_full),
        .empty(w_tx_fifo_empty)
    );

    // uart tx
    uart_tx U_UART_TX (
        .clk(clk),
        .rst(rst),
        .tx_start(!w_tx_fifo_empty),
        .b_tick(w_b_tick),
        .tx_data(w_tx_fifo_data),
        .tx_busy(w_tx_busy),
        .tx_done(w_tx_done),
        .uart_tx(uart_tx)
    );

    // 9600 x 16 baud tick
    baud_tick U_BAUD_TICK (
        .clk(clk),
        .reset(rst),
        .b_tick(w_b_tick)
    );

endmodule


module signal_select_unit (
    input      [3:0] control,
    input            btn_in_up,
    input            btn_in_down,
    input            btn_in_right,
    input            btn_in_left,
    input      [3:0] i_sw,
    output reg       btn_out_up,
    output reg       btn_out_down,
    output reg       btn_out_right,
    output reg       btn_out_left,
    output reg       btn_send,
    output     [3:0] o_sw
);

    // swtich
    assign o_sw = i_sw;


    always @(*) begin
        btn_out_up = 1'b0;
        btn_out_down = 1'b0;
        btn_out_right = 1'b0;
        btn_out_left = 1'b0;
        btn_send = 1'b0;
        // button
        btn_out_right = (control == 4'b0001) || btn_in_right;
        btn_out_left  = (control == 4'b0010) || btn_in_left;
        btn_out_up    = (control == 4'b0011) || btn_in_up;
        btn_out_down  = (control == 4'b0100) || btn_in_down;
        // switch
        //if ((control == 4'b0101) | (sw[0] == 1)) sw0 = 1'b1;
        //if ((control == 4'b0110) | (sw[1] == 1)) sw1 = 1'b1;
        //if ((control == 4'b0111) | (sw[2] == 1)) sw2 = 1'b1;
        //if (sw[3] == 1) sw3 = 1'b1;
        //else begin
        //    sw0 = 0;
        //    sw1 = 0;
        //    sw2 = 0;
        //end
        // send
        if (control == 4'b1000) btn_send = 1'b1;
    end

endmodule

module ASCII_sender (
    input             clk,
    input             rst,
    // top module
    input      [ 2:0] module_sel,  // 001: watch, 010: SR04, 100: DHT11
    input      [31:0] data_in,
    input             send_start,  // send start trigger
    // fifo
    input             fifo_full,
    output reg        fifo_push,
    output reg [ 7:0] data_out
);

    // module_sel parameter
    localparam WATCH = 3'b001, SR04 = 3'b010, DHT11 = 3'b100;

    // state
    localparam IDLE = 0, DATA_SELECT = 1, WAIT = 2, SENDING = 3;
    reg [1:0] c_state, n_state;

    // data buffer for output 8-bit * max 13-digit
    reg [7:0] data_buf[0:12];
    integer i;
    // sending data index count
    reg [3:0] last_index;
    reg [3:0] index_cnt_reg, index_cnt_next;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            for (i = 0; i <= 12; i = i + 1) begin
                data_buf[i] <= 8'd0;
            end
            c_state       <= 0;
            index_cnt_reg <= 0;
        end else begin
            c_state       <= n_state;
            index_cnt_reg <= index_cnt_next;
        end
    end

    always @(*) begin
        fifo_push = 0;
        data_out = 0;
        n_state = c_state;
        index_cnt_next = index_cnt_reg;

        case (module_sel)
            WATCH: last_index = 11;
            SR04:  last_index = 5;
            DHT11: last_index = 13;
        endcase

        case (c_state)
            IDLE: begin
                index_cnt_next = 0;

                if (send_start) begin
                    n_state = DATA_SELECT;
                end
            end
            DATA_SELECT: begin
                n_state = WAIT;
            end
            WAIT: begin
                n_state = SENDING;
            end
            SENDING: begin
                if (!fifo_full) begin
                    // send 1 data to fifo_tx
                    fifo_push = 1;
                    data_out = data_buf[index_cnt_reg];
                    index_cnt_next = index_cnt_reg + 1;

                    // check send all digit
                    if (index_cnt_reg == last_index - 1) n_state = IDLE;
                end
            end
        endcase
    end

    // in data update to data_buf
    always @(posedge clk) begin
        if (c_state == DATA_SELECT) begin
            case (module_sel)
                WATCH: begin
                    data_buf[0]  <= {4'b0, data_in[31:28]} + 8'h30;
                    data_buf[1]  <= {4'b0, data_in[27:24]} + 8'h30;
                    data_buf[2]  <= 8'h3a;  // :
                    data_buf[3]  <= {4'b0, data_in[23:20]} + 8'h30;
                    data_buf[4]  <= {4'b0, data_in[19:16]} + 8'h30;
                    data_buf[5]  <= 8'h3a;  // :
                    data_buf[6]  <= {4'b0, data_in[15:12]} + 8'h30;
                    data_buf[7]  <= {4'b0, data_in[11:8]} + 8'h30;
                    data_buf[8]  <= 8'h27;  // `
                    data_buf[9]  <= {4'b0, data_in[7:4]} + 8'h30;
                    data_buf[10] <= {4'b0, data_in[3:0]} + 8'h30;
                end
                SR04: begin
                    data_buf[0] <= {4'b0, data_in[11:8]} + 8'h30;
                    data_buf[1] <= {4'b0, data_in[7:4]} + 8'h30;
                    data_buf[2] <= {4'b0, data_in[3:0]} + 8'h30;
                    data_buf[3] <= 8'h63;  // c
                    data_buf[4] <= 8'h6d;  // m
                end
                DHT11: begin
                    data_buf[0]  <= {4'b0, data_in[31:28]} + 8'h30;
                    data_buf[1]  <= {4'b0, data_in[27:24]} + 8'h30;
                    data_buf[2]  <= 8'h2e;  // .
                    data_buf[3]  <= {4'b0, data_in[23:20]} + 8'h30;
                    data_buf[4]  <= {4'b0, data_in[19:16]} + 8'h30;
                    data_buf[5]  <= 8'h43;  // C
                    data_buf[6]  <= 8'h20;  // space
                    data_buf[7]  <= {4'b0, data_in[15:12]} + 8'h30;
                    data_buf[8]  <= {4'b0, data_in[11:8]} + 8'h30;
                    data_buf[9]  <= 8'h2e;  // .
                    data_buf[10] <= {4'b0, data_in[7:4]} + 8'h30;
                    data_buf[11] <= {4'b0, data_in[3:0]} + 8'h30;
                    data_buf[12] <= 8'h25;  // %
                end
            endcase
        end
    end

endmodule

module ASCII_decoder (
    input      [7:0] in_data,
    input            done,
    output reg [3:0] control
);

    always @(*) begin
        control = 4'b0000;
        if (done) begin
            case (in_data)
                8'b0111_0010: control = 4'b0001;  //r
                8'h6c: control = 4'b0010;  //l
                8'b0111_0101: control = 4'b0011;  //u
                8'b0110_0100: control = 4'b0100;  //d
                8'b0011_0000: control = 4'b0101;  //0
                8'b0011_0001: control = 4'b0110;  //1
                8'b0011_0010: control = 4'b0111;  //2
                8'b0111_0011: control = 4'b1000;  //s
                default: control = 4'b0000;
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
