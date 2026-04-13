module tb_uart ();
    logic       clk;
    logic       reset;
    logic [7:0] tx_data;
    logic       tx_start;
    logic       tx;
    logic       tx_busy;

uart #(
    .BAUD_RATE(9600)
) dut (
    .clk(clk),
    .reset(reset),
    .tx_data(tx_data),
    .tx_start(tx_start),
    .tx(tx),
    .tx_busy(tx_busy)
);

    always #5 clk = ~clk;

    task send_data(logic [7:0] data);
        tx_data = data;
        tx_start = 1'b1;
        @(posedge clk);
        tx_start = 1'b0;
        @(posedge clk);
        wait(tx_busy == 1'b0);
        @(posedge clk);
    endtask

    initial begin
        clk = 0;
        reset = 1 ;
        repeat(3) @(posedge clk);
        reset = 0;
        repeat(3) @(posedge clk);

        send_data(8'haa);
        send_data(8'h55);
        send_data(8'h11);
        send_data(8'hff);
        #30;
        $finish;
    end

    initial begin
        $fsdbDumpfile("novas.fsdb");
        $fsdbDumpvars(0, tb_uart, "+all");
    end
endmodule