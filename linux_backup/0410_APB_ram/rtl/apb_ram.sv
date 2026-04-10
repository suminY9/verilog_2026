module apb_ram(
    // Global signal
    input logic PCLK,
    input logic PRESET,
    // APB Interface signals
    input  logic [7:0]  PADDR,
    input  logic        PWRITE,
    input  logic        PENABLE,
    input  logic [31:0] PWDATA,
    input  logic        PSEL,
    output logic [31:0] PRDATA,
    output logic        PREADY
);
    logic [31:0] mem[0:2**6-1];

    assign PREADY = 1;

    always_ff @(posedge PCLK) begin
        if(PSEL & PENABLE & PWRITE) begin
            mem[PADDR[7:2]] <= PWDATA;
        end
    end

    assign PRDATA = mem[PADDR[7:2]];

endmodule