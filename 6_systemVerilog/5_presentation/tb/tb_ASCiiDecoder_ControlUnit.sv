`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: suminY9
// Create Date: 2026/03/01 18:14:13
// Design Name: top
// Module Name: tb_top
// Project Name: sv_verification
// Target Devices: Basys3
// Tool Versions: Vaviado 2020.2
// Description: 
//  Verificate condection of ASCii_decoder in uart + Control_unit in watch
//  random input ASCii_decoder -> monitor control_unit output
//  check: ASCii_decoder button input, ASCii_decoder output 'control',
//         control_unit all outputs
// Revision:
//  Revision 0.01 - File Created
//////////////////////////////////////////////////////////////////////////////////

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
    rand bit [7:0] send;        // input to UART
    rand bit [3:0] switch;      // { edit_mode, hour_min/sec_msec, stopwatch/watch, down/up_count }

    // uart_rx input data
    bit [7:0] in_data;
    // output from ASCii decoder
    bit [3:0] control;
    // output from control unit
    bit [1:0] stopwatch_signal; // { o_clear, o_run_stop }
    bit [7:0] watch_signal;     // { o_edit_hour, min, sec, msec }
    bit [3:0] LED;

    // only generate 'u'=8'h75, 'd'=8'h64, 'r'=8'h72, 'l'=8'h6c, 's'=8'h93, 'NULL'=8'h00
    // only state 1000 = watch edit mode, 0000 = watch not edit, 0010 = stopwatch
    constraint gen_ASCii{
        send inside {8'h75, 8'h64, 8'h72, 8'h6c, 8'h73, 8'h00};
        switch inside { 4'b1000, 4'b0000, 4'b0010 };
    }
endclass


/******************** class *******************/
class generator;
    transaction tr;
    mailbox #(transaction) gen2drv_mbox;
    event gen_next_ev;

    function new(mailbox #(transaction) gen2drv_mbox,
                 event gen_next_ev);
        this.gen2drv_mbox = gen2drv_mbox;
        this.gen_next_ev  = gen_next_ev;
    endfunction

    task run(int run_count);
        repeat(run_count) begin
            tr = new;
            tr.randomize();
            $display("%t: [gen] send: %h, switch: %b", $time, tr.send, tr.switch);
            gen2drv_mbox.put(tr);
            @(gen_next_ev);
        end
    endtask
endclass


class driver;
    transaction tr;
    mailbox #(transaction) gen2drv_mbox;
    virtual top_interface top_if;
    
    // UART baudrate: 9600bps -> 104,167ns
    realtime bit_time = 104167ns;

    function new(mailbox #(transaction) gen2drv_mbox,
                 virtual top_interface top_if);
        this.gen2drv_mbox = gen2drv_mbox;
        this.top_if       = top_if;
    endfunction

    task preset();
        tr = new;
        top_if.rst = 1;
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
        forever begin
            gen2drv_mbox.get(tr);

            @(posedge top_if.clk); // wait 1 clk cycle
            #1;                    // delay 1ns for seperate timing from clk
            top_if.sw = tr.switch;
            send_ASCii(tr.send);
        end
    endtask
endclass


class input_monitor;
    transaction tr;
    mailbox #(transaction) inmon2scb_mbox;
    virtual top_interface top_if;

    // UART baudrate: 9600bps -> 104,167ns
    realtime bit_time = 104167ns;

    function new(mailbox #(transaction) inmon2scb_mbox,
                 virtual top_interface top_if);
        this.inmon2scb_mbox = inmon2scb_mbox;
        this.top_if         = top_if;
    endfunction

    task run();
        forever begin
            tr = new;
            
            @(negedge top_if.uart_rx) // detect start bit
            #(bit_time);

            #(bit_time/2); // sampling

            for(int i = 0; i < 8; i++) begin
                tr.in_data[i] = top_if.uart_rx;
                #(bit_time);
            end

            #(bit_time); // wait stop bit
            tr.switch = top_if.sw;
            
            $display("%t: [inmon] UART_RX input: %h", $time, tr.in_data);

            inmon2scb_mbox.put(tr);
        end
    endtask
endclass


// monitoring ASCii_decoder output 'control'
class monitor1;
    transaction tr;
    mailbox #(transaction) mon12scb_mbox;
    virtual top_interface top_if;

    function new(mailbox #(transaction) mon12scb_mbox,
                virtual top_interface top_if);
        this.mon12scb_mbox = mon12scb_mbox;
        this.top_if        = top_if;
    endfunction

    task run();
        forever begin
            // catch output control from ASCii decoder
            wait(tb_ASCiiDecoder_ControlUnit.dut.U_TOP_UART.U_ASCII_DECODER.done == 1);
            tr = new;
            tr.control = tb_ASCiiDecoder_ControlUnit.dut.U_TOP_UART.U_ASCII_DECODER.control;

            $display("%t: [mon1] ASCii_decoder Output: %b", $time, tr.control);
            
            mon12scb_mbox.put(tr);
            wait(tb_ASCiiDecoder_ControlUnit.dut.U_TOP_UART.U_ASCII_DECODER.done == 0);
        end
    endtask
endclass


// monitoring control_unit outputs
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
        forever begin
            // catch output control from ASCii decoder
            wait(tb_ASCiiDecoder_ControlUnit.dut.U_TOP_UART.U_ASCII_DECODER.done == 1);
            #1;
            tr = new;
            tr.stopwatch_signal = {tb_ASCiiDecoder_ControlUnit.dut.U_TOP_STOPWATCH_WATCH.U_CTRL_UNIT.o_clear,
                                   tb_ASCiiDecoder_ControlUnit.dut.U_TOP_STOPWATCH_WATCH.U_CTRL_UNIT.o_run_stop};
            tr.watch_signal     = {tb_ASCiiDecoder_ControlUnit.dut.U_TOP_STOPWATCH_WATCH.U_CTRL_UNIT.o_edit_hour,
                                   tb_ASCiiDecoder_ControlUnit.dut.U_TOP_STOPWATCH_WATCH.U_CTRL_UNIT.o_edit_min,
                                   tb_ASCiiDecoder_ControlUnit.dut.U_TOP_STOPWATCH_WATCH.U_CTRL_UNIT.o_edit_sec,
                                   tb_ASCiiDecoder_ControlUnit.dut.U_TOP_STOPWATCH_WATCH.U_CTRL_UNIT.o_edit_msec};
            tr.LED              =  top_if.LED;

            $display("%t: [mon2] Control_Unit output: Stopwatch(%b), Watch(%b), LED(%b)",
                      $time, tr.stopwatch_signal, tr.watch_signal, tr.LED);

            mon22scb_mbox.put(tr);
            wait(tb_ASCiiDecoder_ControlUnit.dut.U_TOP_UART.U_ASCII_DECODER.done == 0);
        end
    endtask
endclass


class scoreboard;
    transaction in_tr;
    transaction decoder_tr;
    transaction controlUnit_tr;
    mailbox #(transaction) inmon2scb_mbox;
    mailbox #(transaction) mon12scb_mbox;
    mailbox #(transaction) mon22scb_mbox;
    event gen_next_ev;

    int pf;

    function new(mailbox #(transaction) inmon2scb_mbox,
                 mailbox #(transaction) mon12scb_mbox,
                 mailbox #(transaction) mon22scb_mbox,
                 event gen_next_ev);
        this.inmon2scb_mbox = inmon2scb_mbox;
        this.mon12scb_mbox  = mon12scb_mbox;
        this.mon22scb_mbox  = mon22scb_mbox;
        this.gen_next_ev    = gen_next_ev;
    endfunction

    task run();
        forever begin
            inmon2scb_mbox.get(in_tr);
            mon12scb_mbox.get(decoder_tr);
            mon22scb_mbox.get(controlUnit_tr);

            $display("%t: [scb] UART input: 0x%h -> ASCii_decoder: control(%b) -> Control_Unit: Stopwatch(%b), Watch(%b), LED(%b)",
                      $time, in_tr.in_data, decoder_tr.control, controlUnit_tr.stopwatch_signal, controlUnit_tr.watch_signal, controlUnit_tr.LED);

            case(in_tr.in_data)
                8'h75: // u
                    if(decoder_tr.control == 4'b0011) pf = 1;
                8'h64: // u
                    if(decoder_tr.control == 4'b0100) pf = 1;
                8'h72: // r
                    if(decoder_tr.control == 4'b0001) pf = 1;
                8'h6c: // l
                    if(decoder_tr.control == 4'b0010) pf = 1;
                8'h73: // s
                    if(decoder_tr.control == 4'b1000) pf = 1;
                default: begin
                    if(decoder_tr.control == 4'b0000) pf = 1;
                    else pf = 0;
                end
            endcase

            if(pf == 1) begin
                case(in_tr.switch)
                    1000: begin // Watch edit mode
                        case(tb_ASCiiDecoder_ControlUnit.dut.U_TOP_STOPWATCH_WATCH.U_CTRL_UNIT.current_watch_edit)
                            2'b00: begin // MSEC
                                case(decoder_tr.control)
                                    4'b0011: begin // u
                                        if(controlUnit_tr.stopwatch_signal == 2'b00
                                            && controlUnit_tr.watch_signal == 8'b00_00_00_01
                                            && controlUnit_tr.LED == 4'b0001) pf = 1;
                                        else pf = 0;
                                    end
                                    4'b0100: begin // d
                                        if(controlUnit_tr.stopwatch_signal == 2'b00
                                            && controlUnit_tr.watch_signal == 8'b00_00_00_11
                                            && controlUnit_tr.LED == 4'b0001) pf = 1;
                                        else pf = 0;
                                    end
                                    default: begin // r, l, s
                                        if(controlUnit_tr.stopwatch_signal == 2'b00
                                            && controlUnit_tr.watch_signal == 8'b00_00_00_00
                                            && controlUnit_tr.LED == 4'b0001) pf = 1;
                                        else pf = 0;
                                    end                                    
                                endcase
                            end
                            2'b01: begin // SEC
                                case(decoder_tr.control)
                                    4'b0011: begin // u
                                        if(controlUnit_tr.stopwatch_signal == 2'b00
                                            && controlUnit_tr.watch_signal == 8'b00_00_01_00
                                            && controlUnit_tr.LED == 4'b0010) pf = 1;
                                        else pf = 0;
                                    end
                                    4'b0100: begin // d
                                        if(controlUnit_tr.stopwatch_signal == 2'b00
                                            && controlUnit_tr.watch_signal == 8'b00_00_11_00
                                            && controlUnit_tr.LED == 4'b0010) pf = 1;
                                        else pf = 0;
                                    end
                                    default: begin // r, l, s
                                        if(controlUnit_tr.stopwatch_signal == 2'b00
                                            && controlUnit_tr.watch_signal == 8'b00_00_00_00
                                            && controlUnit_tr.LED == 4'b0010) pf = 1;
                                        else pf = 0;
                                    end                                    
                                endcase
                            end
                            2'b10: begin // MIN
                                case(decoder_tr.control)
                                    4'b0011: begin // u
                                        if(controlUnit_tr.stopwatch_signal == 2'b00
                                            && controlUnit_tr.watch_signal == 8'b00_01_00_00
                                            && controlUnit_tr.LED == 4'b0100) pf = 1;
                                        else pf = 0;
                                    end
                                    4'b0100: begin // d
                                        if(controlUnit_tr.stopwatch_signal == 2'b00
                                            && controlUnit_tr.watch_signal == 8'b00_11_00_00
                                            && controlUnit_tr.LED == 4'b0100) pf = 1;
                                        else pf = 0;
                                    end
                                    default: begin // r, l, s
                                        if(controlUnit_tr.stopwatch_signal == 2'b00
                                            && controlUnit_tr.watch_signal == 8'b00_00_00_00
                                            && controlUnit_tr.LED == 4'b0100) pf = 1;
                                        else pf = 0;
                                    end                                    
                                endcase
                            end
                            2'b11: begin // HOUR
                                case(decoder_tr.control)
                                    4'b0011: begin // u
                                        if(controlUnit_tr.stopwatch_signal == 2'b00
                                            && controlUnit_tr.watch_signal == 8'b01_00_00_00
                                            && controlUnit_tr.LED == 4'b1000) pf = 1;
                                        else pf = 0;
                                    end
                                    4'b0100: begin // d
                                        if(controlUnit_tr.stopwatch_signal == 2'b00
                                            && controlUnit_tr.watch_signal == 8'b11_00_00_00
                                            && controlUnit_tr.LED == 4'b1000) pf = 1;
                                        else pf = 0;
                                    end
                                    default: begin // r, l, s
                                        if(controlUnit_tr.stopwatch_signal == 2'b00
                                            && controlUnit_tr.watch_signal == 8'b00_00_00_00
                                            && controlUnit_tr.LED == 4'b1000) pf = 1;
                                        else pf = 0;
                                    end                                    
                                endcase
                            end
                        endcase
                    end
                    0000: begin // Watch not edit mode
                        if(controlUnit_tr.stopwatch_signal == 2'b00
                            && controlUnit_tr.watch_signal == 8'b00_00_00_00
                            && controlUnit_tr.LED == 4'b0000) pf = 1;
                        else pf = 0;
                    end
                    0010: begin // Stopwatch
                        case(decoder_tr.control)
                            4'b0001: begin // r
                                if(controlUnit_tr.stopwatch_signal == 2'b01
                                    && controlUnit_tr.watch_signal == 8'b00_00_00_00
                                    && controlUnit_tr.LED == 4'b0000) pf = 1;
                                else pf = 0;
                            end
                            4'b0010: begin // l
                                if(controlUnit_tr.stopwatch_signal == 2'b10
                                    && controlUnit_tr.watch_signal == 8'b00_00_00_00
                                    && controlUnit_tr.LED == 4'b0000) pf = 1;
                                else pf = 0;
                            end
                            default: begin // u, d, s
                                if(controlUnit_tr.stopwatch_signal == 2'b00
                                    && controlUnit_tr.watch_signal == 8'b00_00_00_00
                                    && controlUnit_tr.LED == 4'b0000) pf = 1;
                                else pf = 0;
                            end
                        endcase
                    end
                endcase
            end else pf = 0;
            
            if(pf == 1) begin
                $display("PASS");
            end else if(pf == 0) begin
                $display("FAIL");
            end

        -> gen_next_ev;
        end
    endtask
endclass


class environment;
    generator     gen;
    driver        drv;
    input_monitor imon;
    monitor1      mon1;
    monitor2      mon2;
    scoreboard    scb;

    transaction tr;
    mailbox #(transaction) gen2drv_mbox;
    mailbox #(transaction) inmon2scb_mbox;
    mailbox #(transaction) mon12scb_mbox;
    mailbox #(transaction) mon22scb_mbox;
    event gen_next_ev;
    virtual top_interface top_if;

    function new(virtual top_interface top_if);
        this.top_if    = top_if;
        gen2drv_mbox   = new;
        inmon2scb_mbox = new;
        mon12scb_mbox  = new;
        mon22scb_mbox  = new;
        gen  = new(gen2drv_mbox, gen_next_ev);
        drv  = new(gen2drv_mbox, top_if);
        imon = new(inmon2scb_mbox, top_if);
        mon1 = new(mon12scb_mbox, top_if);
        mon2 = new(mon22scb_mbox, top_if);
        scb  = new(inmon2scb_mbox, mon12scb_mbox, mon22scb_mbox, gen_next_ev);
    endfunction

    task run(int count);
        fork
            gen.run(count);
            drv.run();
            imon.run();
            mon1.run();
            mon2.run();
            scb.run();
        join_any
    endtask
endclass


/************** testbench module **************/
module tb_ASCiiDecoder_ControlUnit();
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

        $display("***ASCii_decoder <control> signal guide***\n\
                  * 4'b0001 = button R(0x72)\n\
                  * 4'b0010 = button L(0x6c)\n\
                  * 4'b0011 = button U(0x75)\n\
                  * 4'b0100 = button D(0x64)\n\
                  * 4'b1000 = button S(0x73)\n\
                  ******************************************");

        env = new(top_if);
        env.drv.preset;
        env.run(10);

        $stop;
    end
endmodule
