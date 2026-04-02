`timescale 1ns / 1ps

module APB_UART (
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
    localparam [11:0] UART_CTL_ADDR    = 12'h000;
    localparam [11:0] UART_BAUD_ADDR   = 12'h004;
    localparam [11:0] UART_STATUS_ADDR = 12'h008;
    localparam [11:0] UART_TXDATA_ADDR = 12'h00C;
    localparam [11:0] UART_RXDATA_ADDR = 12'h010;

    logic [7:0] CTL_REG, BAUD_REG, TX_DATA_REG, STATUS_REG, RX_DATA_REG;
    logic w_b_tick, w_tx_busy, w_tx_done, w_rx_done;
    logic [7:0] w_rx_data;
    logic tx_start_pulse, ctl_prev;

    // =========================================================================
    // ★ Sticky Flag 로직: CPU가 데이터를 읽을 때까지 완료 신호를 붙잡음 (Hardware 필수)
    // =========================================================================
    logic rx_done_sticky;
    always_ff @(posedge PCLK, posedge PRESET) begin
        if (PRESET) begin
            rx_done_sticky <= 1'b0;
        end else begin
            if (w_rx_done) begin
                // UART RX로부터 1클럭 펄스가 오면 '1'로 박제 (Set)
                rx_done_sticky <= 1'b1;
            end 
            else if (PREADY & ~PWRITE & PSEL & (PADDR[11:0] == UART_RXDATA_ADDR)) begin
                // CPU가 실제로 RX DATA를 읽어가는 순간 '0'으로 초기화 (Clear)
                rx_done_sticky <= 1'b0;
            end
        end
    end

    // STATUS_REG의 7번 비트에 sticky 플래그 연결
    assign STATUS_REG = {rx_done_sticky, 6'b0, w_tx_busy};

    assign PREADY = (PENABLE & PSEL) ? 1'b1 : 1'b0;
    assign PRDATA = (PADDR[11:0]==UART_CTL_ADDR)    ? {24'h0, CTL_REG}    :
                    (PADDR[11:0]==UART_BAUD_ADDR)   ? {24'h0, BAUD_REG}   :
                    (PADDR[11:0]==UART_STATUS_ADDR) ? {24'h0, STATUS_REG} :
                    (PADDR[11:0]==UART_TXDATA_ADDR) ? {24'h0, TX_DATA_REG}:
                    (PADDR[11:0]==UART_RXDATA_ADDR) ? {24'h0, RX_DATA_REG}: 32'hxxxx_xxxx;

    always_ff @(posedge PCLK, posedge PRESET) begin
        if (PRESET) RX_DATA_REG <= 8'h00;
        else if (w_rx_done) RX_DATA_REG <= w_rx_data;
    end

    always_ff @(posedge PCLK, posedge PRESET) begin
        if (PRESET) begin
            CTL_REG <= 8'h00; BAUD_REG <= 8'h00; TX_DATA_REG <= 8'h00;
        end else if (PREADY & PWRITE) begin
            case (PADDR[11:0])
                UART_CTL_ADDR:    CTL_REG     <= PWDATA[7:0];
                UART_BAUD_ADDR:   BAUD_REG    <= PWDATA[7:0];
                UART_TXDATA_ADDR: TX_DATA_REG <= PWDATA[7:0];
            endcase
        end
    end

    always_ff @(posedge PCLK, posedge PRESET) begin
        if (PRESET) ctl_prev <= 1'b0;
        else        ctl_prev <= CTL_REG[0];
    end
    assign tx_start_pulse = CTL_REG[0] & ~ctl_prev;

    uart_tx U_UART_TX (
        .clk(PCLK), .rst(PRESET), .tx_start(tx_start_pulse), .b_tick(w_b_tick),
        .tx_data(TX_DATA_REG), .tx_busy(w_tx_busy), .tx_done(w_tx_done), .uart_tx(uart_tx)
    );

    uart_rx U_UART_RX (
        .clk(PCLK), .rst(PRESET), .rx(uart_rx), .b_tick(w_b_tick),
        .rx_data(w_rx_data), .rx_done(w_rx_done)
    );

    baud_gen U_BAUD_GEN (
        .clk(PCLK), .rst(PRESET), .sel(BAUD_REG[1:0]), .b_tick(w_b_tick)
    );

endmodule

module uart_tx (
    input clk, rst, tx_start, b_tick,
    input [7:0] tx_data,
    output tx_busy, tx_done, uart_tx
);
    localparam IDLE=2'd0, START=2'd1, DATA=2'd2, STOP=2'd3;
    reg [1:0] c_state, n_state;
    reg tx_reg, tx_next, busy_reg, busy_next, done_reg, done_next;
    reg [2:0] bit_cnt_reg, bit_cnt_next;
    reg [3:0] b_tick_cnt_reg, b_tick_cnt_next;
    reg [7:0] data_in_buf_reg, data_in_buf_next;

    assign uart_tx = tx_reg;
    assign tx_busy = busy_reg;
    assign tx_done = done_reg;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            c_state <= IDLE; tx_reg <= 1'b1; busy_reg <= 1'b0; done_reg <= 1'b0;
            bit_cnt_reg <= 3'd0; b_tick_cnt_reg <= 4'd0; data_in_buf_reg <= 8'h00;
        end else begin
            c_state <= n_state; tx_reg <= tx_next; busy_reg <= busy_next;
            done_reg <= done_next; bit_cnt_reg <= bit_cnt_next;
            b_tick_cnt_reg <= b_tick_cnt_next; data_in_buf_reg <= data_in_buf_next;
        end
    end

    always @(*) begin
        n_state = c_state; tx_next = tx_reg; busy_next = busy_reg; done_next = 1'b0;
        bit_cnt_next = bit_cnt_reg; b_tick_cnt_next = b_tick_cnt_reg; data_in_buf_next = data_in_buf_reg;

        case (c_state)
            IDLE: begin
                tx_next = 1'b1; busy_next = 1'b0; bit_cnt_next = 3'd0; b_tick_cnt_next = 4'd0;
                if (tx_start) begin n_state = START; busy_next = 1'b1; data_in_buf_next = tx_data; end
            end
            START: begin
                tx_next = 1'b0;
                if (b_tick) begin
                    if (b_tick_cnt_reg == 15) begin n_state = DATA; b_tick_cnt_next = 4'd0; end
                    else b_tick_cnt_next = b_tick_cnt_reg + 1;
                end
            end
            DATA: begin
                tx_next = data_in_buf_reg[0];
                if (b_tick) begin
                    if (b_tick_cnt_reg == 15) begin
                        b_tick_cnt_next = 4'd0;
                        if (bit_cnt_reg == 7) n_state = STOP;
                        else begin bit_cnt_next = bit_cnt_reg + 1; data_in_buf_next = {1'b0, data_in_buf_reg[7:1]}; end
                    end else b_tick_cnt_next = b_tick_cnt_reg + 1;
                end
            end
            STOP: begin
                tx_next = 1'b1;
                if (b_tick) begin
                    if (b_tick_cnt_reg == 15) begin busy_next = 1'b0; done_next = 1'b1; n_state = IDLE; end
                    else b_tick_cnt_next = b_tick_cnt_reg + 1;
                end
            end
        endcase
    end
endmodule

module uart_rx (
    input clk, rst, rx, b_tick,
    output [7:0] rx_data, output rx_done
);
    localparam IDLE=2'd0, START=2'd1, DATA=2'd2, STOP=2'd3;
    reg [1:0] c_state, n_state;
    reg [4:0] b_tick_cnt_reg, b_tick_cnt_next;
    reg [2:0] bit_cnt_reg, bit_cnt_next;
    reg [7:0] buf_reg, buf_next;
    reg done_reg, done_next;

    assign rx_data = buf_reg;
    assign rx_done = done_reg;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            c_state             <= IDLE;
             b_tick_cnt_reg <= 5'd0; 
             bit_cnt_reg <= 3'd0; 
             done_reg <= 1'b0; 
             buf_reg <= 8'd0;
        end else begin
            c_state <= n_state; 
            b_tick_cnt_reg <= b_tick_cnt_next;
            bit_cnt_reg <= bit_cnt_next; 
            done_reg <= done_next; 
            buf_reg <= buf_next;
        end
    end

    always @(*) begin
        n_state = c_state; b_tick_cnt_next = b_tick_cnt_reg; bit_cnt_next = bit_cnt_reg; buf_next = buf_reg; done_next = 1'b0;
        case (c_state)
            IDLE: begin
                b_tick_cnt_next = 5'd0; bit_cnt_next = 3'd0;
                if (b_tick & !rx) begin buf_next = 8'd0; n_state = START; end
            end
            START: begin
                if (b_tick) begin
                    if (b_tick_cnt_reg == 7) begin b_tick_cnt_next = 5'd0; n_state = DATA; end
                    else b_tick_cnt_next = b_tick_cnt_reg + 1;
                end
            end
            DATA: begin
                if (b_tick) begin
                    if (b_tick_cnt_reg == 15) begin
                        b_tick_cnt_next = 5'd0; buf_next = {rx, buf_reg[7:1]};
                        if (bit_cnt_reg == 7) n_state = STOP;
                        else bit_cnt_next = bit_cnt_reg + 1;
                    end else b_tick_cnt_next = b_tick_cnt_reg + 1;
                end
            end
            STOP: begin
                if (b_tick) begin
                    if (b_tick_cnt_reg == 15) begin done_next = 1'b1; n_state = IDLE; end
                    else b_tick_cnt_next = b_tick_cnt_reg + 1;
                end
            end
        endcase
    end
endmodule

module baud_gen (
    input clk, rst, [1:0] sel, output reg b_tick
);
    reg [9:0] limit, counter_reg;
    always @(*) begin
        case (sel)
            2'b00: limit = 10'd650; // 9600
            2'b01: limit = 10'd325; // 19200
            2'b10: limit = 10'd53;  // 115200
            default: limit = 10'd650;
        endcase
    end
    always @(posedge clk, posedge rst) begin
        if (rst) begin counter_reg <= 10'd0; b_tick <= 1'b0; end
        else if (counter_reg == limit) begin counter_reg <= 10'd0; b_tick <= 1'b1; end
        else begin counter_reg <= counter_reg + 1; b_tick <= 1'b0; end
    end
endmodule