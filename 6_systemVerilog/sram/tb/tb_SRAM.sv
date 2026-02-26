`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/02/26 11:29:59
// Design Name: SRAM
// Module Name: tb_SRAM
// Project Name: 20260226_SRAM
// Target Devices: Basys3
// Tool Versions: Vivado 2020.2
// Description: systemVerilog
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

/****************** interface ******************/
interface ram_interface(input clk);
    logic       we;
    logic [3:0] addr;
    logic [7:0] wdata;
    logic [7:0] rdata;
endinterface

/****************** transaction *****************/
class transaction;

    rand bit we;
    rand bit [3:0] addr;
    rand bit [7:0] wdata;
    logic    [7:0] rdata;

    function void display(string name);
        $display("%t : [%s] we = %d, addr = %2h, wdata = %2h, rdata = %2h", $time, name, we, addr, wdata, rdata);
    endfunction

endclass //transaction

/****************** class *****************/
class generator;
    transaction tr;
    mailbox #(transaction) gen2drv_mbox;
    event gen_next_ev;

    function new(mailbox #(transaction) gen2drv_mbox, event gen_next_ev);
        this.gen2drv_mbox = gen2drv_mbox;
        this.gen_next_ev  = gen_next_ev;
    endfunction //new()

    task run(int run_count);
        repeat(run_count) begin
            tr = new();
            tr.randomize();
            gen2drv_mbox.put(tr);
            tr.display("gen");
            @(gen_next_ev);
        end
    endtask
endclass //generator

class driver;
    transaction tr;
    mailbox #(transaction) gen2drv_mbox;
    virtual ram_interface ram_if;

    function new(mailbox #(transaction) gen2drv_mbox,
                 virtual ram_interface ram_if);
        this.gen2drv_mbox = gen2drv_mbox;
        this.ram_if       = ram_if;
    endfunction //new()

    task run();
        forever begin
            gen2drv_mbox.get(tr);
            @(negedge ram_if.clk);
            ram_if.addr  = tr.addr;
            ram_if.wdata = tr.wdata;
            ram_if.we    = tr.we;
            tr.display("drv");
        end
    endtask //
endclass //driver

class monitor;
    transaction tr;
    mailbox #(transaction) mon2scb_mbox;
    virtual ram_interface ram_if;

    function new(mailbox #(transaction) mon2scb_mbox,
                 virtual ram_interface ram_if);
            this.mon2scb_mbox = mon2scb_mbox;
            this.ram_if       = ram_if;
    endfunction //new()

    task run();
        forever begin
            @(posedge ram_if.clk);
            #1;
            tr = new();
            tr.addr  = ram_if.addr;
            tr.we    = ram_if.we;
            tr.wdata = ram_if.wdata;
            tr.rdata = ram_if.rdata;
            mon2scb_mbox.put(tr);
            tr.display("mon");
        end
    endtask //
endclass //monitor

class scoreboard;
    transaction tr;
    mailbox #(transaction) mon2scb_mbox;
    event gen_next_ev;

    int pass_cnt, fail_cnt, try_cnt;

    function new(mailbox #(transaction) mon2scb_mbox, event gen_next_ev);
        this.mon2scb_mbox = mon2scb_mbox;
        this.gen_next_ev  = gen_next_ev;
    endfunction //new()

    task run();
        logic [7:0] expected_ram[0:15];

        pass_cnt = 0;
        fail_cnt = 0;
        try_cnt  = 0;

        forever begin
            mon2scb_mbox.get(tr);
            try_cnt++;
            tr.display("scb");

            // pass, fail
            if(tr.we) begin
                expected_ram[tr.addr] = tr.wdata;
                $display("%2h", expected_ram[tr.addr]);
            end else begin
                if(expected_ram[tr.addr] === tr.rdata) begin    // '===' x까지 비교
                    $display("Pass");
                    pass_cnt++;
                end else begin
                    $display("Fail: expected data = %2h, rdata = %2h",
                             expected_ram[tr.addr], tr.rdata);
                    fail_cnt++;
                end
            end

            // next stimulus
            ->gen_next_ev;
        end
    endtask
endclass //scoreboard

class environment;
    generator  gen;
    driver     drv;
    monitor    mon;
    scoreboard scb;

    mailbox #(transaction) gen2drv_mbox;
    mailbox #(transaction) mon2scb_mbox;

    event gen_next_ev;

    function new(virtual ram_interface ram_if);
        gen2drv_mbox = new;
        mon2scb_mbox = new;
        gen = new(gen2drv_mbox, gen_next_ev);
        drv = new(gen2drv_mbox, ram_if);
        mon = new(mon2scb_mbox, ram_if);
        scb = new(mon2scb_mbox, gen_next_ev);
    endfunction  //new()

    task run();
        fork
            gen.run(10);
            drv.run();
            mon.run();
            scb.run();
        join_any
        #10;

        // report
        $display("_____________________________");
        $display("**  8-bit register verifi  **");
        $display("*****************************");
        $display("** total try count = %3d   **", scb.try_cnt);
        $display("** pass count = %3d        **", scb.pass_cnt);
        $display("** fail count = %3d        **", scb.fail_cnt);
        $display("*****************************");

        $stop;
    endtask  //
endclass //environment

/************** testbench module **************/
module tb_SRAM ();

    reg clk = 0;
    ram_interface ram_if(clk);
    environment env;

    SRAM #(
        .DEPTH(16)
    )dut (
        .clk(clk),
        .we(ram_if.we),
        .addr(ram_if.addr),
        .wdata(ram_if.wdata),
        .rdata(ram_if.rdata)
    );

    always #5 clk = ~clk;

    initial begin
        env = new(ram_if);
        env.run();
    end

endmodule
