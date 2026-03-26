`timescale 1ns / 1ps

module APB_GPI (
    input               PCLK,
    input               PRESET,
    input        [31:0] PADDR,
    input               PENABLE,
    input               PWRITE,
    input               PSEL,
    input        [15:0] GPI_IN,
    output logic [31:0] PRDATA,
    output logic        PREADY
);

    localparam [11:0] GPI_CTRL_ADDR  = 12'h000;
    localparam [11:0] GPI_IDATA_ADDR = 12'h004;
    logic [15:0] GPI_IDATA_REG, GPI_CTRL_REG;

    assign PREADY = (PENABLE & PSEL) ? 1'b1 : 1'b0;

    //assign PRDATA = (PADDR[11:0] == GPI_CTRL_ADDR) ? GPI_CTRL_REG :
    //                (PADDR[11:0] == GPI_IDATA_ADDR) ? GPI_IDATA_REG : 16'hxxxx;

    always_ff @(posedge PCLK, posedge PRESET) begin
        if(PRESET) begin
            GPI_IDATA_REG <= 16'h0000;
        end else begin
            GPI_IDATA_REG <= GPI_IN; // data sampling every clk
        end
    end

    always_comb begin
        if(PREADY & !PWRITE) begin
            case(PADDR[11:0])
                GPI_CTRL_ADDR:  PRDATA = {16'h0, GPI_CTRL_REG};
                GPI_IDATA_ADDR: PRDATA = {16'h0, GPI_IDATA_REG};
            endcase
        end else begin
            PRDATA = 32'hxxxx_xxxx;
        end
    end

endmodule
