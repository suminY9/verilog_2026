`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: sumniY9
// Create Date: 2026/03/02 14:10:18
// Design Name: top
// Module Name: tb_uart_timing
// Project Name: sv_verification
// Target Devices: Basys3
// Tool Versions: Vivado 2020.2
// Description: 
//  Verify uart bit frame timing (baudrate = 9600bps)
//    input - 1_01010101_0 (start-bit 1, data_bit 8, stop_bit 1)
//    monitor1 - monitoring 1 bit width
//    monitor2 - monitoring total frame time
// Revision:
// Revision 0.01 - File Created
//////////////////////////////////////////////////////////////////////////////////

/******************* interface ******************/
interface uart_interface (
    input logic clk,
    input logic b_tick
);
    logic       rst;
    logic       tx_start;
    logic [7:0] tx_data;
    logic       tx_busy;
    logic       tx_done;
    logic       uart_tx;
endinterface


/****************** transaction *****************/
class transaction;
    bit [7:0] tx_input = { 8'b01010101 };

    // current time
    realtime current = $realtime;
    // one bit width timing
    realtime bit_period;
    // total frame time
    realtime frame_time;
endclass



/******************** class *******************/
class generator;
    transaction tr;
    mailbox #(transaction) gen2drv_mbox;

    function new(mailbox #(transaction) gen2drv_mbox);
        this.gen2drv_mbox = gen2drv_mbox;
    endfunction

    task run();
        tr = new;
        
        $display("%t: [gen] Start", $time);
        gen2drv_mbox.put(tr);
    endtask
endclass


class driver;
    transaction tr;
    mailbox #(transaction) gen2drv_mbox;
    virtual uart_interface uart_if;

    function new(mailbox #(transaction) gen2drv_mbox,
                 virtual uart_interface uart_if);
        this.gen2drv_mbox = gen2drv_mbox;
        this.uart_if       = uart_if;
    endfunction

    // UART baudrate: 9600bps -> 104,167ns
    realtime bit_time = 104167ns;

    task preset();
        tr = new;
        uart_if.rst = 1;
        repeat(10) @(posedge uart_if.clk) // wait 10 clk cycle
        uart_if.rst = 0;
    endtask

    task run();
        gen2drv_mbox.get(tr);

        @(posedge uart_if.clk); // wait 1 clk cycle
        #1;                    // delay 1ns for seperate timing from clk
        uart_if.tx_data = tr.tx_input;

        @(posedge uart_if.clk);
        @(posedge uart_if.clk);
        @(posedge uart_if.clk);
        @(posedge uart_if.clk);
        uart_if.tx_start = 1;
    endtask
endclass


class monitor1;
    transaction tr;
    mailbox #(transaction) mon12scb_mbox;
    virtual uart_interface uart_if;

    int bit_cnt;

    function new(mailbox #(transaction) mon12scb_mbox,
                 virtual uart_interface uart_if);
        this.mon12scb_mbox = mon12scb_mbox;
        this.uart_if         = uart_if;
    endfunction

    task run();
        bit_cnt = 1;

        // start bit
        wait(uart_if.uart_tx == 0); // start bit start
        tr = new;
        wait(uart_if.uart_tx == 1); // start bit end
        tr.bit_period = $realtime - tr.current;
        $display("%t: [mon1] start bit sended -> bit_width = %8dus", $time, tr.bit_period);
        mon12scb_mbox.put(tr);

        repeat(7) begin
            tr = new;
            @(edge uart_if.uart_tx) // 1-bit sended
            tr.bit_period = $realtime - tr.current; // capture time

            $display("%t: [mon1] bit%1d sended -> bit_width = %8dus", $time, bit_cnt, tr.bit_period);
            mon12scb_mbox.put(tr);
            bit_cnt++;
        end

        // last data bit
        tr = new;
        wait(uart_if.uart_tx == 1); // stop bit start
        tr.bit_period = $realtime - tr.current;
        $display("%t: [mon1] bit8 sended -> bit_width = %8dus", $time, tr.bit_period);
        mon12scb_mbox.put(tr);

        // end bit
        tr = new;
        wait(uart_if.uart_tx == 0); // stop bit end
        tr.bit_period = $realtime - tr.current;
        $display("%t: [mon1] stop bit sended -> bit_width = %8dns", $time, tr.bit_period);
        mon12scb_mbox.put(tr);
    endtask
endclass


class monitor2;
    transaction tr;
    mailbox #(transaction) mon22scb_mbox;
    virtual uart_interface uart_if;

    function new(mailbox #(transaction) mon22scb_mbox,
                 virtual uart_interface uart_if);
        this.mon22scb_mbox = mon22scb_mbox;
        this.uart_if        = uart_if;
    endfunction

    task run();
        wait(tb_uart_timing.dut.tx_busy == 1); // uart_tx start
        tr = new;

        wait(tb_uart_timing.dut.tx_busy == 0); // all sended
        tr.frame_time = $realtime - tr.current; // capture time

        $display("%t: [mon2] every bit sended -> run time = %8dus", $time, tr.frame_time);
        mon22scb_mbox.put(tr);
    endtask
endclass


class scoreboard;
    transaction mon1_tr;
    transaction mon2_tr;
    mailbox #(transaction) mon12scb_mbox;
    mailbox #(transaction) mon22scb_mbox;

    function new(mailbox #(transaction) mon12scb_mbox,
                 mailbox #(transaction) mon22scb_mbox);
        this.mon12scb_mbox = mon12scb_mbox;
        this.mon22scb_mbox = mon22scb_mbox;
    endfunction

    task run();
        repeat(10) begin
            mon12scb_mbox.get(mon1_tr);
            if(mon1_tr.bit_period/1us > 103 && mon1_tr.bit_period/1us < 106) begin
                $display("%t: [scb] bit_period = %8dus = %5d cycle -> PASS",
                          $time, mon1_tr.bit_period, mon1_tr.bit_period/1us);
            end else begin
                $display("%t: [scb] bit_period = %8dus = %5d cycle -> FAIL",
                          $time, mon1_tr.bit_period, mon1_tr.bit_period/1us);
            end
        end

        mon22scb_mbox.get(mon2_tr);
        if(mon2_tr.frame_time/1us > 1030 && mon2_tr.frame_time/1us < 1060) begin
            $display("%t: [scb] frame_period = %8dus = %5d cycle -> PASS",
                      $time, mon2_tr.frame_time, mon2_tr.frame_time/1us);
        end else begin
            $display("%t: [scb] frame_period = %8dus = %5d cycle -> PASS",
                      $time, mon2_tr.frame_time, mon2_tr.frame_time/1us);
        end
    endtask
endclass


class environment;
    generator  gen;
    driver     drv;
    monitor1   mon1;
    monitor2   mon2;
    scoreboard scb;

    transaction tr;
    mailbox #(transaction) gen2drv_mbox;
    mailbox #(transaction) mon12scb_mbox;
    mailbox #(transaction) mon22scb_mbox;
    virtual uart_interface uart_if;

    function new(virtual uart_interface uart_if);
        this.uart_if   = uart_if;
        gen2drv_mbox  = new;
        mon12scb_mbox = new;
        mon22scb_mbox = new;
        gen  = new(gen2drv_mbox);
        drv  = new(gen2drv_mbox, uart_if);
        mon1 = new(mon12scb_mbox, uart_if);
        mon2 = new(mon22scb_mbox, uart_if);
        scb  = new(mon12scb_mbox, mon22scb_mbox);
    endfunction

    task run();
        fork
            gen.run();
            drv.run();
            mon1.run();
            mon2.run();
            scb.run();
        join_any
    endtask
endclass


/************** testbench module **************/
module tb_uart_timing();
    environment env;

    logic clk;
    logic b_tick;
    uart_interface uart_if(clk, b_tick);

    baud_tick #(
        .F_COUNT(100_000_000 / (9600 * 16))
    )U_BAUD_TICK_GEN (
        .clk(clk),
        .reset(uart_if.rst),
        .b_tick(b_tick)
    );

    uart_tx dut (
        .clk(clk),
        .rst(uart_if.rst),
        .tx_start(uart_if.tx_start),
        .b_tick(b_tick),
        .tx_data(uart_if.tx_data),
        .tx_busy(uart_if.tx_busy),
        .tx_done(uart_if.tx_done),
        .uart_tx(uart_if.uart_tx)
    );

    always #5 clk = ~clk; // 100Mhz

    initial begin
        clk = 0;

        env = new(uart_if);
        env.drv.preset;
        env.run();

        $stop;
    end
endmodule
