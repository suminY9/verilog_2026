`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: suminY9
// 
// Create Date: 2026/03/05 12:41:39
// Design Name: RISC-V
// Module Name: dedicated_cpu0
// Project Name: 20260305_dedicated_cpu
// Target Devices: Basys3
// Tool Versions: Vivado 2020.2
// Description: 
// 
// Revision:
// Revision 0.01 - File Created
//////////////////////////////////////////////////////////////////////////////////


module dedicated_cpu0 (
    input        clk,
    input        rst,
    output [7:0] out
);

    logic asrcsel, aload, outsel, alt10;

    control_unit U_CONTROL_UNIT (
        .*
    );
    datapath U_DATAPATH (
        .*
    );
endmodule


module control_unit (
    input        clk,
    input        rst,
    input        alt10,
    output logic asrcsel,
    output logic aload,
    output logic outsel
);

    // FSM state
    typedef enum logic [4:0] {
        S0,
        S1,
        S2,
        S3,
        S4
    } state_t;
    state_t c_state, n_state;

    always_ff @(posedge clk, posedge rst) begin
        if (rst) begin
            c_state <= S0;
        end else begin
            c_state <= n_state;
        end
    end

    always_comb begin
        n_state = c_state;
        asrcsel = 0;
        aload   = 0;
        outsel  = 0;

        case (c_state)
            S0: begin
                asrcsel = 0;
                aload   = 0;
                outsel  = 0;
                n_state = S1;
            end
            S1: begin
                asrcsel = 0;
                aload   = 0;
                outsel  = 0;
                if(alt10) begin
                    n_state = S2;
                end else
                    n_state = S4;
            end
            S2: begin
                asrcsel = 0;
                aload   = 0;
                outsel  = 1;
                n_state = S3;
            end
            S3: begin
                asrcsel = 1;
                aload   = 1;
                outsel  = 0;
                n_state = S1;
            end
            S4: begin
                asrcsel = 0;
                aload   = 0;
                outsel  = 1;
                // halt
            end
        endcase
    end
endmodule


module datapath (
    input        clk,
    input        rst,
    input        asrcsel,
    input        aload,
    input        outsel,
    output [7:0] out,
    output       alt10
);

    logic [7:0] w_aluout, w_muxout, w_regout;

    assign out = (outsel) ? w_regout: 8'hz;

    mux_2x1 U_ASRCMUX (
        .a      (0),         // 0
        .b      (w_aluout),  // 1
        .asrcsel(asrcsel),
        .mux_out(w_muxout)
    );
    areg U_AREG (
        .clk(clk),
        .rst(rst),
        .reg_in(w_muxout),
        .aload(aload),
        .reg_out(w_regout)
    );
    alu U_ALU (
        .a(w_regout),
        .b(8'h1),
        .alu_out(w_aluout)
    );
    alt10_cmp U_ALT10 (
        .in_data(w_regout),
        .alt10(alt10)
    );
endmodule


module areg (
    input        clk,
    input        rst,
    input  [7:0] reg_in,
    input        aload,
    output [7:0] reg_out
);
    logic [7:0] a_reg;

    assign reg_out = a_reg;

    always_ff @(posedge clk, posedge rst) begin
        if (rst) begin
            a_reg <= 0;
        end else begin
            if (aload) begin
                a_reg <= reg_in;
            end
        end
    end
endmodule


module alu (
    input  [7:0] a,
    input  [7:0] b,
    output [7:0] alu_out
);
    assign alu_out = a + b;  // carry discard
endmodule


module mux_2x1 (
    input  [7:0] a,
    input  [7:0] b,
    input        asrcsel,
    output [7:0] mux_out
);
    assign mux_out = (asrcsel) ? b : a;
endmodule


module alt10_cmp (
    input [7:0] in_data,
    output      alt10
);
    assign alt10 = (in_data < 10);
endmodule