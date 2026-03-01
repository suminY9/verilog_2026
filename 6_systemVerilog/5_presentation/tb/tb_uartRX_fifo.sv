`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: suminY9
// Create Date: 2026/02/28 17:45:47
// Design Name: top
// Module Name: tb_top
// Project Name: sv_verification
// Target Devices: Basys3
// Tool Versions: Vivado 2020.2
// Description:
//  Verificate conduction of uart+fifo
//  random input uart -> monitor fifo pop data
// Revision:
//  Revision 0.01 - File Created
//////////////////////////////////////////////////////////////////////////////////

/******************* interface *******************/
interface top_interface (
    input logic clk
);
    logic       rst;
    logic [3:0] sw;
    logic       btn_u;
    logic       btn_d;
    logic       btn_r;
    logic       btn_l;
    logic       uart_rx;
    logic       uart_tx;
    logic [3:0] fnd_digit;
    logic [7:0] fnd_data;
    logic [3:0] LED;
endinterface


/****************** transaction *****************/
class transaction;
    rand bit [7:0] data_in;     // input to UART
    bit      [7:0] data_out;    // output from RX_FIFO

    // only generate 'u'=8'h75, 'd'=8'h64, 'r'=8'h72, 'l'=8'h6c, 's'=8'h93
    constraint gen_ASCii{
        data_in inside {8'h75, 8'h64, 8'h72, 8'h6c, 8'h73};
    }
endclass


/******************** class *******************/
class generator;
    transaction tr;
    mailbox #(transaction) gen2drv_mbox;
    event gen_next_ev;

    function new(mailbox #(transaction) gen2drv_mbox, event gen_next_ev);
        this.gen2drv_mbox = gen2drv_mbox;
        this.gen_next_ev  = gen_next_ev;
    endfunction

    task run(int run_count);
        repeat (run_count) begin
            tr = new;
            tr.randomize();
            $display("%t: [gen] generate uart_rx input: %c(0x%H)",
                          $time, tr.data_in, tr.data_in);
            gen2drv_mbox.put(tr);
            @(gen_next_ev);
        end
    endtask
endclass


class driver;
    transaction tr;
    mailbox #(transaction) gen2drv_mbox;
    mailbox #(transaction) gen2scb_mbox;
    virtual top_interface top_if;

    // UART baudrate: 9600bps -> 104,167ns
    realtime bit_time = 104167ns;

    function new(mailbox #(transaction) gen2drv_mbox,
                 mailbox #(transaction) gen2scb_mbox,
                 virtual top_interface top_if);
        this.gen2drv_mbox = gen2drv_mbox;
        this.gen2scb_mbox = gen2scb_mbox;
        this.top_if       = top_if;        
    endfunction

    task preset();
        tr = new;
        top_if.rst = 1;
        top_if.uart_rx = 1; // UART_RX state: IDLE
        repeat(10) @(posedge top_if.clk) // wait 10 clk cycle
        top_if.rst = 0; // end reset
    endtask

    task send_ASCii(bit [7:0] data);
        top_if.uart_rx = 0; // start bit: LOW
        #(bit_time);

        // send ASCii 8-bit
        for(int i = 0; i < 8; i++) begin
            top_if.uart_rx = data[i];
            #(bit_time);
        end

        top_if.uart_rx = 1; // stop bit: HIHG
        #(bit_time);

        // delay for next send
        #(bit_time);
        #(bit_time);
    endtask 

    task run();
        forever begin
            gen2drv_mbox.get(tr);
            gen2scb_mbox.put(tr); // send copy gen2drv_mbox to scb

            @(posedge top_if.clk); // wait 1 clk cycle
            #1;                    // delay 1ns for seperate timing from clk
            send_ASCii(tr.data_in);
        end
    endtask
endclass


class monitor;
    transaction tr;
    mailbox #(transaction) mon2scb_mbox;
    virtual top_interface top_if;

    function new(mailbox #(transaction) mon2scb_mbox,
                 virtual top_interface top_if);
        this.mon2scb_mbox = mon2scb_mbox;
        this.top_if       = top_if;        
    endfunction //new()

    task run();
        forever begin
            wait(tb_top.dut.U_TOP_UART.fifo_rx.pop == 1); // wait until detect rx_fifo pop rising edge
            tr = new;
            tr.data_out = tb_top.dut.U_TOP_UART.fifo_rx.pop_data; // rx_fifo pop data from top module
            mon2scb_mbox.put(tr);
            wait(tb_top.dut.U_TOP_UART.fifo_rx.pop == 0); // wait until detect rx_fifo pop falling edge
        end
    endtask
endclass


class scoreboard;
    transaction tr;
    mailbox #(transaction) mon2scb_mbox;
    event gen_next_ev;

    function new(mailbox #(transaction) mon2scb_mbox,
                 event gen_next_ev);
        this.mon2scb_mbox = mon2scb_mbox;
        this.gen_next_ev  = gen_next_ev;
    endfunction //new()

    task run(mailbox #(transaction) gen2scb_mbox);
        transaction exp_tr; // expert data
        transaction act_tr; // actual data
        forever begin
            gen2scb_mbox.get(exp_tr); // expert data from drv
            mon2scb_mbox.get(act_tr); // actual data from mon

            // pass/fail
            if(exp_tr.data_in == act_tr.data_out) begin
                $display("%t: [scb] PASS: uart_rx input: %c(0x%H), fifo_rx pop: 0x%H",
                          $time, exp_tr.data_in, exp_tr.data_in, act_tr.data_out);
            end else begin
                $display("%t: [scb] FAIL: uart_rx input: %c(0x%H), fifo_rx pop: 0x%H",
                          $time, exp_tr.data_in, exp_tr.data_in, act_tr.data_out);
            end

            ->gen_next_ev;
        end
    endtask
endclass


class environment;
    generator   gen;
    driver      drv;
    monitor     mon;
    scoreboard  scb;

    transaction tr;
    mailbox #(transaction) gen2drv_mbox;
    mailbox #(transaction) mon2scb_mbox;
    mailbox #(transaction) gen2scb_mbox;
    event gen_next_ev;
    virtual top_interface top_if;

    function new(virtual top_interface top_if);
        this.top_if = top_if;
        gen2drv_mbox = new;
        mon2scb_mbox = new;
        gen2scb_mbox = new;
        gen = new(gen2drv_mbox, gen_next_ev);
        drv = new(gen2drv_mbox, gen2scb_mbox, top_if);
        mon = new(mon2scb_mbox, top_if);
        scb = new(mon2scb_mbox, gen_next_ev);
    endfunction

    task run(int count);
        fork
            gen.run(count);
            drv.run();
            mon.run();
            scb.run(gen2scb_mbox);
        join_any
    endtask
endclass


/************** testbench module **************/
module tb_top();
    environment env;

    logic clk;
    top_interface top_if(clk);

    top dut(
        .clk(clk),
        .rst(top_if.rst),
        .sw(top_if.sw),
        .btn_u(top_if.btn_u),
        .btn_d(top_if.btn_d),
        .btn_r(top_if.btn_r),
        .btn_l(top_if.btn_l),
        .uart_rx(top_if.uart_rx),
        .uart_tx(top_if.uart_tx),
        .fnd_digit(top_if.fnd_digit),
        .fnd_data(top_if.fnd_data),
        .LED(top_if.LED)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0;

        env = new(top_if);
        env.drv.preset;
        env.run(10);
        #20ms;
        $stop;
    end

endmodule
