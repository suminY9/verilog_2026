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
    bit [7:0] input_data = 8'h73; // 's'
    bit [3:0] input_sw   = 4'b0000; // watch not edit, up count

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
    virtual top_interface top_if;

    function new(mailbox #(transaction) gen2drv_mbox,
                 virtual top_interface top_if);
        this.gen2drv_mbox = gen2drv_mbox;
        this.top_if       = top_if;
    endfunction

    // UART baudrate: 9600bps -> 104,167ns
    realtime bit_time = 104167ns;

    task preset();
        tr = new;
        top_if.rst = 1;
        top_if.sw = tr.input_sw;
        repeat(10) @(posedge top_if.clk) // wait 10 clk cycle
        top_if.rst = 0;
    endtask

    task send_ASCii(bit [7:0] send_data);
        top_if.uart_rx = 0; // start bit: LOW
        #(bit_time);

        // send ASCii 8-bit
        for(int i = 0; i < 8; i++) begin
            top_if.uart_rx = send_data[i];
            #(bit_time);
        end

        top_if.uart_rx = 1; // stop bit: HIHG
        #(bit_time);

        // delay for next send
        #(bit_time);
        #(bit_time);
    endtask 

    task run();
        gen2drv_mbox.get(tr);

        @(posedge top_if.clk); // wait 1 clk cycle
        #1;                    // delay 1ns for seperate timing from clk
        send_ASCii(tr.input_data);
    endtask
endclass


class monitor1;
    transaction tr;
    mailbox #(transaction) mon12scb_mbox;
    virtual top_interface top_if;

    int bit_cnt;

    function new(mailbox #(transaction) mon12scb_mbox,
                 virtual top_interface top_if);
        this.mon12scb_mbox = mon12scb_mbox;
        this.top_if         = top_if;
    endfunction

    task run();
        bit_cnt = 1;

        // start bit
        wait(top_if.uart_tx == 0); // start bit start
        tr = new;
        wait(top_if.uart_tx == 1); // start bit end
        tr.bit_period = $realtime - tr.current;
        $display("%t: [mon1] start bit sended -> bit_width = %dus", $time, tr.bit_period);
        mon12scb_mbox.put(tr);

        repeat(7) begin
            tr = new;
            @(edge tb_uart_timing.dut.U_TOP_UART.U_UART_TX.bit_cnt_reg) // 1-bit sended
            tr.bit_period = $realtime - tr.current; // capture time

            $display("%t: [mon1] bit%1d sended -> bit_width = %dus", $time, bit_cnt, tr.bit_period);
            mon12scb_mbox.put(tr);
            bit_cnt++;
        end

        // last data bit
        tr = new;
        wait(top_if.uart_tx == 1); // stop bit start
        tr.bit_period = $realtime - tr.current;
        $display("%t: [mon1] bit8 sended -> bit_width = %dus", $time, tr.bit_period);
        mon12scb_mbox.put(tr);

        // end bit
        tr = new;
        wait(top_if.uart_tx == 0); // stop bit end
        tr.bit_period = $realtime - tr.current;
        $display("%t: [mon1] stop bit sended -> bit_width = %dns", $time, tr.bit_period);
        mon12scb_mbox.put(tr);
    endtask
endclass


class monitor2;
    transaction tr;
    mailbox #(transaction) mon22scb_mbox;
    virtual top_interface top_if;

    function new(mailbox #(transaction) mon22scb_mbox,
                 virtual top_interface top_if);
        this.mon22scb_mbox = mon22scb_mbox;
        this.top_if        = top_if;
    endfunction

    task run();
        wait(tb_uart_timing.dut.U_TOP_UART.U_UART_TX.tx_busy == 1); // uart_tx start
        tr = new;

        wait(tb_uart_timing.dut.U_TOP_UART.U_UART_TX.tx_busy == 0); // all sended
        tr.frame_time = $realtime - tr.current; // capture time

        $display("%t: [mon2] every bit sended -> run time = %dus", $time, tr.frame_time);
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
            if(mon1_tr.bit_period/1us > 103 && mon1_tr.bit_period/1us < 108) begin
                $display("%t: [scb] bit_period = %dus = %d cycle -> PASS",
                          $time, mon1_tr.bit_period, mon1_tr.bit_period/1us);
            end else begin
                $display("%t: [scb] bit_period = %dus = %d cycle -> FAIL",
                          $time, mon1_tr.bit_period, mon1_tr.bit_period/1us);
            end
        end

        mon22scb_mbox.get(mon2_tr);
        if(mon2_tr.frame_time/1us > 1030 && mon2_tr.frame_time/1us < 1080) begin
            $display("%t: [scb] frame_period = %dus = %d cycle -> PASS",
                      $time, mon2_tr.frame_time, mon2_tr.frame_time/1us);
        end else begin
            $display("%t: [scb] frame_period = %dus = %d cycle -> PASS",
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
    virtual top_interface top_if;

    function new(virtual top_interface top_if);
        this.top_if   = top_if;
        gen2drv_mbox  = new;
        mon12scb_mbox = new;
        mon22scb_mbox = new;
        gen  = new(gen2drv_mbox);
        drv  = new(gen2drv_mbox, top_if);
        mon1 = new(mon12scb_mbox, top_if);
        mon2 = new(mon22scb_mbox, top_if);
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
        env.run();

        $stop;
    end
endmodule
