interface uart_if (input logic clk, input logic rst);
    logic uart_rx;
    logic uart_tx;

    clocking drv_cb @(posedge clk);
        default input #1step output #0;
        output uart_rx;
        input uart_tx;
    endclocking

    clocking mon_cb @(posedge clk);
        default input #1step;
        input uart_rx;
        input uart_tx;
    endclocking

    modport mp_drv(clocking drv_cb, input clk, input rst);
    modport mp_mon(clocking mon_cb, input clk, input rst);

endinterface