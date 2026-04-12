module uart (
    input  logic clk,
    input  logic rst,
    input  logic uart_rx,
    output logic uart_tx
);

    // baud tick
    logic b_tick;
    // rx
    logic rx_done;
    logic [7:0] rx_data;
    // tx
    logic tx_done, tx_busy;
 
    uart_rx U_RX(
        .clk(clk),
        .rst(rst),
        .rx(uart_rx),
        .b_tick(b_tick),
        .rx_data(rx_data),
        .rx_done(rx_done)
    );
    uart_tx U_TX(
        .clk(clk),
        .rst(rst),
        .tx_start(rx_done),
        .b_tick(b_tick),
        .tx_data(rx_data),
        .tx_busy(tx_busy),
        .tx_done(tx_done),
        .uart_tx(uart_tx)
    );
    baud_tick U_BTICK(
        .clk(clk),
        .reset(rst),
        .b_tick(b_tick)
    );
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
    localparam IDLE = 0, START = 1, DATA = 2, STOP = 3;
    logic [1:0] c_state, n_state;
    // x16 tick counter
    logic [4:0] b_tick_cnt_reg, b_tick_cnt_next;
    // uart 8-bit data counter
    logic [2:0] bit_cnt_next, bit_cnt_reg;
    // uart signal
    logic done_reg, done_next;
    logic [7:0] buf_reg, buf_next;
    logic rx_reg;

    assign rx_data = buf_reg;
    assign rx_done = done_reg;

    // state register
    always_ff @(posedge clk, posedge rst) begin
        if(rst) begin
            c_state         <= 2'd0;
            b_tick_cnt_reg  <= 5'd0;
            bit_cnt_reg     <= 3'd0;
            done_reg        <= 1'b0;
            buf_reg         <= 8'b0;
            rx_reg          <= 1'b1;
        end else begin
            c_state         <= n_state;
            b_tick_cnt_reg  <= b_tick_cnt_next;
            bit_cnt_reg     <= bit_cnt_next;
            done_reg        <= done_next;
            buf_reg         <= buf_next;
            rx_reg          <= rx;
        end
    end

    // next, output
    always_comb begin
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
                if(b_tick & !rx_reg) begin
                    buf_next = 8'd0;
                    n_state  = START;
                end
            end
            START: begin
                if(b_tick) begin
                    if(b_tick_cnt_reg == 7) begin
                        b_tick_cnt_next = 5'd0;
                        n_state = DATA;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end
            DATA: begin
                if(b_tick) begin
                    if(b_tick_cnt_reg == 4'd15) begin
                        b_tick_cnt_next = 4'd0;
                        buf_next = {rx_reg, buf_reg[7:1]};
                        if(bit_cnt_reg == 7) begin
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
                if(b_tick) begin
                    if(b_tick_cnt_reg == 15) begin
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


module uart_tx(
    input        clk,
    input        rst,
    input        tx_start,
    input        b_tick,
    input  [7:0] tx_data,
    output       tx_busy,
    output       tx_done,
    output       uart_tx
);

    // FSM state
    localparam IDLE = 0, START = 1, DATA = 2, STOP = 3;
    logic [1:0] c_state, n_state;
    // uart 8-bit count reg
    logic [2:0] bit_cnt_reg, bit_cnt_next;
    // baud tick counter
    logic [3:0] b_tick_cnt_reg, b_tick_cnt_next;
    // data buffer
    logic [7:0] data_in_buf_reg, data_in_buf_next;
    // tx signal
    logic tx_reg, tx_next;
    logic busy_reg, busy_next;
    logic done_reg, done_next;
    
    assign tx_busy = busy_reg;
    assign tx_done = done_reg;
    assign uart_tx = tx_reg;

    always_ff @(posedge clk, posedge rst) begin
        if(rst) begin
            c_state         <= IDLE;
            tx_reg          <= 1'b1;
            bit_cnt_reg     <= 1'b0;
            busy_reg        <= 0;
            done_reg        <= 0;
            data_in_buf_reg <= 0;
            b_tick_cnt_reg  <= 0;
        end else begin
            c_state         <= n_state;
            tx_reg          <= tx_next;
            bit_cnt_reg     <= bit_cnt_next;
            busy_reg        <= busy_next;
            done_reg        <= done_next;
            data_in_buf_reg <= data_in_buf_next;
            b_tick_cnt_reg  <= b_tick_cnt_next;
        end
    end

    always_comb begin
        n_state          = c_state;
        tx_next          = tx_reg;
        bit_cnt_next     = bit_cnt_reg;
        b_tick_cnt_next  = b_tick_cnt_reg;
        busy_next        = busy_reg;
        done_next        = done_reg;
        data_in_buf_next = data_in_buf_reg;

        case(c_state)
            IDLE: begin
                tx_next = 1'b1;
                bit_cnt_next = 0;
                b_tick_cnt_next = 4'd0;
                busy_next = 0;
                done_next = 0;
                if(tx_start) begin
                    n_state = START;
                    busy_next = 1'b1;
                    data_in_buf_next = tx_data;
                end
            end
            START: begin
                tx_next = 1'b0;
                if(b_tick) begin
                    if(b_tick_cnt_reg == 15) begin
                        n_state = DATA;
                        b_tick_cnt_next = 0;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end
            DATA: begin
                tx_next = data_in_buf_reg[0];
                if(b_tick) begin
                    if(b_tick_cnt_reg == 15) begin
                        b_tick_cnt_next = 4'd0;
                        if(bit_cnt_reg == 7) begin
                            n_state = STOP;
                        end else begin
                            b_tick_cnt_next = 4'd0;
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
                if(b_tick) begin
                    if(b_tick_cnt_reg == 15) begin
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

module baud_tick(
    input  logic clk,
    input  logic reset,
    output logic b_tick
);

    parameter BAUDRATE = 9600 * 16;
    parameter F_COUNT = 100_000_000 / BAUDRATE;

    logic [$clog2(F_COUNT)-1:0] count_reg;

    always_ff @(posedge clk, posedge reset) begin
        if(reset) begin
            count_reg <= 0;
            b_tick    <= 1'b0;
        end else begin
            if(count_reg == (F_COUNT - 1)) begin
                b_tick <= 1;
                count_reg <= 0;
            end else begin
                count_reg<= count_reg + 1;
                b_tick <= 0;
            end
        end
    end
endmodule