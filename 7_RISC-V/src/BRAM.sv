`timescale 1ns / 1ps

module BRAM (
    input               PCLK,
    input        [31:0] PADDR,
    input        [31:0] PWDATA,
    input               PENABLE,
    input               PWRITE,
    input               PSEL,
    output logic [31:0] PRDATA,
    output logic        PREADY
);

    logic [31:0] bmem[0:1023];  // 1024 * 4byte : 4K

    assign PREADY = (PENABLE & PSEL) ? 1'b1 : 1'b0;

    always_ff @(posedge PCLK) begin
        if (PSEL & PENABLE & PWRITE) begin
            bmem[PADDR[11:2]] <= PWDATA;
        end
    end
    
    assign PRDATA = bmem[PADDR[11:2]];
endmodule
