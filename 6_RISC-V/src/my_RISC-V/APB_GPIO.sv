`timescale 1ns / 1ps

module APB_GPIO (
    input               PCLK,
    input               PRESET,
    input        [31:0] PADDR,
    input        [31:0] PWDATA,
    input               PENABLE,
    input               PWRITE,
    input               PSEL,
    output logic [31:0] PRDATA,
    output logic        PREADY,
    input  logic [15:0] GPIO
);

    
    localparam [11:0] GPIO_CTRL_ADDR = 12'h0000;
    localparam [11:0] GPIO_ODATA_ADDR = 12'h0004;
    localparam [11:0] GPIO_IDATA_ADDR = 12'h0008;
    logic [15:0] GPIO_IDATA_REG, GPIO_ODATA_REG, GPIO_CTRL_REG;

    assign PREADY = (PENABLE & PSEL) ? 1'b1 : 1'b0;

    assign PRDATA = (PADDR[11:0] == GPIO_CTRL_ADDR) ? {16'h0000, GPIO_CTRL_REG} :
                    (PADDR[11:0] == GPIO_ODATA_ADDR) ? {16'h00000, GPIO_ODATA_REG} : 
                    (PADDR[11:0] == GPIO_IDATA_ADDR) ? {16'h0000, GPIO_IDATA_REG} : 32'hxxxx_xxxx;

    always_ff @(posedge PCLK, posedge PRESET) begin
        if (PRESET) begin
            GPIO_CTRL_REG  <= 16'h0000;
            GPIO_ODATA_REG <= 16'h0000;
            //GPIO_IDATA_REG <= 16'h0000;
        end else begin
            if (PREADY & PWRITE) begin
                case (PADDR[11:0])
                    GPIO_CTRL_ADDR:  GPIO_CTRL_REG  <= PWDATA[15:0];
                    GPIO_ODATA_ADDR: GPIO_ODATA_REG <= PWDATA[15:0];
                endcase
            end
        end
    end

    gpio U_GPIO (
        .ctrl(GPIO_CTRL_REG),
        .o_data(GPIO_ODATA_REG),
        .i_data(GPIO_IDATA_REG),
        .gpio(GPIO)
    );

endmodule


module gpio (
    input        [15:0] ctrl,
    input        [15:0] o_data,
    output logic [15:0] i_data,
    inout  logic [15:0] gpio
);

    genvar i;
    generate
        for (i = 0; i < 16; i++) begin
            assign gpio[i] = ctrl[i] ? o_data[i] : 1'bz;
            assign i_data[i] = ~ctrl[i] ? gpio[i] : 1'bz;
        end
    endgenerate

endmodule
