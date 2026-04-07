module counter (
    input  logic       clk,
    input  logic       rst_n,
    input  logic       enable,
    output logic [3:0] count
);

    always_ff @(posedge clk, negedge rst_n) begin
        if(!rst_n) begin
            count <= 0;
        end else begin
            if(enable) count <= count + 1;
        end
    end
endmodule