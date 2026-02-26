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

    task display(string name);
        $display("%t : [%s] we = %d, addr = %2h, wdata = %2h, rdata = %2h", $time, we, name, addr, wdata, rdata);
    endtask

endclass //transaction

/************** class **************/

class generator;
    transaction tr;
    mailbox #(transaction) gen2drv_mbox;
    event gen_next_ev;

    function new(mailbox #(transaction) gen2drv_mbox, event gen_next_ev);
        this.gen2drv_mbox = gen2drv_mbox;
        tihs.gen_next_ev  = gen_next_ev;
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

    task preset(input clk);
        // reset
        clk = 0;
        ram_if.we = 0;        
    endtask //

    task run();
        forever begin
            gen2drv_mbox.get(tr);
            ram_if.we    = tr.we;
            ram_if.wdata = tr.wdata;
            //ram_if.rdata = tr.rdata;
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
            tr = new();
            #1;
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
    memory mem;
    mailbox #(transaction) mon2scb_mbox;
    event gen_next_ev;

    int pass_cnt, fail_cnt, try_cnt;
    bit [7:0] read_data;

    function new(mailbox #(transaction) mon2scb_mbox, event gen_next_ev);
        this.mon2scb_mbox = mon2scb_mbox;
        this.gen_next_ev  = gen_next_ev;
    endfunction //new()

    task run();
        pass_cnt = 0;
        fail_cnt = 0;
        try_cnt  = 0;

        forever begin
            mon2scb_mbox.get(tr);
            try_cnt++;

            if(tr.we) begin
                mem.write();
            end else begin
                if(tr.wdata == mem.read(read_data))
                $display("%t : Pass : we = %d, addr = %2h, wdata = %2h, rdata = %2h",
                          $time, tr.we, tr.addr, tr.wdata, tr.rdata);
                pass_cnt++;
            end else begin
                $display("%t : Fail : we = %d, addr = %2h, wdata = %2h, rdata = %2h",
                          $time, tr.we, tr.addr, tr.wdata, tr.rdata);
                fail_cnt++;
            end
            tr.display("scb");
            ->gen_next_ev;
        end
    endtask
endclass //scoreboard

class memory;
    transaction tr;
    mailbox #(transaction) mon2scb_mbox;

    logic [3:0] mem[0:15];

    function new(mailbox #(transaction) mon2scb_mbox);
        this.mon2scb_mbox = mon2scb_mbox;        
    endfunction //new()

    task write();
        mon2scb_mbox.get(tr);
        mem[tr.addr] = tr.wdata;
    endtask

    task read(output [7:0] read_data);
        read_data = mem[tr.addr];
    endtask
endclass //memory

class environment;
    generator  gen;
    driver     drv;
    monitor    mon;
    scoreboard scb;

    mailbox #(transaction) gen2drv_mbox;
    mailbox #(transaction) mon2scb_mbox;

    event gen_next_ev;

    function new(virtual register_interface register_if);
        gen2drv_mbox = new;
        mon2scb_mbox = new;
        gen = new(gen2drv_mbox, gen_next_ev);
        drv = new(gen2drv_mbox, register_if);
        mon = new(mon2scb_mbox, register_if);
        scb = new(mon2scb_mbox, gen_next_ev);
    endfunction  //new()

    task run();
        drv.preset();
        fork
            gen.run(10);
            drv.run();
            mon.run();
            scb.run();
        join_any
        #20;

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
    ) dut (
        .clk(clk),
        .we(ram_if.we),
        .addr(ram_if.addr),
        .wdata(ram_if.wdata),
        .rdata(ram_if.rdata)
    );

    always #5 clk = ~clk;

endmodule
