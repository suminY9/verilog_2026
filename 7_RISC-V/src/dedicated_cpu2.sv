`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: suminY9
// 
// Create Date: 2026/03/06 17:51:14
// Design Name: RISC-V
// Module Name: dedicated_cpu2
// Project Name: 20260306_dedicated_cpu2
// Target Devices: Basys3
// Tool Versions: Vivado 2020.2
// Description: 
//  Homework. Design control unit datapath.
//  Conduct cumulative addtion(sum = sum + i) with 4-byte register in datapath.
// Revision:
// Revision 0.01 - File Created
//////////////////////////////////////////////////////////////////////////////////

//***** C code modeling ******/
//*    i = 0;
//*    sum = 0;
//*    while(i <= 10) {
//*    sum = sum + i;
//*    i = i + 1;
//*    out = sum;
//*    }
//*    halt;
//*    
//*    R3 = 1;
//*    R1 = R0 + R0; //i
//*    R2 = R0 + R0; //sum
//*    while(R1 <= 10){
//*    R2 = R2 + R1;
//*    R1 = R1 + R3;
//*    out = R2;
//*    }
//*    halt;
//***************************/

module dedicated_cpu2 (
    input        clk,
    input        rst,
    output [7:0] out
);
    logic lq10, rfsrcsel, we;
    logic [1:0] raddr1, raddr2, waddr;

    control_unit U_CONTROL_UNIT (.*);
    datapath U_DATAPATH (.*);
endmodule


module control_unit (
    input              clk,
    input              rst,
    input              lq10,
    output logic       rfsrcsel,
    output logic [1:0] raddr1,
    output logic [1:0] raddr2,
    output logic [1:0] waddr,
    output logic       we
);

    typedef enum logic [2:0] {
        S0,
        S1,
        S2,
        S3,
        S4,
        S5,
        S6
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
        n_state  = c_state;
        rfsrcsel = 0;
        we       = 0;

        case (c_state)
            S0: begin
                rfsrcsel = 0;
                raddr1   = 0;
                raddr2   = 0;
                waddr    = 2'd3;
                we       = 1;
                n_state  = S1;
            end
            S1: begin
                rfsrcsel = 1;
                raddr1   = 0;
                raddr2   = 0;
                waddr    = 2'd1;
                we       = 1;
                n_state  = S2;
            end
            S2: begin
                rfsrcsel = 1;
                raddr1   = 0;
                raddr2   = 0;
                waddr    = 2'd2;
                we       = 1;
                n_state  = S3;
            end
            S3: begin
                rfsrcsel = 0;
                raddr1   = 2'd1;
                raddr2   = 0;
                waddr    = 0;
                we       = 0;
                if(lq10) n_state = S4;
                else     n_state = S6;
            end
            S4: begin
                rfsrcsel = 1;
                raddr1   = 2'd1;
                raddr2   = 2'd2;
                waddr    = 2'd2;
                we       = 1;
                n_state  = S5;
            end
            S5: begin
                rfsrcsel = 1;
                raddr1   = 2'd1;
                raddr2   = 2'd3;
                waddr    = 2'd1;
                we       = 1;
                n_state  = S3;
            end
            S6: begin
                rfsrcsel = 0;
                raddr1   = 0;
                raddr2   = 0;
                waddr    = 0;
                we       = 0;
            end
        endcase
    end
endmodule


module datapath (
    input        clk,
    input        rst,
    input        rfsrcsel,
    input  [1:0] raddr1,
    input  [1:0] raddr2,
    input  [1:0] waddr,
    input        we,
    output [7:0] out,
    output       lq10
);

    logic [7:0] alu_out, mux_out, rdata1, rdata2;

    assign out = rdata1;

    mux_2x1 U_RFSRCMUX (
        .a(1),
        .b(alu_out),
        .sel(rfsrcsel),
        .mux_out(mux_out)
    );
    register U_REGISTER (
        .clk(clk),
        .rst(rst),
        .raddr1(raddr1),
        .raddr2(raddr2),
        .waddr(waddr),
        .we(we),
        .wdata(mux_out),
        .rdata1(rdata1),
        .rdata2(rdata2)
    );
    alu U_ALU (
        .rd0(rdata1),
        .rd1(rdata2),
        .alu_out(alu_out)
    );
    lq10 U_LQ10 (
        .in_data(rdata1),
        .lq10(lq10)
    );
endmodule


module register (
    input              clk,
    input              rst,
    input        [1:0] raddr1,
    input        [1:0] raddr2,
    input        [1:0] waddr,
    input              we,
    input        [7:0] wdata,
    output logic [7:0] rdata1,
    output logic [7:0] rdata2
);

    logic [7:0] in_reg[0:3];

    always_ff @(posedge clk, posedge rst) begin
        if (rst) begin
            in_reg[0] <= 0;
            in_reg[1] <= 0;
            in_reg[2] <= 0;
            in_reg[3] <= 0;
        end else begin
            rdata1 <= in_reg[raddr1];
            rdata2 <= in_reg[raddr2];
            if (we) in_reg[waddr] <= wdata;
        end
    end
endmodule


module alu (
    input  [7:0] rd0,
    input  [7:0] rd1,
    output [7:0] alu_out
);
    assign alu_out = rd0 + rd1;  // carry discard
endmodule


module mux_2x1 (
    input  [7:0] a,       // sel 0
    input  [7:0] b,       // sel 1
    input        sel,
    output [7:0] mux_out
);
    assign mux_out = (sel) ? b : a;
endmodule


module lq10 (
    input  [7:0] in_data,
    output       lq10
);
    assign lq10 = (in_data <= 10);
endmodule
