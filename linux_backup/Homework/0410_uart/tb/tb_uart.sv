`include "uvm_macros.svh"
import uvm_pkg::*;

`include "uart_interface.sv"
`include "uart_seq_item.sv"
`include "uart_sequence.sv"
`include "uart_driver.sv"
`include "uart_monitor.sv"
`include "uart_agent.sv"
`include "uart_scoreboard.sv"
`include "uart_coverage.sv"
`include "uart_env.sv"
`include "uart_test.sv"

module tb_uart();
    logic clk;
    logic rst;

    always #5 clk = ~clk;

    uart_if uif(clk, rst);

    uart dut(
        .clk(clk),
        .rst(rst),
        .uart_rx(uif.uart_rx),
        .uart_tx(uif.uart_tx)
    );

    initial begin
        clk = 0;
        rst = 1;
        repeat(5) @(posedge clk);
        rst = 0;
    end

    initial begin
        uvm_config_db#(virtual uart_if)::set(null, "*", "uif", uif);
        run_test("uart_rand_test");
    end

    initial begin
        $fsdbDumpfile("novas.fsdb");
        $fsdbDumpvars(0, tb_uart, "+all");
    end
endmodule