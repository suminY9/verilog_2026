`timescale 1ns / 1ps

module top_axi4_lite(
    input  logic        ACLK,
    input  logic        ARESETn,
    input  logic        transfer,
    output logic        ready,
    input  logic [31:0] addr,
    input  logic [31:0] wdata,
    input  logic        write,
    output logic [31:0] rdata
    );

    // AW channel
    logic [31:0] AWADDR;
    logic        AWVALID;
    logic        AWREADY;
    // W channel
    logic [31:0] WDATA;
    logic        WVALID;
    logic        WREADY;
    // B channel
    logic [ 1:0] BRESP;
    logic        BVALID;
    logic        BREADY;
    // AR channel
    logic [31:0] ARADDR;
    logic        ARVALID;
    logic        ARREADY;
    // R channel
    logic [31:0] RDATA;
    logic        RVALID;
    logic        RREADY;
    logic [ 1:0] RRESP;

    axi4_lite_master U_MASTER ( .* );
    axi4_lite_slave U_SLAVE ( .* );
endmodule
