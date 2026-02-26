`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/02/26 11:12:44
// Design Name: suminY9
// Module Name: SRAM
// Project Name: 20260226_SRAM
// Target Devices: Basys3
// Tool Versions: Vivado 2020.2
// Description: systemVerilog
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module SRAM (
    input              clk,
    input  logic       we,
    input  logic [3:0] addr,
    input  logic [7:0] wdata,
    output logic [7:0] rdata
);

    logic [7:0] sram[0:15]; //DEPTH = 16

    always_ff @(posedge clk) begin
        if(we)
            sram[addr] <= wdata;
    end

    always_comb begin
        rdata = sram[addr];
    end

endmodule
