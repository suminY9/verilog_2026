`timescale 1ns / 1ps

module GPIO_practice (
    input               PCLK,
    input               PRESET,
    input        [31:0] PADDR,
    input        [ 7:0] PWDATA,
    input               PWRITE,
    input               PENABLE,
    input               PSEL,
    output logic        PREADY,
    output logic        GPO0,
    output logic        GPO1,
    output logic        GPO2,
    output logic        GPO3,
    output logic        GPO4,
    output logic        GPO5,
    output logic        GPO6,
    output logic        GPO7
);

    logic [7:0] GPO_OREG;
    logic we;

    assign we = PSEL && PENABLE && PWRITE;
    assign PREADY = (PENABLE & PSEL) ? 1'b1 : 1'b0;

    always_ff @(posedge PCLK, posedge PRESET) begin
        if(PRESET) begin
            GPO_OREG <= 8'b0;
        end else begin
            if(PADDR == 32'h2000_0000) begin
                if(we) begin
                    GPO_OREG <= PWDATA;
                end
            end
        end
    end

    assign {GPO7, GPO6, GPO5, GPO4, GPO3, GPO2, GPO1, GPO0} = GPO_OREG;

endmodule
