`timescale 1ns / 1ps

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
    parameter IDLE=3'd0, START=3'd1, WAIT=3'd2, SYNC_L=3'd3, SYNC_H=3'd4, DATA_SYNC=3'd5, DATA_C=3'd6, STOP=3'd7;
    reg [2:0] c_state, n_state;

    reg dhtio_reg, dhtio_next;
    reg io_sel_reg, io_sel_next;
    wire w_tick_10u;

    reg [$clog2(40)-1:0] data_cnt_reg, data_cnt_next;
    reg [15:0] humidity_reg, humidity_next;
    reg [15:0] temperature_reg, temperature_next;
    reg [7:0] checksum_reg, checksum_next;
    reg [39:0] data_40bit_reg, data_40bit_next;
    reg [7:0] for_checksum_next, for_checksum_reg;
    reg done_next, done_reg;

    // 19msec counter by 10usec tick, 11bit
    reg [$clog2(1900)-1:0] tick_cnt_reg, tick_cnt_next;

    tick_gen_10u U_TICK_GEN_10U (
        .clk     (clk),        // 100Mhz
        .rst     (rst),
        .tick_10u(w_tick_10u)  // 100Khz
    );

    assign dhtio       = (io_sel_reg) ? dhtio_reg : 1'bz;

    // for debug
    assign debug       = {dht11_valid, c_state};

    assign humidity    = humidity_reg;
    assign temperature = temperature_reg;
    assign dht11_valid = (for_checksum_reg == checksum_reg) ? 1'b1 : 1'b0;
    assign dht11_done  = done_reg;

    // state register SL
    always @(posedge clk, posedge rst) begin
        if (rst) begin
            c_state <= IDLE;
            dhtio_reg <= 1'b1;
            io_sel_reg <= 1'b1;
            tick_cnt_reg <= 0;
            humidity_reg <= 0;
            temperature_reg <= 0;
            checksum_reg <= 0;
            for_checksum_reg <= 0;
            done_reg <= 0;
            data_40bit_reg <= 0;
            data_cnt_reg<=0;
        end else begin
            c_state <= n_state;
            dhtio_reg <= dhtio_next;
            io_sel_reg <= io_sel_next;
            tick_cnt_reg <= tick_cnt_next;
            humidity_reg <= humidity_next;
            temperature_reg <= temperature_next;
            checksum_reg <= checksum_next;
            for_checksum_reg <= for_checksum_next;
            done_reg <= done_next;
            data_40bit_reg <= data_40bit_next;
            data_cnt_reg<=data_cnt_next;
        end
    end

    // next state CL
    always @(*) begin
        n_state           = c_state;
        dhtio_next        = dhtio_reg;
        io_sel_next       = io_sel_reg;
        tick_cnt_next     = tick_cnt_reg;
        humidity_next     = humidity_reg;
        temperature_next  = temperature_reg;
        checksum_next     = checksum_reg;
        for_checksum_next = for_checksum_reg;
        done_next         = done_reg;
        data_40bit_next   = data_40bit_reg;
        data_cnt_next=data_cnt_reg;
        case (c_state)
            IDLE: begin
                if (start) begin
                    n_state = START;
                end
            end
            START: begin
                dhtio_next = 1'b0;
                if (w_tick_10u) begin
                    tick_cnt_next = tick_cnt_reg + 1;
                    if (tick_cnt_reg == 1900) begin  // 19ms?
                        tick_cnt_next = 0;
                        n_state = WAIT;
                    end
                end
            end
            WAIT: begin
                dhtio_next = 1'b1;
                if (w_tick_10u) begin
                    tick_cnt_next = tick_cnt_reg + 1;
                    if (tick_cnt_reg == 3) begin  // 20us: danger
                        // for output to high-z
                        n_state = SYNC_L;
                        io_sel_next = 1'b0;

                        tick_cnt_next = 0;
                    end
                end
            end
            SYNC_L: begin
                if (w_tick_10u) begin  // !! noise danger !! 
                    if (dhtio == 1) begin
                        n_state = SYNC_H;
                    end
                end
            end
            SYNC_H: begin
                if (w_tick_10u) begin
                    if (dhtio == 0) begin
                        n_state = DATA_SYNC;
                    end
                end
            end
            DATA_SYNC: begin
                if (w_tick_10u) begin
                    if (dhtio == 1) begin
                        n_state = DATA_C;
                    end
                end
            end
            DATA_C: begin
                if (w_tick_10u) begin
                    if (dhtio == 1) begin
                        // counter
                        tick_cnt_next = tick_cnt_reg + 1;
                    end else begin
                        if (tick_cnt_reg > 5) begin
                            // data 1
                            data_40bit_next[39-data_cnt_reg] = 1'b1;
                        end else begin
                            // data 0
                            data_40bit_next[39-data_cnt_reg] = 1'b0;
                        end
                        data_cnt_next = data_cnt_reg + 1;
                        tick_cnt_next = 0;
                        if (data_cnt_next >= 40) begin

                            n_state   = STOP;
                            done_next = 1'b1;
                            data_cnt_next  = 0;
                        end else begin
                            n_state = DATA_SYNC;
                        end
                    end
                end
            end
            STOP: begin
                humidity_next = data_40bit_reg[39:24];
                temperature_next = data_40bit_reg[23:8];
                checksum_next = data_40bit_reg[7:0];
                for_checksum_next= data_40bit_reg[39:32]+data_40bit_reg[31:24]+data_40bit_reg[23:16]+data_40bit_reg[15:8];
                if (w_tick_10u) begin
                    // 50us -> IDLE
                    tick_cnt_next = tick_cnt_reg + 1;
                    if (tick_cnt_reg == 5) begin
                        // output mode
                        dhtio_next = 1'b1;
                        io_sel_next = 1'b1;
                        n_state = IDLE;
                        done_next = 1'b0;
                    end
                end
            end
        endcase
    end
endmodule


module tick_gen_10u (
    input      clk,      // 100Mhz
    input      rst,
    output reg tick_10u  // 100Khz
);
    parameter F_COUNT = 100_000_000 / 100_000;
    reg [$clog2(F_COUNT)-1:0] counter_reg;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            counter_reg <= 0;
            tick_10u <= 0;
        end else begin
            counter_reg <= counter_reg + 1;
            if (counter_reg == F_COUNT - 1) begin
                counter_reg <= 0;
                tick_10u <= 1'b1;
            end else begin
                tick_10u <= 1'b0;
            end
        end
    end
endmodule
