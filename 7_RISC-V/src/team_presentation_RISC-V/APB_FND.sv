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
    output logic [ 3:0] fnd_digit,
    output logic [ 7:0] fnd_data
);

    logic [15:0] FND_DATA_REG;

    assign PREADY = (PENABLE & PSEL) ? 1'b1 : 1'b0;
    assign PRDATA = {16'h0000, FND_DATA_REG};

    always_ff @(posedge PCLK, posedge PRESET) begin
        if (PRESET) begin
            FND_DATA_REG <= 16'h0000;
        end else begin
            if (PREADY & PWRITE) begin
                if (PADDR[11:0] == 12'h004)  
                    FND_DATA_REG <= PWDATA[15:0];
            end
        end
    end

    fnd_controller U_FND_CORE (
        .clk      (PCLK),
        .reset    (PRESET),
        .sum      (FND_DATA_REG[13:0]),
        .fnd_digit(fnd_digit),
        .fnd_data (fnd_data)
    );

endmodule
