`include "uvm_macros.svh"
import uvm_pkg::*;

`include "apb_ram_interface.sv"
`include "apb_ram_seq_item.sv"
`include "apb_ram_sequence.sv"
`include "apb_ram_driver.sv"
`include "apb_ram_monitor.sv"
`include "apb_ram_agent.sv"
`include "apb_ram_scoreboard.sv"
`include "apb_ram_coverage.sv"
`include "apb_ram_env.sv"
`include "apb_ram_test.sv"

module tb_apb();
    logic pclk;
    logic presetn;

    always #5 pclk = ~pclk;

    apb_if vif(pclk, presetn);

    apb_ram dut(
        .PCLK(pclk),
        .PRESET(presetn),
        .PADDR(vif.paddr),
        .PWRITE(vif.pwrite),
        .PENABLE(vif.penable),
        .PWDATA(vif.pwdata),
        .PSEL(vif.psel),
        .PRDATA(vif.prdata),
        .PREADY(vif.pready)
    );

    initial begin
        pclk = 0;
        presetn = 0;
        repeat(5) @(posedge pclk);
        presetn = 1;
    end

    initial begin
        uvm_config_db#(virtual apb_if)::set(null, "*", "vif", vif);
        run_test();
    end

    initial begin
        $fsdbDumpfile("novas.fsdb");
        $fsdbDumpvars(0, tb_apb, "+all");
    end
endmodule