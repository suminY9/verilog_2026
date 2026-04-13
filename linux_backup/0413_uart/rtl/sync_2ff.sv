module sync_ff (
    input  logic clk,
    input  logic reset,
    input  logic async_in,
    output logic sync_out
);

    logic ff1, ff2;

    assign sync_out = ff2;

    always_ff @(posedge clk or posedge reset) begin
        if(reset) begin
            ff1 <= 1'b1;
        end else begin
            ff1 <= async_in;
            ff2 <= ff1;
        end
    end

endmodule