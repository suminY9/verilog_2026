module uart #(
    parameter int BAUD_RATE = 9600
) (
    input  logic       clk,
    input  logic       reset,
    // tx port
    input  logic [7:0] tx_data,
    input  logic       tx_start,
    output logic       tx,
    output logic       tx_busy,
    // rx port
    input  logic       rx,
    output logic [7:0] rx_data,
    output logic       rx_valid
);
    logic tick;
    logic rx_sync;

baud_rate_gen #(
    .BAUD_RATE(BAUD_RATE)
) u_brg(
    .clk(clk),
    .reset(reset),
    .tick(tick)
);
uart_tx u_uart_tx(
    .clk(clk),
    .reset(reset),
    .tick(tick),
    .tx_data(tx_data),
    .tx_start(tx_start),
    .tx(tx),
    .tx_busy(tx_busy)
);
sync_ff u_sync_rx (
    .clk(clk),
    .reset(reset),
    .async_in(rx),
    .sync_out(rx_sync)
);
uart_rx u_uart_rx (
    .clk(clk),
    .reset(reset),
    .tick(tick),
    .rx(rx_sync),
    .rx_data(rx_data),
    .rx_valid(rx_valid)
);
endmodule