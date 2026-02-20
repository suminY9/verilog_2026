`timescale 1ns / 1ps

module fnd_controller_watch (
    input         clk,
    input         reset,
    input         sel_display,
    input  [23:0] fnd_in_data,
    output [ 3:0] fnd_digit,
    output [ 7:0] fnd_data
);

    // counter
    wire [2:0] w_digit_sel;
    wire w_1khz;
    // digit splitter
    wire [3:0] w_digit_hour_1, w_digit_hour_10;
    wire [3:0] w_digit_min_1, w_digit_min_10;
    wire [3:0] w_digit_sec_1, w_digit_sec_10;
    wire [3:0] w_digit_msec_1, w_digit_msec_10;
    // dot comparision
    wire w_dot_onoff;
    // MUX
    wire [3:0] w_mux_hour_min_out, w_mux_sec_msec_out;
    wire [3:0] w_mux_2x1_out;

    clk_div U_CLK_DIV (
        .clk(clk),
        .reset(reset),
        .o_1khz(w_1khz)
    );

    // counter 8
    counter_8 U_COUNTER_8 (
        .clk(w_1khz),
        .reset(reset),
        .digit_sel(w_digit_sel)
    );

    // decoder
    decoder_2x4 U_DECODER_2x4 (
        .digit_sel  (w_digit_sel[1:0]),
        .decoder_out(fnd_digit)
    );

    // digit splitter
    digit_splitter #(
        .BIT_WIDTH(5)
    ) U_HOUR_DS (
        .in_data (fnd_in_data[23:19]),
        .digit_1 (w_digit_hour_1),
        .digit_10(w_digit_hour_10),
        .digit_100()
    );
    digit_splitter #(
        .BIT_WIDTH(6)
    ) U_MIN_DS (
        .in_data (fnd_in_data[18:13]),
        .digit_1 (w_digit_min_1),
        .digit_10(w_digit_min_10),
        .digit_100()
    );
    digit_splitter #(
        .BIT_WIDTH(6)
    ) U_SEC_DS (
        .in_data (fnd_in_data[12:7]),
        .digit_1 (w_digit_sec_1),
        .digit_10(w_digit_sec_10),
        .digit_100()
    );
    digit_splitter #(
        .BIT_WIDTH(7)
    ) U_MSEC_DS (
        .in_data (fnd_in_data[6:0]),
        .digit_1 (w_digit_msec_1),
        .digit_10(w_digit_msec_10),
        .digit_100()
    );

    // dot comparision
    dot_onoff_comp #(
        .BIT_WIDTH(7)
    ) U_DOT_COMP_WATCH (
        .msec(fnd_in_data[6:0]),
        .dot_onoff(w_dot_onoff)
    );

    // MUX
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
    mux_2x1 U_MUX_2x1 (
        .sel(sel_display),
        .i_sel0(w_mux_sec_msec_out),  // sel 0: sec_msec
        .i_sel1(w_mux_hour_min_out),  // sel 1: hour_min
        .o_mux(w_mux_2x1_out)
    );

    // BCD
    BCD U_BCD (
        .bcd(w_mux_2x1_out),
        .fnd_data(fnd_data)
    );
endmodule

module fnd_controller_SR04 (
    input         clk,
    input         reset,
    input  [11:0] fnd_in_data,
    output [ 3:0] fnd_digit,
    output [ 7:0] fnd_data
);

    // counter
    wire [2:0] w_digit_sel;
    wire w_1khz;
    // digit splitter
    wire [3:0] w_digit_1, w_digit_10, w_digit_100;
    // MUX
    wire [3:0] w_out;


    clk_div U_CLK_DIV (
        .clk(clk),
        .reset(reset),
        .o_1khz(w_1khz)
    );

    // counter 8
    counter_8 U_COUNTER_8 (
        .clk(w_1khz),
        .reset(reset),
        .digit_sel(w_digit_sel)
    );

    // decoder
    decoder_2x4 U_DECODER_2x4 (
        .digit_sel  (w_digit_sel[1:0]),
        .decoder_out(fnd_digit)
    );

    // digit splitter
    digit_splitter #(
        .BIT_WIDTH(12)
    ) U_HUM_DS (
        .in_data (fnd_in_data),
        .digit_1 (w_digit_1),
        .digit_10(w_digit_10),
        .digit_100(w_digit_100)
    );

    // MUX
    mux_8x1 U_MUX_HUMIDITY (
        .sel(w_digit_sel),
        .digit_1(w_digit_1),
        .digit_10(w_digit_10),
        .digit_100(w_digit_100),
        .digit_1000(4'd0),
        .digit_dot_1(4'hf),
        .digit_dot_10(4'hf),
        .digit_dot_100(4'hf),
        .digit_dot_1000(4'hf),
        .mux_out(w_out)
    );

    // BCD
    BCD U_BCD (
        .bcd(w_out),
        .fnd_data(fnd_data)
    );
endmodule

module fnd_controller_dht11 (
    input         clk,
    input         reset,
    input         sel_display,
    input  [31:0] fnd_in_data,
    output [ 3:0] fnd_digit,
    output [ 7:0] fnd_data
);

    // counter
    wire [2:0] w_digit_sel;
    wire w_1khz;
    // digit splitter
    wire [3:0] w_digit_hum_1, w_digit_hum_10;
    wire [3:0] w_digit_hum_d01, w_digit_hum_d10;
    wire [3:0] w_digit_temp_1, w_digit_temp_10;
    wire [3:0] w_digit_temp_d01, w_digit_temp_d10;
    // MUX
    wire [3:0] w_mux_hum_out, w_mux_temp_out;
    wire [3:0] w_mux_2x1_out;


    clk_div U_CLK_DIV (
        .clk(clk),
        .reset(reset),
        .o_1khz(w_1khz)
    );

    // counter 8
    counter_8 U_COUNTER_8 (
        .clk(w_1khz),
        .reset(reset),
        .digit_sel(w_digit_sel)
    );

    // decoder
    decoder_2x4 U_DECODER_2x4 (
        .digit_sel  (w_digit_sel[1:0]),
        .decoder_out(fnd_digit)
    );

    // digit splitter
    digit_splitter #(
        .BIT_WIDTH(8)
    ) U_HUM_DS (
        .in_data (fnd_in_data[31:24]),
        .digit_1 (w_digit_hum_1),
        .digit_10(w_digit_hum_10),
        .digit_100()
    );
    digit_splitter #(
        .BIT_WIDTH(8)
    ) U_HUM_D_DS (
        .in_data (fnd_in_data[23:16]),
        .digit_1 (w_digit_hum_d01),
        .digit_10(w_digit_hum_d10),
        .digit_100()
    );
    digit_splitter #(
        .BIT_WIDTH(8)
    ) U_TEMP_DS (
        .in_data (fnd_in_data[15:8]),
        .digit_1 (w_digit_temp_1),
        .digit_10(w_digit_temp_10),
        .digit_100()
    );
    digit_splitter #(
        .BIT_WIDTH(8)
    ) U_TEMP_D_DS (
        .in_data (fnd_in_data[7:0]),
        .digit_1 (w_digit_temp_d01),
        .digit_10(w_digit_temp_d10),
        .digit_100()
    );

    // MUX
    mux_8x1 U_MUX_HUMIDITY (
        .sel(w_digit_sel),
        .digit_1(w_digit_hum_d01),
        .digit_10(w_digit_hum_d10),
        .digit_100(w_digit_hum_1),
        .digit_1000(w_digit_hum_10),
        .digit_dot_1(4'hf),
        .digit_dot_10(4'hf),
        .digit_dot_100(4'b1110),
        .digit_dot_1000(4'hf),
        .mux_out(w_mux_hum_out)
    );
    mux_8x1 U_MUX_TEMPERATURE (
        .sel(w_digit_sel),
        .digit_1(w_digit_temp_d01),
        .digit_10(w_digit_temp_d10),
        .digit_100(w_digit_temp_1),
        .digit_1000(w_digit_temp_10),
        .digit_dot_1(4'hf),
        .digit_dot_10(4'hf),
        .digit_dot_100(4'b1110),
        .digit_dot_1000(4'hf),
        .mux_out(w_mux_temp_out)
    );
    mux_2x1 U_MUX_2x1 (
        .sel(sel_display),
        .i_sel0(w_mux_hum_out),  // sel 0: humidity
        .i_sel1(w_mux_temp_out),  // sel 1: temperature
        .o_mux(w_mux_2x1_out)
    );

    // BCD
    BCD U_BCD (
        .bcd(w_mux_2x1_out),
        .fnd_data(fnd_data)
    );
endmodule










module dot_onoff_comp #(
    parameter BIT_WIDTH = 7
)(
    input [BIT_WIDTH - 1:0] msec,
    output dot_onoff
);

    // dot_onoff = 0: on / 1: off
    assign dot_onoff = (msec < 50);

endmodule

module mux_2x1 (
    input sel,
    input [3:0] i_sel0,
    input [3:0] i_sel1,
    output [3:0] o_mux
);

    assign o_mux = (sel) ? i_sel1 : i_sel0;

endmodule

module clk_div (
    input clk,
    input reset,
    output reg o_1khz
);
    reg [$clog2(
100_000
):0] counter_r;  //counter 모듈의 counter_r과 다른거다. 모듈이 다르니까.

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            counter_r <= 0;
            o_1khz <= 1'b0;
        end else begin
            if (counter_r == 99_999) begin
                counter_r <= 0;
                o_1khz <= 1'b1;
            end else begin
                counter_r <= counter_r + 1;
                o_1khz <= 1'b0;
            end
        end
    end
endmodule

module counter_8 (
    input clk,
    input reset,
    output [2:0] digit_sel
);

    reg [2:0] counter_r;  // 0~8 값을 유지해야 하기 때문에 reg type

    assign digit_sel = counter_r;   // 선언보다 assign이 뒤에 와야 함에 주의

    // 순차논리회로 -> 항상 always문 사용
    // posedge clk or posedge reset 과 같은 뜻 (콤마(,) = or)
    // 하나의 모듈 안에서는 posedge, negedge 둘 중 하나로 통일. edge를 둘 다 쓰기보다는 주파수를 2배 높이면 됨.
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            // init counter_r
            counter_r <= 0;     // 순차 논리일 때에는 '<=' 사용(non-blocking 연산)
        end else begin
            // to do
            counter_r <= counter_r + 1;     // counter_r이 2-bit이므로 3 다음에 4가 되지 않고 0이 됨. overflow carry는 버려짐.
        end
    end
endmodule

module decoder_2x4 (
    input      [1:0] digit_sel,
    output reg [3:0] decoder_out
);
    always @digit_sel begin
        case (digit_sel)
            2'b00: decoder_out = 4'b1110;
            2'b01: decoder_out = 4'b1101;
            2'b10: decoder_out = 4'b1011;
            2'b11: decoder_out = 4'b0111;
        endcase
    end
endmodule

module mux_8x1 (
    input      [2:0] sel,
    input      [3:0] digit_1,
    input      [3:0] digit_10,
    input      [3:0] digit_100,
    input      [3:0] digit_1000,
    input      [3:0] digit_dot_1,
    input      [3:0] digit_dot_10,
    input      [3:0] digit_dot_100,
    input      [3:0] digit_dot_1000,
    output reg [3:0] mux_out
);
    always @(*) begin
        case (sel)
            3'b000: mux_out = digit_1;
            3'b001: mux_out = digit_10;
            3'b010: mux_out = digit_100;
            3'b011: mux_out = digit_1000;
            3'b100: mux_out = digit_dot_1;
            3'b101: mux_out = digit_dot_10;
            3'b110: mux_out = digit_dot_100;
            3'b111: mux_out = digit_dot_1000;
        endcase
    end
endmodule

module digit_splitter #(
    parameter BIT_WIDTH = 7
) (
    input [BIT_WIDTH - 1:0] in_data,
    output [3:0] digit_1,
    output [3:0] digit_10,
    output [3:0] digit_100
);

    assign digit_1  = in_data % 10;
    assign digit_10 = (in_data / 10) % 10;
    assign digit_100 = (in_data / 100) % 10;
endmodule

module BCD (
    input [3:0] bcd,
    output reg [7:0] fnd_data
);

    always @(bcd) begin
        case (bcd)
            4'd0: fnd_data = 8'hC0;
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
