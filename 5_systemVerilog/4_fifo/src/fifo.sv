`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/02/26 16:32:36
// Design Name: suminY9
// Module Name: fifo
// Project Name: 20260226_fifo
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


module fifo (
    input              wclk,
    input              rclk,
    input              rst,
    input  logic       we,
    input  logic       re,
    input  logic [7:0] wdata,
    output logic [7:0] rdata,
    output logic       full,
    output logic       empty
);



endmodule


module register_file (
    input  logic       we,
    input  logic [3:0] waddr,
    input  logic [7:0] wdata,
    input  logic [3:0] raddr,
    output logic [7:0] rdata
);
endmodule



module control_unit (
    inout  logic       we,
    input  logic       re,
    output logic [3:0] wptr,
    output logic [3:0] rptr,
    output logic       full,
    output logic       empty
);



endmodule
