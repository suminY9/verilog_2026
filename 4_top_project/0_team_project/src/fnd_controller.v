`timescale 1ns / 1ps

module fnd_controller (
    input [23:0] fnd_in_data,
    input [23:0] watch_in_data,
    input clk,
    input reset,
    input sel_display,
    input sel_sensor,
    input sw_3,  // sw[3] 
    output [3:0] fnd_digit,
    output [7:0] fnd_data,
    output [15:0] display_data,
    output [15:0] watch_data
);
    wire [3:0] w_digit_msec_1, w_digit_msec_10;
    wire [3:0] w_digit_sec_1, w_digit_sec_10;
    wire [3:0] w_digit_min_1, w_digit_min_10;
    wire [3:0] w_digit_hour_1, w_digit_hour_10;
    wire [3:0] w_uart_hour_1, w_uart_hour_10, w_uart_min_1, w_uart_min_10;

    wire [3:0] w_mux_dist_out_i, w_mux_dist_out_o;
    wire [3:0] w_sensor_digit_1, w_sensor_digit_10, w_sensor_digit_100, w_sensor_digit_1000, w_mux_dht11_out_i, w_mux_dht11_out_o;
    wire [3:0] w_mux_out_sensor;

    wire [3:0] w_mux_hour_min_out, w_mux_sec_msec_out;
    wire [3:0] w_mux_4x1_out;
    wire [2:0] w_digit_sel;
    wire w_clk_out;
    wire w_dot_onoff;
    wire [15:0] w_display_time_sms, w_display_time_hm, w_display_sensor;
    wire [15:0] w_sensor_data;


    clk_div U_CLK_DIV (
        .clk(clk),  // 100MHz
        .reset(reset),
        .o_1khz(w_clk_out)  // 1KHz
    );

    counter_8 U_CNT (
        .clk(w_clk_out),
        .reset(reset),
        .count_r(w_digit_sel)
    );

    dec_2x4 U_DEC_2x4 (
        .din (w_digit_sel[1:0]),
        .dout(fnd_digit)
    );


    digit_splitter #(
        .BIT_WIDTH(5)
    ) U_UART_HOUR_DS (
        .in_data (watch_in_data[23:19]),
        .digit_1 (w_uart_hour_1),
        .digit_10(w_uart_hour_10)
    );

    digit_splitter #(
        .BIT_WIDTH(5)
    ) U_UART_min_DS (
        .in_data (watch_in_data[18:13]),
        .digit_1 (w_uart_min_1),
        .digit_10(w_uart_min_10)
    );

    // hour
    digit_splitter #(
        .BIT_WIDTH(5)
    ) U_HOUR_DS (
        .in_data (fnd_in_data[23:19]),
        .digit_1 (w_digit_hour_1),
        .digit_10(w_digit_hour_10)
    );
    // min
    digit_splitter #(
        .BIT_WIDTH(6)
    ) U_MIN_DS (
        .in_data (fnd_in_data[18:13]),
        .digit_1 (w_digit_min_1),
        .digit_10(w_digit_min_10)
    );
    // sec
    digit_splitter #(
        .BIT_WIDTH(6)
    ) U_SEC_DS (
        .in_data (fnd_in_data[12:7]),
        .digit_1 (w_digit_sec_1),
        .digit_10(w_digit_sec_10)
    );
    // msec
    digit_splitter #(
        .BIT_WIDTH(7)
    ) U_MSEC_DS (
        .in_data (fnd_in_data[6:0]),
        .digit_1 (w_digit_msec_1),
        .digit_10(w_digit_msec_10)
    );

    fifo_param_bit #(
        .WIDTH(16)
    ) FIFO_INPUT_DHT11 (
        .clk(clk),
        .i_data(fnd_in_data[15:0]),
        .o_data(w_sensor_data)
    );

    digit_splitter_100 U_SENSOR_DS_10_1 (
        .in_data (w_sensor_data[7:0]),
        .digit_1 (w_sensor_digit_1),
        .digit_10(w_sensor_digit_10)
    );

    digit_splitter_100 U_SENSOR_DS_1000_100 (
        .in_data (w_sensor_data[15:8]),
        .digit_1 (w_sensor_digit_100),
        .digit_10(w_sensor_digit_1000)
    );

    fifo_param_bit #(
        .WIDTH(16)
    ) FIFO_SPLITTER_SENSOR (
        .clk(clk),
        .i_data({
            w_sensor_digit_1000,
            w_sensor_digit_100,
            w_sensor_digit_10,
            w_sensor_digit_1
        }),
        .o_data(w_display_sensor)
    );

    dot_onoff_comp U_DOT_COMP (
        .msec(fnd_in_data[6:0]),
        .dot_on_off(w_dot_onoff)
    );

    mux_8x1 U_MUX_HOUR_MIN (
        .sel(w_digit_sel),
        .digit_1(w_digit_min_1),
        .digit_10(w_digit_min_10),
        .digit_100(w_digit_hour_1),
        .digit_1000(w_digit_hour_10),
        .digit_dot_1(4'hf),
        .digit_dot_10(4'hf),
        .digit_dot_100({3'b111, w_dot_onoff}),
        .digit_dot_1000(4'hf),
        .mux_out(w_mux_hour_min_out)
    );

    mux_8x1 U_MUX_SEC_MSEC (
        .sel(w_digit_sel),
        .digit_1(w_digit_msec_1),
        .digit_10(w_digit_msec_10),
        .digit_100(w_digit_sec_1),
        .digit_1000(w_digit_sec_10),
        .digit_dot_1(4'hf),
        .digit_dot_10(4'hf),
        .digit_dot_100({3'b111, w_dot_onoff}),
        .digit_dot_1000(4'hf),
        .mux_out(w_mux_sec_msec_out)
    );

    mux_4x1 U_MUX_4X1_DIST_DIGIT (
        .sel(w_digit_sel[1:0]),
        .i_sel_1(w_display_sensor[3:0]),
        .i_sel_10(w_display_sensor[7:4]),
        .i_sel_100(w_display_sensor[11:8]),
        .i_sel_1000(w_display_sensor[15:12]),
        .mux_out(w_mux_dist_out_i)
    );
    mux_8x1 U_MUX_8X1_DHT11_DIGIT (
        .sel(w_digit_sel),
        .digit_1(w_display_sensor[3:0]),
        .digit_10(w_display_sensor[7:4]),
        .digit_100(w_display_sensor[11:8]),
        .digit_1000(w_display_sensor[15:12]),
        .digit_dot_1(w_display_sensor[3:0]),
        .digit_dot_10(w_display_sensor[7:4]),
        .digit_dot_100(4'b1110),                        // dot
        .digit_dot_1000(w_display_sensor[15:12]),
        .mux_out(w_mux_dht11_out_i)
    );

    fifo_param_bit #(
        .WIDTH(4)
    ) U_FIFO_DIST_OUT (
        .clk(clk),
        .i_data(w_mux_dist_out_i),
        .o_data(w_mux_dist_out_o)
    );

    fifo_param_bit #(
        .WIDTH(4)
    ) U_FIFO_DHT11_OUT (
        .clk(clk),
        .i_data(w_mux_dht11_out_i),
        .o_data(w_mux_dht11_out_o)
    );

    mux_2x1 U_MUX_2X1_SENSOR_SEL (
        .sel(sel_sensor),
        .i_sel0(w_mux_dist_out_o),  // sw[1] 0 : sr04
        .i_sel1(w_mux_dht11_out_o),  // sw[1] 1 : dht11
        .o_mux(w_mux_out_sensor)
    );

    mux_4x1 U_MUX_4X1_disp_mode (
        .sel({sw_3, sel_display}),
        .i_sel_1(w_mux_sec_msec_out),
        .i_sel_10(w_mux_hour_min_out),
        .i_sel_100(w_mux_out_sensor),  // sw[3], !sw[1]: sr04
        .i_sel_1000(w_mux_out_sensor),  // sw[3], sw[1]: dht11
        .mux_out(w_mux_4x1_out)
    );

    fifo_param_bit U_FIFO_TIME_SMS (
        .clk(clk),
        .i_data({
            w_digit_sec_10, w_digit_sec_1, w_digit_msec_10, w_digit_msec_1
        }),
        .o_data(w_display_time_sms)
    );
    fifo_param_bit U_FIFO_TIME_HM (
        .clk(clk),
        .i_data({
            w_digit_hour_10, w_digit_hour_1, w_digit_min_10, w_digit_min_1
        }),
        .o_data(w_display_time_hm)
    );

    mux_4x1_param_bit U_MUX_2X1_16BIT (
        .sel({sw_3, sel_display}),
        .i_sel0(w_display_time_sms),
        .i_sel1(w_display_time_hm),
        .i_sel2(w_display_sensor),
        .i_sel3(w_display_sensor),
        .o_mux(display_data)
    );

    bcd U_BCD (
        .bcd(w_mux_4x1_out),
        .fnd_data(fnd_data)
    );

    assign watch_data = {w_uart_hour_10, w_uart_hour_1, w_uart_min_10, w_uart_min_1};

    // assign watch_data = w_display_time_hm;
endmodule


module dot_onoff_comp (
    input [6:0] msec,
    output dot_on_off
);
    assign dot_on_off = (msec < 50);

endmodule


module mux_4x1_param_bit #(
    BIT_WIDTH = 16
) (
    input [1:0] sel,
    input [BIT_WIDTH-1:0] i_sel0,
    input [BIT_WIDTH-1:0] i_sel1,
    input [BIT_WIDTH-1:0] i_sel2,
    input [BIT_WIDTH-1:0] i_sel3,
    output reg [BIT_WIDTH-1:0] o_mux
);

    // assign o_mux = (sel) ? i_sel1 : i_sel0;
    always @(*) begin
        case (sel)
            2'b00: o_mux = i_sel0;
            2'b01: o_mux = i_sel1;
            2'b10: o_mux = i_sel2;
            2'b11: o_mux = i_sel3;
        endcase
    end
endmodule

module mux_2x1_param_bit #(
    BIT_WIDTH = 16
) (
    input sel,
    input [BIT_WIDTH-1:0] i_sel0,
    input [BIT_WIDTH-1:0] i_sel1,
    output [BIT_WIDTH-1:0] o_mux
);

    assign o_mux = (sel) ? i_sel1 : i_sel0;
endmodule


module mux_2x1 (
    input sel,
    input [3:0] i_sel0,
    input [3:0] i_sel1,
    output [3:0] o_mux
);
    // sel 1: i_sel1, 0: i_sel0
    assign o_mux = (sel) ? i_sel1 : i_sel0;
endmodule

module clk_div (
    input clk,  // 100MHz
    input reset,
    output reg o_1khz  // 1KHz
);
    reg [$clog2(100_000):0] clk_cnt;  // reg [16:0]

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            clk_cnt <= 17'b0;
            o_1khz  <= 1'b0;
        end else begin
            if (clk_cnt == 99_999) begin
                clk_cnt <= 1'b0;
                o_1khz  <= 1'b1;
            end else begin
                clk_cnt <= clk_cnt + 1'b1;
                o_1khz  <= 1'b0;
            end
        end
    end
endmodule


module counter_8 (
    input clk,
    input reset,
    output reg [2:0] count_r
);
    always @(posedge clk, posedge reset) begin
        if (reset) count_r <= 0;
        else begin
            count_r <= count_r + 1'b1;
        end
    end
endmodule


// fnd digit display selection
module dec_2x4 (
    input [1:0] din,  // digit_sel
    output reg [3:0] dout  // fnd_digit
);
    always @(*) begin
        case (din)
            2'b00:   dout = 4'b1110;
            2'b01:   dout = 4'b1101;
            2'b10:   dout = 4'b1011;
            2'b11:   dout = 4'b0111;
            default: dout = 4'b1111;
        endcase
    end
endmodule

module mux_4x1 (
    input [1:0] sel,
    input [3:0] i_sel_1,
    input [3:0] i_sel_10,
    input [3:0] i_sel_100,
    input [3:0] i_sel_1000,
    output reg [3:0] mux_out
);
    always @(*) begin
        case (sel)
            2'b00:   mux_out = i_sel_1;
            2'b01:   mux_out = i_sel_10;
            2'b10:   mux_out = i_sel_100;
            2'b11:   mux_out = i_sel_1000;
            default: mux_out = 4'b0000;
        endcase
    end
endmodule

module mux_8x1 (
    input [2:0] sel,
    input [3:0] digit_1,
    input [3:0] digit_10,
    input [3:0] digit_100,
    input [3:0] digit_1000,
    input [3:0] digit_dot_1,
    input [3:0] digit_dot_10,
    input [3:0] digit_dot_100,
    input [3:0] digit_dot_1000,
    output reg [3:0] mux_out
);
    always @(*) begin
        case (sel)
            3'b000:  mux_out = digit_1;
            3'b001:  mux_out = digit_10;
            3'b010:  mux_out = digit_100;
            3'b011:  mux_out = digit_1000;
            3'b100:  mux_out = digit_dot_1;
            3'b101:  mux_out = digit_dot_10;
            3'b110:  mux_out = digit_dot_100;
            3'b111:  mux_out = digit_dot_1000;
            default: mux_out = 4'b0000;
        endcase
    end
endmodule

module digit_splitter #(
    parameter BIT_WIDTH = 7
) (
    input [BIT_WIDTH-1:0] in_data,
    output [3:0] digit_1,
    output [3:0] digit_10
);
    assign digit_1  = in_data % 10;
    assign digit_10 = (in_data / 10) % 10;

endmodule


module digit_splitter_100 #(
    BIT_WIDTH = 8
) (
    input [BIT_WIDTH-1:0] in_data,
    output [3:0] digit_1,
    output [3:0] digit_10
);
    assign digit_1  = in_data % 10;
    assign digit_10 = (in_data / 10) % 10;
    // assign digit_100 = (in_data / 100) % 10;
    // assign digit_1000 = (in_data / 1000) % 10;
endmodule

module digit_splitter_10000 #(
    BIT_WIDTH = 14
) (
    input [BIT_WIDTH-1:0] in_data,
    output [3:0] digit_1,
    output [3:0] digit_10,
    output [3:0] digit_100,
    output [3:0] digit_1000
);
    assign digit_1 = in_data % 10;
    assign digit_10 = (in_data / 10) % 10;
    assign digit_100 = (in_data / 100) % 10;
    assign digit_1000 = (in_data / 1000) % 10;
endmodule


module bcd (
    input [3:0] bcd,
    output reg [7:0] fnd_data
);
    always @(bcd) begin
        case (bcd)
            4'd0: fnd_data = 8'hc0;
            4'd1: fnd_data = 8'hf9;
            4'd2: fnd_data = 8'ha4;
            4'd3: fnd_data = 8'hb0;
            4'd4: fnd_data = 8'h99;
            4'd5: fnd_data = 8'h92;
            4'd6: fnd_data = 8'h82;
            4'd7: fnd_data = 8'hf8;
            4'd8: fnd_data = 8'h80;
            4'd9: fnd_data = 8'h90;
            4'd10: fnd_data = 8'hff;
            4'd11: fnd_data = 8'hff;
            4'd12: fnd_data = 8'hff;
            4'd13: fnd_data = 8'hff;
            4'd14: fnd_data = 8'h7f;
            4'd15: fnd_data = 8'hff;
            default: fnd_data = 8'hFF;
        endcase
    end
endmodule
