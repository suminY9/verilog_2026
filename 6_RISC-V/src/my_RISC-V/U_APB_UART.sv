`timescale 1ns / 1ps

module U_APB_UART (
    input               PCLK,
    input               PRESET,
    input        [31:0] PADDR,
    input        [31:0] PWDATA,
    input               PENABLE,
    input               PWRITE,
    input               PSEL,
    output logic [31:0] PRDATA,
    output logic        PREADY,
    input               uart_rx,
    output              uart_tx
);

    // uart_rx, rx_fifo
    logic w_rx_done;
    logic [7:0] w_rx_data, w_rx_fifo_data;
    logic w_rx_fifo_full, w_rx_fifo_empty;
    // ascii_decoder
    logic [3:0] w_control;
    // uart_tx, tx_fifo
    logic w_baud_tick;
    logic w_tx_done, w_tx_busy;
    logic [7:0] w_tx_fifo_data;
    logic w_tx_fifo_push, w_tx_fifo_full, w_tx_fifo_empty;

    localparam [11:0] UART_CTRL_ADDR  = 12'h000;
    localparam [11:0] UART_IDATA_ADDR = 12'h004;
    logic [15:0] UART_IDATA_REG, UART_CTRL_REG;

    assign PREADY = (PENABLE & PSEL) ? 1'b1 : 1'b0;
    assign PRDATA = (PADDR[11:0] == UART_CTRL_ADDR) ? {16'h0000, UART_CTRL_REG} :
                    (PADDR[11:0] == UART_IDATA_ADDR) ? {16'h0000, UART_IDATA_REG} : 32'hxxxx_xxxx;

    always_ff @(posedge PCLK, posedge PRESET) begin
        if (PRESET) begin
            UART_CTRL_REG <= 16'h0000;
        end else if (PREADY & PWRITE) begin
            case(PADDR[11:0])
                UART_CTRL_ADDR: UART_CTRL_REG <= PWDATA[15:0];
            endcase
        end
    end

    genvar i;
    generate
        for (i = 0; i < 16; i++) begin
            assign UART_IDATA_REG[i] = (i == w_control) ? 1'b1 : 1'b0;            
        end
    endgenerate

    ASCII_decoder U_ASCII_DECODER (
        .in_data(w_rx_fifo_data),
        .done(!w_rx_fifo_empty),
        .control(w_control)
    );
    fifo #(
        .DEPTH(4),
        .BIT_WIDTH(8)
    ) fifo_rx (
        .clk(PCLK),
        .rst(PRESET),
        .push(w_rx_done && !w_rx_fifo_full),
        .pop(!w_rx_fifo_empty & !w_tx_fifo_full),
        .push_data(w_rx_data),
        .pop_data(w_rx_fifo_data),
        .full(w_rx_fifo_full),
        .empty(w_rx_fifo_empty)
    );
    uart_rx U_UART_RX (
        .clk(PCLK),
        .rst(PRESET),
        .rx(uart_rx),
        .b_tick(w_baud_tick),
        .rx_data(w_rx_data),
        .rx_done(w_rx_done)
    );
    fifo #(
        .DEPTH(16),
        .BIT_WIDTH(8)
    ) fifo_tx (
        .clk(PCLK),
        .rst(PRESET),
        .push(!w_rx_fifo_empty & !w_tx_fifo_full),
        .pop(!w_tx_busy && !w_tx_fifo_empty),
        .push_data(w_rx_fifo_data),
        .pop_data(w_tx_fifo_data),
        .full(w_tx_fifo_full),
        .empty(w_tx_fifo_empty)
    );
    uart_tx U_UART_TX (
        .clk(PCLK),
        .rst(PRESET),
        .tx_start(!w_tx_fifo_empty),
        .b_tick(w_baud_tick),
        .tx_data(w_tx_fifo_data),
        .tx_busy(w_tx_busy),
        .tx_done(w_tx_done),
        .uart_tx(uart_tx)
    );
    baud_tick #(
        .BAUD_RATE(9600)            // need to make variable
    ) U_BAUD_TICK (
        .clk(PCLK),
        .reset(PRESET),
        .b_tick(w_baud_tick)
    );
endmodule


/********SUB MODULE********/
module ASCII_decoder (
    input        [7:0] in_data,
    input              done,
    output logic [3:0] control
);

    always @(*) begin
        control = 4'b0000;
        if (done) begin
            case (in_data)
                // hexa decimal 0 ~ f
                8'h30: control = 4'h0;
                8'h31: control = 4'h1;
                8'h32: control = 4'h2;
                8'h33: control = 4'h3;
                8'h34: control = 4'h4;
                8'h35: control = 4'h5;
                8'h36: control = 4'h6;
                8'h37: control = 4'h7;
                8'h38: control = 4'h8;
                8'h39: control = 4'h9;
                8'h61: control = 4'ha;
                8'h62: control = 4'hb;
                8'h63: control = 4'hc;
                8'h64: control = 4'hd;
                8'h65: control = 4'he;
                8'h66: control = 4'hf;
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
    logic [1:0] c_state, n_state;
    // x16 tick counter
    logic [4:0] b_tick_cnt_reg, b_tick_cnt_next;
    // uart 8-bit data counter
    logic [2:0] bit_cnt_next, bit_cnt_reg;
    // uart done, rx data
    logic done_reg, done_next;
    logic [7:0] buf_reg, buf_next;

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
    output       tx_busy,
    output       tx_done,
    output       uart_tx
);

    localparam IDLE = 2'd0, START = 2'd1, DATA = 2'd2, STOP = 2'd3;

    //state reg
    logic [1:0] c_state, n_state;
    logic tx_reg, tx_next;
    //BIT_CNT
    logic [2:0] bit_cnt_reg, bit_cnt_next;
    //tick_count
    logic [3:0] b_tick_cnt_reg, b_tick_cnt_next;
    //busy,done
    logic busy_reg, busy_next;
    logic done_reg, done_next;
    //buffer
    logic [7:0] data_in_buf_reg, data_in_buf_next;

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


module baud_tick #(
    parameter BAUD_RATE = 9600
) (
    input        clk,
    input        reset,
    output logic b_tick
);

    parameter BAUDRATE = BAUD_RATE * 16;
    parameter F_COUNT = 100_000_000 / BAUDRATE;

    logic [$clog2(F_COUNT)-1 : 0] count_reg;

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
