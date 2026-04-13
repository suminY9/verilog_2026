module baud_rate_gen #(
    parameter int BAUD_RATE = 9_600
) (
    input  logic clk,
    input  logic reset,
    output logic tick
);

    localparam int CLK_DIV = 100_000_000 / (BAUD_RATE * 16) - 1;
    localparam int CNT_W = $clog2(CLK_DIV + 1);

    logic [CNT_W-1:0] cnt;

    always_ff @(posedge clk or posedge reset) begin
        if(reset) begin
            cnt  <= 0;
            tick <= 1'b0;
        end else begin
            if(cnt == CLK_DIV) begin
                cnt  <= 0;
                tick <= 1'b1;
            end else begin
                cnt  <= cnt + 1;
                tick <= 1'b0;
            end
        end
    end
endmodule