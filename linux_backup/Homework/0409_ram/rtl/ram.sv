`timescale 1ns/1ps

module ram(
    input logic         clk,
    input logic         wr,
    input logic  [7:0]  addr,
    input logic  [15:0] wdata,
    output logic [15:0] rdata
);
    logic [15:0] mem[0:2**8-1];

    always_ff @(posedge clk) begin
        if(wr) mem[addr] <= wdata;
        else rdata <= mem[addr];
    end
endmodule