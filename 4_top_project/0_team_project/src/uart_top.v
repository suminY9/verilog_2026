`timescale 1ns / 1ps


module top_uart (
    input clk,
    input rst,
    input uart_rx,
    input [15:0] display_data,
    input [15:0] watch_data,
    input time_out,
    input [1:0] sw_3_1,
    output uart_tx,
    output [3:0] cmd_tick,
    output [3:0] cmd_switch
);
    wire w_b_tick, w_rx_done;
    wire [7:0] w_rx_data, w_sender_data;
    wire [7:0] w_rx_fifo_pop_data, w_tx_fifo_pop_data;
    wire w_tx_fifo_full, w_rx_fifo_empty, w_tx_fifo_empty, w_tx_busy;
    wire w_tx_busy_f_detect;
    wire w_decoder_busy;
    wire w_sender_en, w_sender_ready, w_sender_busy;


   

    uart_rx U_UART_RX (
        .clk(clk),
        .rst(rst),
        .rx(uart_rx),
        .b_tick(w_b_tick),
        .rx_data(w_rx_data),
        .rx_done(w_rx_done)
    );

    fifo U_FIFO_RX (
        .clk(clk),
        .rst(rst),
        .push(w_rx_done),
        .pop(~w_decoder_busy),
        .push_data(w_rx_data),
        .pop_data(w_rx_fifo_pop_data),
        .full(),
        .empty(w_rx_fifo_empty)
    );


    ascii_decoder U_ASCII_DECODER (
        .clk(clk),
        .rst(rst),
        .in_data(w_rx_fifo_pop_data),
        .ready(~w_rx_fifo_empty),  // rx_done
        .cmd_tick(cmd_tick),  // R, L, U, D
        .cmd_switch(cmd_switch),
        .busy(w_decoder_busy),
        .sender_en(w_sender_en)
    );

    ascii_sender U_ASCII_SENDER (
        .clk(clk),
        .rst(rst),
        .sender_en(w_sender_en),
        .tx_done(~w_tx_fifo_full),
        .display_data(display_data),
        .watch_data(watch_data),
        .time_out(time_out),
        .sw_3_1(sw_3_1),
        .ascii_code(w_sender_data),
        .sender_ready(w_sender_ready),
        .sender_busy(w_sender_busy)
    );

    fifo U_FIFO_TX (
        .clk(clk),
        .rst(rst),
        .push(w_sender_ready),
        .pop(w_tx_busy_f_detect),
        .push_data(w_sender_data),
        .pop_data(w_tx_fifo_pop_data),
        .full(w_tx_fifo_full),
        .empty(w_tx_fifo_empty)
    );

    uart_tx U_UART_TX (
        .clk(clk),
        .rst(rst),
        .tx_start(~w_tx_fifo_empty),
        .b_tick(w_b_tick),
        .tx_data(w_tx_fifo_pop_data),
        .tx_busy(w_tx_busy),
        // .tx_done(w_tx_done),
        .tx_done(),
        .uart_tx(uart_tx)
    );

    falling_edge_detector U_TX_BUSY_F_DETECT (
        .clk(clk),
        .rst(rst),
        .tx_busy(w_tx_busy),
        .tx_busy_f_detect(w_tx_busy_f_detect)
    );

    baud_tick U_BAUD_TICK (
        .clk(clk),
        .rst(rst),
        .b_tick(w_b_tick)
    );

endmodule

module falling_edge_detector (
    input clk,
    input rst,
    input tx_busy,
    output tx_busy_f_detect
);

    reg busy_reg;

    always @(posedge clk, posedge rst) begin
        if(rst) begin
            busy_reg <= 1'b0;
        end else begin
            busy_reg <= tx_busy;
        end
    end

    assign tx_busy_f_detect = (busy_reg && !tx_busy);

endmodule

module dec_2_ascii (
    input [3:0] dec,
    output reg [7:0] ascii_code
);
    always @(*) begin
         ascii_code = 8'd30;
        case (dec)
            4'd0: ascii_code = 8'h30;
            4'd1: ascii_code = 8'h31;
            4'd2: ascii_code = 8'h32;
            4'd3: ascii_code = 8'h33;
            4'd4: ascii_code = 8'h34;
            4'd5: ascii_code = 8'h35;
            4'd6: ascii_code = 8'h36;
            4'd7: ascii_code = 8'h37;
            4'd8: ascii_code = 8'h38;
            4'd9: ascii_code = 8'h39;
            default : ascii_code = 8'h30;
        endcase
    end
endmodule

module ascii_sender (
    input clk,
    input rst,
    input sender_en,
    input tx_done,
    input [15:0] display_data,
     input [15:0] watch_data,
     input time_out,
    input [1:0] sw_3_1,
    output [7:0] ascii_code,
    output sender_ready,
    output sender_busy
);
    parameter IDLE = 5'd0, PREPARE = 5'd1, DATA0 = 5'd2, DATA1 = 5'd3, DATA2 = 5'd4;
    parameter DATA3 = 5'd5, DATA4 = 5'd6;
    parameter DATA5 = 5'd7, DATA6 = 5'd8;  // cm, . C
    parameter STOP = 5'd9;
    parameter SPACE = 5'd10, EXTRA0 = 5'd11, EXTRA1 = 5'd12, EXTRA2 = 5'd13, EXTRA3 = 5'd14, EXTRA4 = 5'd15;
    parameter TIME_OUT = 5'd16;
    
    reg [4:0] c_state, n_state;
    reg [15:0] watch_data_reg, watch_data_next;
    reg [15:0] time_data_reg, time_data_next;


    wire [7:0] w_ascii_1000, w_ascii_100, w_ascii_10, w_ascii_1;
    wire [7:0] w_watch_1000, w_watch_100, w_watch_10, w_watch_1;

    reg [7:0] ascii_reg, ascii_next;
    reg ready_reg, ready_next;
    reg busy_reg, busy_next;

    reg counter_reg, counter_next;

    reg [1:0] sw_3_1_reg, sw_3_1_next;

    reg [7:0] timeout_ascii[0:6];//, timeout_ascii_next[0:6];
    //integer i = 0;

    reg [2:0] index_reg, index_next;

    assign ascii_code   = ascii_reg;
    assign sender_ready = ready_reg;
    assign sender_busy  = busy_reg;

//     ila_0 U_ila(
//     .clk(clk),    
//     .probe0(w_watch_1),
//     .probe1(w_watch_10),
//     .probe2(w_watch_100),
//     .probe3(w_watch_1000)
// );

    //watch
    dec_2_ascii U_DEC_2_W_1000 (
        .dec(watch_data_reg[15:12]),
        .ascii_code(w_watch_1000)
    );
    dec_2_ascii U_DEC_2_W_100 (
        .dec(watch_data_reg[11:8]),
        .ascii_code(w_watch_100)
    );
    dec_2_ascii U_DEC_2_W_10 (
        .dec(watch_data_reg[7:4]),
        .ascii_code(w_watch_10)
    );
    dec_2_ascii U_DEC_2_W_1 (
        .dec(watch_data_reg[3:0]),
        .ascii_code(w_watch_1)
    );

    //display
    dec_2_ascii U_DEC_2_ASCII_1000 (
        .dec(time_data_reg[15:12]),
        .ascii_code(w_ascii_1000)
    );
    dec_2_ascii U_DEC_2_ASCII_100 (
        .dec(time_data_reg[11:8]),
        .ascii_code(w_ascii_100)
    );
    dec_2_ascii U_DEC_2_ASCII_10 (
        .dec(time_data_reg[7:4]),
        .ascii_code(w_ascii_10)
    );
    dec_2_ascii U_DEC_2_ASCII_1 (
        .dec(time_data_reg[3:0]),
        .ascii_code(w_ascii_1)
    );

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            c_state <= IDLE;
            time_data_reg <= 16'd0;
            watch_data_reg <= 16'd0;
            ascii_reg <= 8'd0;
            ready_reg <= 1'd0;
            busy_reg <= 1'd0;
            counter_reg <= 1'b0;
            sw_3_1_reg <= 1'b0;
            index_reg <= 3'd0;
            //for(i = 0; i < 7; i = i + 1) begin
            //    timeout_ascii[i] <= 8'h0;
            //end
        end else begin
            c_state <= n_state;
            time_data_reg <= time_data_next;
            ascii_reg <= ascii_next;
            ready_reg <= ready_next;
            busy_reg <= busy_next;
            counter_reg <= counter_next;
            watch_data_reg<= watch_data_next;
            sw_3_1_reg <= sw_3_1_next;
            index_reg <= index_next;
            //for(i = 0; i < 7; i = i + 1) begin
            //    timeout_ascii[i] <= timeout_ascii_next[i];
            //end
        end
    end
    
    initial begin
        timeout_ascii[0] = 8'h54;  //ascii 'T'
        timeout_ascii[1] = 8'h49;  //ascii 'I'
        timeout_ascii[2] = 8'h4d;  //ascii 'M'
        timeout_ascii[3] = 8'h45;  //ascii 'E'
        timeout_ascii[4] = 8'h4f;  //ascii 'O'
        timeout_ascii[5] = 8'h55;  //ascii 'U'
        timeout_ascii[6] = 8'h54;  //ascii 'T'
    end

    //always @(*) begin
    //    timeout_ascii_next[0] = 8'h54;  //ascii 'T'
    //    timeout_ascii_next[1] = 8'h49;  //ascii 'I'
    //    timeout_ascii_next[2] = 8'h4d;  //ascii 'M'
    //    timeout_ascii_next[3] = 8'h45;  //ascii 'E'
    //    timeout_ascii_next[4] = 8'h4f;  //ascii 'O'
    //    timeout_ascii_next[5] = 8'h55;  //ascii 'U'
    //    timeout_ascii_next[6] = 8'h54;  //ascii 'T'
    //end
    

    always @(*) begin
        n_state = c_state;
        time_data_next = time_data_reg;
        ascii_next = ascii_reg;
        ready_next = ready_reg;
        busy_next = busy_reg;
        counter_next = counter_reg;
        sw_3_1_next = sw_3_1_reg;
        watch_data_next = watch_data_reg;
        index_next = index_reg;

        // sw_3_1_reg=sw_3_1;
        case (c_state)
            IDLE: begin
                // time_data_next = 0;
                ascii_next = 0;
                ready_next = 1'b0;
                busy_next = 1'b0;
                counter_next = 1'b0;
                if (sender_en) begin
                    n_state = DATA0;
                    time_data_next = display_data;
                    watch_data_next = watch_data;
                    sw_3_1_next = sw_3_1;
                    busy_next = 1'b1;
                    if (sw_3_1[1] == 1'b0) begin
                        n_state = EXTRA0;
                        
                    end
                end else if (time_out) begin
                    n_state   = TIME_OUT;
                    busy_next = 1'b1;
                end
            end
            DATA0: begin
                ready_next   = 1'b0;
                ascii_next   = w_watch_1000;
                counter_next = counter_reg + 1;
                if (counter_reg == 1) begin
                    if (tx_done) begin
                        n_state = DATA1;
                        ready_next = 1'b1;  // send data0
                        counter_next = 1'b0;
                    end
                end
            end
            DATA1: begin
                ready_next   = 1'b0;
                ascii_next   = w_watch_100;
                counter_next = counter_reg + 1;
                if (counter_reg == 1) begin
                    if (tx_done) begin
                        ready_next   = 1'b1;
                        counter_next = 1'b0;
                        // if (sw_3_1_reg == 2'b10) begin
                        //     // sr04
                            n_state = DATA2;
                        // end else begin
                            // n_state = DATA2;
                        end
                    end

                end
            
            DATA2: begin
                ready_next = 1'b0;
                // if (sw_3_1_reg[1]) begin
                //     ascii_next = 8'h2e;  // ascii (.)
                // end else begin
                    ascii_next = 8'h3a;  // ascii (:)
                // end
                counter_next = counter_reg + 1;
                if (counter_reg == 1) begin
                    if (tx_done) begin
                        n_state = DATA3;
                        ready_next = 1'b1;
                        counter_next = 1'b0;
                    end
                end
            end
            DATA3: begin
                ready_next   = 1'b0;
                ascii_next   = w_watch_10;
                counter_next = counter_reg + 1;
                if (counter_reg == 1) begin
                    if (tx_done) begin
                        n_state = DATA4;
                        ready_next = 1'b1;
                        counter_next = 1'b0;
                    end
                end
            end
            
            DATA4: begin
                ready_next   = 1'b0;
                ascii_next   = w_watch_1;
                counter_next = counter_reg + 1;
                if (counter_reg == 1) begin
                    if (tx_done) begin
                        ready_next   = 1'b1;
                        counter_next = 1'b0;
                        // sr04
                    //      if (sw_3_1_reg == 2'b10) begin
                    //         n_state = STOP;
                    //      end //else begin
                            n_state = SPACE;
                        //end
                     end
                    end
                end
            // end
            SPACE: begin
                ascii_next = 8'h20; // Space (0x20)
                counter_next = counter_reg + 1;
                if (counter_reg == 1 && tx_done) begin
                    n_state = EXTRA0; // 디스플레이 값 출력으로 이동
                    ready_next = 1'b1;
                    counter_next = 1'b0;
                end
            end
            EXTRA0: begin
                ready_next = 1'b0;
                ascii_next = w_ascii_1000;
                counter_next = counter_reg + 1;
                if (counter_reg == 1 && tx_done) begin
                    n_state = EXTRA1;
                    ready_next = 1'b1;
                    counter_next = 1'b0;
                end
            end
            EXTRA1: begin 
                ready_next = 1'b0;
                ascii_next = w_ascii_100;
                counter_next = counter_reg + 1;
                if (tx_done && counter_reg == 1) begin
                    n_state = EXTRA2; 
                    ready_next = 1'b1; 
                    counter_next = 1'b0;
                    // sr04
                    if (sw_3_1_reg==2'b10) begin
                        n_state=EXTRA3;
                    end
                end  
            end
            EXTRA2 : begin
                ready_next = 1'b0;
                //sensor mode '.' , watch mode ':'
                ascii_next = (sw_3_1_reg[1]) ? 8'h2e : 8'h3a;
                counter_next = counter_reg + 1;
                if (counter_reg == 1 && tx_done) begin
                    n_state = EXTRA3;
                    ready_next = 1'b1;
                    counter_next = 1'b0;
                end
            end
            EXTRA3: begin
                ready_next = 1'b0;
                ascii_next = w_ascii_10;
                counter_next = counter_reg + 1;
                if (counter_reg == 1 && tx_done) begin
                    n_state = EXTRA4;
                    ready_next = 1'b1;
                    counter_next = 1'b0;
                end
            end
            EXTRA4: begin
                ready_next = 1'b0;
                ascii_next = w_ascii_1;
                counter_next = counter_reg + 1;
                if (counter_reg == 1 && tx_done) begin
                    ready_next = 1'b1;
                    counter_next = 1'b0;
                    // 초음파 센서 모드일 때만 cm 단위를 붙임
                    if (sw_3_1_reg == 2'b10) n_state = DATA5; 
                    else n_state = STOP;
                end
            end
            DATA5: begin
                ready_next   = 1'b0;
                ascii_next   = 8'h63;  // ascii 'c'
                counter_next = counter_reg + 1;
                if (counter_reg == 1) begin
                    if (tx_done) begin
                        ready_next = 1'b1;
                        counter_next = 1'b0;
                        n_state = DATA6;
                    end
                end
            end
            DATA6: begin
                ready_next   = 1'b0;
                ascii_next   = 8'h6d;  // ascii 'm'
                counter_next = counter_reg + 1;
                if (counter_reg == 1) begin
                    if (tx_done) begin
                        ready_next = 1'b1;
                        counter_next = 1'b0;
                        n_state = STOP;
                    end
                end
            end

            TIME_OUT: begin
                ready_next   = 1'b0;
                ascii_next   = timeout_ascii[index_reg];

                counter_next = counter_reg + 1;
                if (counter_reg == 1) begin
                    if (tx_done) begin
                        n_state = TIME_OUT;
                        ready_next = 1'b1;  // send data
                        counter_next = 1'b0;
                        index_next = index_reg + 1'b1;
                        if (index_reg == 3'd6) begin
                            n_state = STOP;
                            index_next = 3'd0;
                        end
                    end
                end
            end


            STOP: begin
                ready_next   = 1'b0;
                counter_next = counter_reg + 1;
                if (counter_reg == 1) begin
                    if (tx_done) begin
                        n_state   = IDLE;
                        // time_data_next = 0;
                        busy_next = 1'b0;
                    end
                end
            end
        endcase
    end

endmodule

module ascii_decoder (
    input clk,
    input rst,
    input [7:0] in_data,
    input ready,  // rx_done
    output [3:0] cmd_tick,  // r, l, u, d
    output [3:0] cmd_switch,
    output busy,  // ADD BUSY PIN !!! 02.12
    output sender_en
);
    parameter IDLE=4'd0, START=4'd1, BTN_R = 4'd2, BTN_L = 4'd3, BTN_U = 4'd4, BTN_D = 4'd5;
    parameter SW_0 = 4'd6, SW_1 = 4'd7, SW_2 = 4'd8, SW_3 = 4'd9, STATE = 4'd10;  //, SR04 = 4'd10;
    reg [3:0] c_state, n_state;

    reg [7:0] data_r;
    reg [3:0] tick_reg, tick_next;
    reg [3:0] switch_reg, switch_next;
    reg busy_reg, busy_next;
    reg sender_reg, sender_next;

    assign cmd_tick = tick_reg;
    assign cmd_switch = switch_reg;
    assign busy = busy_reg;
    assign sender_en = sender_reg;

    // state register SL
    always @(posedge clk, posedge rst) begin
        if (rst) begin
            c_state <= IDLE;
            tick_reg <= 4'd0;
            switch_reg <= 3'd0;
            busy_reg <= 1'b0;
            sender_reg <= 1'b0;
            data_r <= 8'd0;
        end else begin
            c_state <= n_state;
            tick_reg <= tick_next;
            switch_reg <= switch_next;
            busy_reg <= busy_next;
            sender_reg <= sender_next;
            if (ready) begin
                data_r <= in_data;
            end else begin
                data_r <= data_r;
            end
        end
    end

    // next state + output CL
    always @(*) begin
        n_state = c_state;
        tick_next = tick_reg;
        switch_next = switch_reg;
        busy_next = busy_reg;
        sender_next = sender_reg;
        case (c_state)
            IDLE: begin
                tick_next = 4'd0;
                busy_next = 1'b0;
                if (ready) begin
                    n_state   = START;
                    busy_next = 1'b1;
                end else n_state = c_state;
            end
            START: begin  // decoding
                case (data_r)
                    8'h72: begin  // r
                        n_state = BTN_R;
                        tick_next[0] = 1'b1;
                    end
                    8'h6c: begin  // l
                        n_state = BTN_L;
                        tick_next[1] = 1'b1;
                    end
                    8'h75: begin  // u
                        n_state = BTN_U;
                        tick_next[2] = 1'b1;
                    end
                    8'h64: begin  // d
                        n_state = BTN_D;
                        tick_next[3] = 1'b1;
                    end
                    8'h30: begin  // 0
                        n_state = SW_0;
                        switch_next[0] = ~switch_next[0];
                    end
                    8'h31: begin  // 1
                        n_state = SW_1;
                        switch_next[1] = ~switch_next[1];
                    end
                    8'h32: begin  // 2
                        n_state = SW_2;
                        switch_next[2] = ~switch_next[2];
                    end
                    8'h33: begin
                        n_state=SW_3;
                        switch_next[3] = ~switch_next[3];
                    end
                    8'h73: begin  // s
                        n_state = STATE;
                        sender_next = 1'b1;
                    end
                endcase
            end
            BTN_R: begin
                n_state   = IDLE;
                tick_next = 5'd0;
                busy_next = 1'b0;
            end
            BTN_L: begin
                n_state   = IDLE;
                tick_next = 5'd0;
                busy_next = 1'b0;
            end
            BTN_U: begin
                n_state   = IDLE;
                tick_next = 5'd0;
                busy_next = 1'b0;
            end
            BTN_D: begin
                n_state   = IDLE;
                tick_next = 5'd0;
                busy_next = 1'b0;
            end
            SW_0: begin
                n_state   = IDLE;
                busy_next = 1'b0;
            end
            SW_1: begin
                n_state   = IDLE;
                busy_next = 1'b0;
            end
            SW_2: begin
                n_state   = IDLE;
                busy_next = 1'b0;
            end
            SW_3: begin
                n_state   = IDLE;
                busy_next = 1'b0;
            end
            STATE: begin
                n_state = IDLE;
                busy_next = 1'b0;
                sender_next = 1'b0;
            end
            // STATE_T: begin
            //     n_state = IDLE;
            //     busy_next = 1'b0;
            //     send_time = 1'b1;
            // end
        endcase
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

    localparam IDLE = 2'd0, START = 2'd1;
    localparam DATA = 2'd2, STOP = 2'd3;

    reg [1:0] c_state, n_state;
    reg [4:0] b_tick_cnt_reg, b_tick_cnt_next;
    reg [3:0] bit_cnt_next, bit_cnt_reg;
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

    //next, output
    always @(*) begin
        n_state         = c_state;
        b_tick_cnt_next = b_tick_cnt_reg;
        bit_cnt_next    = bit_cnt_reg;
        done_next       = done_reg;
        buf_next        = buf_reg;

        case (c_state)
            IDLE: begin
                done_next       = 3'd0;
                bit_cnt_next    = 3'd0;
                b_tick_cnt_next = 5'd0;
                done_next       = 1'b0;
                buf_next        = 8'd0;
                if (b_tick & !rx) begin
                    n_state = START;
                end
            end
            START: begin
                if (b_tick)
                    if (b_tick & (b_tick_cnt_reg == 7)) begin
                        b_tick_cnt_next = 0;
                        n_state = DATA;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
            end
            DATA: begin
                if (b_tick) begin
                    if (b_tick_cnt_reg == 15) begin
                        b_tick_cnt_next = 0;
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
                if (b_tick)
                    if (b_tick_cnt_reg == 15) begin
                        n_state   = IDLE;
                        done_next = 1'b1;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
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
    output       uart_tx,
    output       tx_busy,
    output       tx_done
);

    localparam IDLE = 2'd0, START = 2'd1;
    localparam DATA = 2'd2, STOP = 2'd3;


    // state reg
    reg [1:0] c_state, n_state;
    reg tx_reg, tx_next;  //output SL
    //bit_cont
    reg [2:0] bit_cnt_reg, bit_cnt_next;

    //busy, done
    reg done_reg, done_next;
    reg busy_reg, busy_next;
    //b_tick_count
    reg [3:0] b_tick_cnt_reg, b_tick_cnt_next;

    //data_in_buf
    reg [7:0] data_in_buf_reg, data_in_buf_next;

    assign uart_tx = tx_reg;
    assign tx_busy = busy_reg;
    assign tx_done = done_reg;

    // state regiset SL
    always @(posedge clk, posedge rst) begin
        if (rst) begin
            c_state         <= IDLE;
            tx_reg          <= 1'b1;
            bit_cnt_reg     <= 1'b0;
            b_tick_cnt_reg  <= 4'h0;
            busy_reg        <= 1'b0;
            done_reg        <= 1'b0;
            data_in_buf_reg <= 8'h00;
        end else begin
            c_state         <= n_state;
            tx_reg          <= tx_next;
            bit_cnt_reg     <= bit_cnt_next;
            b_tick_cnt_reg  <= b_tick_cnt_next;
            done_reg        <= done_next;
            busy_reg        <= busy_next;
            data_in_buf_reg <= data_in_buf_next;
        end
    end

    // next CL
    always @(*) begin
        n_state          = c_state;  // to prevent Latch
        tx_next          = tx_reg;
        bit_cnt_next     = bit_cnt_reg;
        b_tick_cnt_next  = b_tick_cnt_reg;
        busy_next        = busy_reg;
        done_next        = done_reg;
        data_in_buf_next = data_in_buf_reg;
        case (c_state)

            IDLE: begin
                tx_next         = 1'b1;
                bit_cnt_next    = 1'b0;
                b_tick_cnt_next = 4'h0;
                busy_next       = 1'b0;
                done_next       = 1'b0;
                if (tx_start) begin
                    n_state = START;
                    busy_next = 1'b1;
                    data_in_buf_next = tx_data;
                end
            end

            START: begin
                //to start uart fram start bit
                tx_next = 1'b0;
                // data_in_buf_next = tx_data;
                if (b_tick) begin
                    if (b_tick_cnt_reg == 15) begin
                        n_state = DATA;
                        b_tick_cnt_next = 4'h0;
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
                if (b_tick) begin
                    if (b_tick_cnt_reg == 15) begin
                        done_next = 1'b1;
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
    input rst,
    output reg b_tick

);
    parameter BAUDRATE = 9600 * 16;
    parameter F_count = 100_000_000 / BAUDRATE;
    //reg for counter
    reg [$clog2(F_count)-1:0] counter_reg;
    always @(posedge clk, posedge rst) begin
        if (rst) begin
            counter_reg <= 0;
            b_tick <= 1'b0;

        end else begin
            counter_reg <= counter_reg + 1;
            if (counter_reg == (F_count - 1)) begin
                counter_reg <= 0;
                b_tick <= 1'b1;
            end else begin
                b_tick <= 1'b0;
            end
        end
    end
endmodule
