`timescale 1ns / 1ps

module uart_top (
    input        clk,
    input        rst,
    input  [3:0] sw,
    input        btn_u,
    input        btn_d,
    input        btn_r,
    input        btn_l,
    input        uart_rx,
    output       uart_tx,
    output [3:0] fnd_digit,
    output [7:0] fnd_data,
    output [3:0] LED
);

    // button
    wire o_btn_up, o_btn_down, o_btn_right, o_btn_left;
    // to top_stopwatch_watch
    wire [3:0] w_control;
    wire w_btn_in_u, w_btn_in_d, w_btn_in_r, w_btn_in_l, w_btn_in_state;
    wire w_sw0, w_sw1, w_sw2, w_sw3;
    // uart_rx
    wire w_rx_done;
    wire [7:0] w_rx_data;
    // uart_tx
    wire w_b_tick;

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

    // uart control to stopwatch_watch
    signal_select_unit U_SIGNAL_SEL (
        .control(w_control),
        .btn_in_up(o_btn_up),
        .btn_in_down(o_btn_down),
        .btn_in_right(o_btn_right),
        .btn_in_left(o_btn_left),
        .sw(sw),
        .btn_out_up(w_btn_in_u),
        .btn_out_down(w_btn_in_d),
        .btn_out_right(w_btn_in_r),
        .btn_out_left(w_btn_in_l),
        .btn_state(w_btn_state),
        .sw0(w_sw0),
        .sw1(w_sw1),
        .sw2(w_sw2),
        .sw3(w_sw3)
    );

    // top_stopwatch_watch
    top_stopwatch_watch U_TOP_STOPWATCH_WATCH (
        .clk(clk),
        .reset(rst),
        .sw({w_sw3, w_sw2, w_sw1, w_sw0}),
        .btn_u(w_btn_in_u),
        .btn_d(w_btn_in_d),
        .btn_r(w_btn_in_r),
        .btn_l(w_btn_in_l),
        .fnd_digit(fnd_digit),
        .fnd_data(fnd_data),
        .LED(LED)
    );

    ASCII_decoder U_ASCII_DECODER (
        .in_data(w_rx_data),
        .done(w_rx_done),
        .control(w_control)
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
        .tx_start(w_rx_done),
        .b_tick(w_b_tick),
        .tx_data(w_rx_data),
        .tx_busy(),
        .tx_done(),
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
    input      [3:0] control,
    input            btn_in_up,
    input            btn_in_down,
    input            btn_in_right,
    input            btn_in_left,
    input      [3:0] sw,
    output reg       btn_out_up,
    output reg       btn_out_down,
    output reg       btn_out_right,
    output reg       btn_out_left,
    output reg       btn_state,
    output           sw0,
    output           sw1,
    output           sw2,
    output           sw3
);

    // swtich
    assign sw0 = sw[0];
    assign sw1 = sw[1];
    assign sw2 = sw[2];
    assign sw3 = sw[3];


    always @(*) begin
        btn_out_up = 1'b0;
        btn_out_down = 1'b0;
        btn_out_right = 1'b0;
        btn_out_left = 1'b0;
        btn_state = 1'b0;
        // button
        if ((control == 4'b0001) | (btn_in_right)) btn_out_right = 1'b1;
        else if ((control == 4'b0010) | (btn_in_left)) btn_out_left = 1'b1;
        else if ((control == 4'b0011) | (btn_in_up)) btn_out_up = 1'b1;
        else if ((control == 4'b0100) | (btn_in_down)) btn_out_down = 1'b1;
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
        // state
        if (control == 4'b1000) btn_state = 1'b1;
    end

endmodule

module ASCII_sender (
    input            clk,
    input            rst,
    input      [1:0] fnd_sel,     // 0: watch, 1: SR04, 2: DHT11
    input      [7:0] fnd_data,    // data input 8-bit
    input            fnd_collect, // 1(tick): collecting fnd_data
    input            send_start,  // uart_tx start signal
    input            tx_done,
    output reg       tx_start,
    output reg [7:0] tx_data
);

    // fnd_sel parameter
    localparam WATCH = 0,
               SR04  = 1,
               DHT11 = 2;

    // state
    localparam IDLE       = 0,
               FND_SELECT = 1,
               START      = 2,
               SENDING    = 3,
               WAIT       = 4;
    reg [2:0]  c_state, n_state;

    // data buffer
    reg [63:0] data_buf;
    // fnd data collecting
    reg [2:0] collect_cnt;
    // fnd 자릿수 0~7 count
    reg [3:0] tx_send_cnt_reg, tx_send_cnt_next;

    always @(posedge clk, posedge rst) begin
        if(rst) begin
            c_state         <= 0;
            data_buf        <= 0;
            collect_cnt     <= 0;
            tx_send_cnt_reg <= 0;
        end else begin
            c_state         <= n_state;
            tx_send_cnt_reg <= tx_send_cnt_next;

            // fnd 8자리 or 4자리 collect
            // current state == IDLE 일 때에만 fnd collect
            if(c_state == IDLE) begin
                case(fnd_sel)
                    WATCH: begin
                        if(fnd_collect && collect_cnt < 8) begin
                            data_buf    <= {data_buf[55:0], fnd_data};
                            collect_cnt <= collect_cnt + 1;
                        end else begin
                            collect_cnt <= 0;
                        end
                    end
                    SR04: begin
                        if(fnd_collect && collect_cnt < 4) begin
                            data_buf    <= {data_buf[55:0], fnd_data};
                            collect_cnt <= collect_cnt + 1;
                        end else begin
                            collect_cnt <= 0;
                        end
                    end
                    DHT11: begin
                        if(fnd_collect && collect_cnt < 4) begin
                            data_buf    <= {data_buf[55:0], fnd_data};
                            collect_cnt <= collect_cnt + 1;
                        end else begin
                            collect_cnt <= 0;
                        end
                    end
                endcase
            end
        end
    end

    always @(*) begin
        n_state  = c_state;
        tx_start = 0;
        tx_data  = 8'd0;
        tx_send_cnt_next = tx_send_cnt_reg;

        case(c_state)
            // IDLE
            // data_buf에 fnd collecting. send_start 신호가 들어오면 FND_SELECT로
            IDLE: begin
                if(send_start) begin
                    n_state = FND_SELECT;
                end
            end

            // FND_SELECT
            // uart_tx로 전송할 데이터(tx_data, 8-bit) 결정. ASCII 숫자로 변환.
            FND_SELECT: begin
                case(fnd_sel)
                    WATCH: begin
                        case(tx_send_cnt_reg)
                            0: tx_data = data_buf[63:56];
                            1: tx_data = data_buf[55:48];
                            2: tx_data = data_buf[47:40];
                            3: tx_data = data_buf[39:32];
                            4: tx_data = data_buf[31:24];
                            5: tx_data = data_buf[23:16];
                            6: tx_data = data_buf[15: 8];
                            7: tx_data = data_buf[ 7: 0];
                            default: tx_data = 0;
                        endcase
                    end
                    SR04: begin
                        case(tx_send_cnt_reg)
                            0: tx_data = data_buf[63:56];
                            1: tx_data = data_buf[55:48];
                            2: tx_data = data_buf[47:40];
                            3: tx_data = data_buf[39:32];
                            default: tx_data = 0;
                        endcase
                    end
                    DHT11: begin
                        case(tx_send_cnt_reg)
                            0: tx_data = data_buf[63:56];
                            1: tx_data = data_buf[55:48];
                            2: tx_data = data_buf[47:40];
                            3: tx_data = data_buf[39:32];
                            default: tx_data = 0;
                        endcase
                    end
                    //default:
                endcase

                // 0~9 숫자 인풋, ASCII 문자로 변환
                tx_data = tx_data + 8'h30;
                
                n_state = START;
            end

            // START
            // tx_start 신호를 내보냄
            START: begin
                // uart_tx <- 전송 가능 상태로 전환
                tx_start = 1;
                n_state = SENDING;
            end

            // SENDING
            // uart_tx가 done 신호를 보내면 WAIT로
            SENDING: begin
                if(tx_done) begin // uart_tx <- 전송 done check
                    n_state = WAIT;
                end
            end

            // WAIT
            // fnd 8 or 4자리 수 모두 전송했는지 확인.
            // 전송 다 끝남 -> IDLE로 / 안 끝남 -> FND_SELECT로
            WAIT: begin
                case(fnd_sel)
                    WATCH: begin
                        if(tx_send_cnt_reg == 7) begin
                            n_state = IDLE;
                        end else begin
                            n_state = FND_SELECT;
                        end
                    end
                    SR04: begin
                        if(tx_send_cnt_reg == 4) begin
                            n_state = IDLE;
                        end else begin
                            n_state = FND_SELECT;
                        end
                    end
                    DHT11: begin
                        if(tx_send_cnt_reg == 4) begin
                            n_state = IDLE;
                        end else begin
                            n_state = FND_SELECT;
                        end
                    end
                    //default:
                endcase
                
                tx_send_cnt_next = tx_send_cnt_reg + 1;
            end
            default: n_state = IDLE;
        endcase
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
