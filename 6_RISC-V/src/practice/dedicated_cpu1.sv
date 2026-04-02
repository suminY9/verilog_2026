`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/03/06 10:21:32
// Design Name: 
// Module Name: dedicated_cpu1
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module dedicated_cpu1 (
    input        clk,
    input        rst,
    output [7:0] out
);

    logic isrcsel, sumsrcsel, iload, sumload, alusrcsel, outload, ilq10;

    control_unit U_CONTROL_UNIT (.*);

    datapath U_DATAPATH (.*);

endmodule

module control_unit (
    input        clk,
    input        rst,
    input        ilq10,
    output logic isrcsel,
    output logic sumsrcsel,
    output logic iload,
    output logic sumload,
    output logic alusrcsel,
    output logic outload
);

    typedef enum logic [2:0] {
        S0,
        S1,
        S2,
        S3,
        S4,
        S5
    } state_t;

    state_t c_state, n_state;

    always_ff @(posedge clk, posedge rst) begin
        if (rst) begin
            c_state <= S0;
        end else begin
            c_state <= n_state;
        end
    end

    // next, output
    always_comb begin
        n_state   = c_state;
        isrcsel   = 0;
        sumsrcsel = 0;
        iload     = 0;
        sumload   = 0;
        alusrcsel = 0;
        outload   = 0;

        case (c_state)
            S0: begin
                isrcsel   = 0;
                sumsrcsel = 0;
                iload     = 1;
                sumload   = 1;
                alusrcsel = 0;
                outload   = 0;
                n_state   = S1;
            end
            S1: begin
                isrcsel   = 0;
                sumsrcsel = 0;
                iload     = 0;
                sumload   = 0;
                alusrcsel = 0;
                outload   = 0;
                if (ilq10) n_state = S2;
                else n_state = S5;
            end
            S2: begin
                isrcsel   = 0;
                sumsrcsel = 1;
                iload     = 0;
                sumload   = 1;
                alusrcsel = 0;
                outload   = 0;
                n_state   = S3;
            end
            S3: begin
                isrcsel   = 1;
                sumsrcsel = 0;
                iload     = 1;
                sumload   = 0;
                alusrcsel = 1;
                outload   = 0;
                n_state   = S4;
            end
            S4: begin
                isrcsel   = 0;
                sumsrcsel = 0;
                iload     = 0;
                sumload   = 0;
                alusrcsel = 0;
                outload   = 1;
                n_state   = S1;
            end
            S5: begin
                isrcsel   = 0;
                sumsrcsel = 0;
                iload     = 0;
                sumload   = 0;
                alusrcsel = 0;
                outload   = 0;
            end
        endcase
    end
endmodule


module datapath (
    input        clk,
    input        rst,
    input        isrcsel,
    input        sumsrcsel,
    input        iload,
    input        sumload,
    input        alusrcsel,
    input        outload,
    output       ilq10,
    output [7:0] out
);

    logic [7:0] ireg_src_data, sumreg_src_data, alu_src_data;
    logic [7:0] ireg_out, sumreg_out, alu_out;

    register U_OUTREG (
        .clk(clk),
        .rst(rst),
        .load(outload),
        .in_data(sumreg_out),
        .out_data(out)
    );

    mux_2x1 U_IREG_SRC_MUX (
        .a(0),
        .b(alu_out),
        .sel(isrcsel),
        .mux_out(ireg_src_data)
    );
    register U_IREG (
        .clk(clk),
        .rst(rst),
        .load(iload),
        .in_data(ireg_src_data),
        .out_data(ireg_out)
    );
    lqt10 U_LQT10 (
        .in_data(ireg_out),
        .ilq10(ilq10)
    );

    mux_2x1 U_SUMREG_SRC_MUX (
        .a(0),
        .b(alu_out),
        .sel(sumsrcsel),
        .mux_out(sumreg_src_data)
    );
    register U_SUMREG (
        .clk(clk),
        .rst(rst),
        .load(sumload),
        .in_data(sumreg_src_data),
        .out_data(sumreg_out)
    );

    mux_2x1 U_ALU_SRC_MUX (
        .a(sumreg_out),
        .b(1),
        .sel(alusrcsel),
        .mux_out(alu_src_data)
    );
    alu U_ALU (
        .a(ireg_out),
        .b(alu_src_data),
        .alu_out(alu_out)
    );
endmodule


module register (
    input              clk,
    input              rst,
    input              load,
    input        [7:0] in_data,
    output logic [7:0] out_data
);

    always_ff @(posedge clk, posedge rst) begin
        if (rst) begin
            out_data <= 0;
        end else begin
            if(load) out_data <= in_data;
        end
    end
endmodule


module alu (
    input [7:0] a,  // from ireg
    input [7:0] b,  // from sumreg
    output [7:0] alu_out
);
    assign alu_out = a + b;
endmodule


module mux_2x1 (
    input  [7:0] a,       // sel 0
    input  [7:0] b,       // sel 1
    input        sel,
    output [7:0] mux_out
);
    assign mux_out = (sel) ? b : a;
endmodule


module lqt10 (
    input  [7:0] in_data,
    output       ilq10
);
    assign ilq10 = ((in_data) <= 10);
endmodule
