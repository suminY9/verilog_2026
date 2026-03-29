`timescale 1ns / 1ps

module APB_FND (
    input               PCLK,
    input               PRESET,
    input        [31:0] PADDR,
    input        [31:0] PWDATA,
    input               PENABLE,
    input               PWRITE,
    input               PSEL,
    output logic [31:0] PRDATA,
    output logic        PREADY,
    output       [ 3:0] fnd_digit,
    output       [ 7:0] fnd_data
);

    logic [31:0] fnd_data_reg;

    assign PREADY = (PENABLE & PSEL) ? 1'b1 : 1'b0;
    assign PRDATA = fnd_data_reg;

    always_ff @(posedge PCLK, posedge PRESET) begin
        if (PRESET) begin
            fnd_data_reg <= 32'h0;
        end else if (PREADY & PWRITE) begin
            fnd_data_reg <= PWDATA;
        end
    end

    fnd_controller U_FND_CTRL (
        .clk(PCLK),
        .reset(PRESET),
        .fnd_in_data(fnd_data_reg),
        .fnd_digit(fnd_digit),
        .fnd_data(fnd_data)
    );
endmodule


module fnd_controller (
    input         clk,
    input         reset,
    input  [31:0] fnd_in_data,
    output [ 3:0] fnd_digit,
    output [ 7:0] fnd_data
);

    logic [2:0] w_digit_sel;
    logic [3:0] w_digit_1, w_digit_10, w_digit_100, w_digit_1000;
    logic [3:0] w_mux_out_digitsel;

    clk_div U_CLK_DIV (
        .clk(clk),  // 100MHz
        .reset(reset),
        .o_1khz(w_clk_out)  // 1KHz
    );
    counter_8 U_CNT8 (
        .clk(w_clk_out),
        .reset(reset),
        .count_r(w_digit_sel)
    );
    digit_splitter #(
        .BIT_WIDTH(32)
    ) U_DIGIT_SPLITTER (
        .in_data(fnd_in_data),
        .digit_1(w_digit_1),
        .digit_10(w_digit_10),
        .digit_100(w_digit_100),
        .digit_1000(w_digit_1000)
    );
    mux_8x1 U_MUX_DIGIT_SEL (
        .sel(w_digit_sel),
        .digit_1(w_digit_1),
        .digit_10(w_digit_10),
        .digit_100(w_digit_100),
        .digit_1000(w_digit_1000),
        .digit_dot_1(w_digit_1),
        .digit_dot_10(w_digit_10),
        .digit_dot_100(w_digit_100),
        .digit_dot_1000(w_digit_1000),
        .mux_out(w_mux_out_digitsel)
    );
    dec_2x4 U_DEC_2x4 (
        .din (w_digit_sel[1:0]),
        .dout(fnd_digit)
    );
    bcd U_BCD (
        .bcd(w_mux_out_digitsel),
        .fnd_data(fnd_data)
    );
endmodule


/********SUB MODULE********/
module clk_div (
    input        clk,    // 100MHz
    input        reset,
    output logic o_1khz  // 1KHz
);
    logic [$clog2(100_000):0] clk_cnt;  // reg [16:0]

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
    input              clk,
    input              reset,
    output logic [2:0] count_r
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
    input        [1:0] din,  // digit_sel
    output logic [3:0] dout  // fnd_digit
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


module digit_splitter #(
    parameter BIT_WIDTH = 16
) (
    input  [BIT_WIDTH-1:0] in_data,
    output [          3:0] digit_1,
    output [          3:0] digit_10,
    output [          3:0] digit_100,
    output [          3:0] digit_1000
);
    assign digit_1    = in_data[3:0];
    assign digit_10   = in_data[7:4];
    assign digit_100  = in_data[11:8];
    assign digit_1000 = in_data[15:12];
endmodule


module mux_8x1 (
    input        [2:0] sel,
    input        [3:0] digit_1,
    input        [3:0] digit_10,
    input        [3:0] digit_100,
    input        [3:0] digit_1000,
    input        [3:0] digit_dot_1,
    input        [3:0] digit_dot_10,
    input        [3:0] digit_dot_100,
    input        [3:0] digit_dot_1000,
    output logic [3:0] mux_out
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


module bcd (
    input        [3:0] bcd,
    output logic [7:0] fnd_data
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
            4'd10: fnd_data = 8'h88;
            4'd11: fnd_data = 8'h83;
            4'd12: fnd_data = 8'hc6;
            4'd13: fnd_data = 8'ha1;
            4'd14: fnd_data = 8'h86;
            4'd15: fnd_data = 8'h8e;
            default: fnd_data = 8'hFF;
        endcase
    end
endmodule
