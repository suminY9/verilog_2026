`timescale 1ps/1ps
`include "uvm_macros.svh"
import uvm_pkg::*;

`include "ram_interface.sv"
`include "ram_seq_item.sv"
`include "ram_sequence.sv"
`include "ram_driver.sv"
`include "ram_monitor.sv"
`include "ram_agent.sv"
`include "ram_scoreboard.sv"
//`include "ram_coverage.sv"
`include "ram_env.sv"
`include "ram_test.sv"

module tb_ram();
    logic clk;
    initial clk = 0;
    always #5 clk = ~clk;

    ram_interface r_if(clk);

    ram dut(
        .clk(clk),
        .wr(r_if.wr),
        .addr(r_if.addr),
        .wdata(r_if.wdata),
        .rdata(r_if.rdata)
    );

    initial begin
        uvm_config_db#(virtual ram_interface)::set(null, "*", "r_if", r_if);
        run_test("ram_base_test");
    end
endmodule