`timescale 1ns / 1ps

interface adder_interface;
    logic [31:0] a;
    logic [31:0] b;
    logic [31:0] s;
    logic        c;
    logic        mode;
endinterface  //adder_interface

// stimulus(vector)
class transaction;
    // task, function에서 randomize를 하면 rand 키워드가 있는 변수들에 랜덤 값 생성
    rand bit [31:0] a;
    rand bit [31:0] b;
    rand bit        mode;
    logic    [31:0] s;
    logic           c;

    // to debug
    task display(string name);
        $display("%t: [%s] a = %h, b = %h, mode = %h, sum = %h, carry = %h",
                 $time, name, a, b, mode, s, c);        
    endtask //display
endclass  //transaction

// generator for randomize stimulus
class generator;
    // tr: transaction handler
    transaction tr;
    mailbox #(transaction) gen2drv_mbox;
    event gen_next_ev;

    function new(mailbox#(transaction) gen2drv_mbox, event gen_next_ev);
        this.gen_next_ev  = gen_next_ev;
        this.gen2drv_mbox = gen2drv_mbox;
    endfunction  //new()

    task run(int count);
        repeat (count) begin
            tr = new();
            tr.randomize();
            gen2drv_mbox.put(tr);
            tr.display("gen");      // debug message display
            @(gen_next_ev);
        end
    endtask  //
endclass  //generator

class driver;
    transaction tr;  // 다른 class이므로 이름 같아도 됨
    virtual adder_interface adder_if;   // 외부와 연결하기 위한 virtual interface
    mailbox #(transaction) gen2drv_mbox;
    event mon_next_ev;

    function new(mailbox#(transaction) gen2drv_mbox, event mon_next_ev,
                 virtual adder_interface adder_if);
        this.adder_if     = adder_if;
        this.mon_next_ev  = mon_next_ev;
        this.gen2drv_mbox = gen2drv_mbox;
    endfunction  //new()

    task run();
        forever begin
            gen2drv_mbox.get(tr);
            adder_if.a    = tr.a;
            adder_if.b    = tr.b;
            adder_if.mode = tr.mode;
            tr.display("drv");          // debug message display
            #10;
            // event generation
            ->mon_next_ev;
        end
    endtask  //
endclass  //driver

class monitor;
    transaction tr;
    mailbox #(transaction) mon2scb_mbox;
    event mon_next_ev;
    virtual adder_interface adder_if;

    function new(mailbox#(transaction) mon2scb_mbox,
                 event mon_next_ev,
                 virtual adder_interface adder_if);
        this.mon2scb_mbox = mon2scb_mbox;
        this.mon_next_ev  = mon_next_ev;
        this.adder_if     = adder_if;
    endfunction  //new()

    task run();
        forever begin
            @(mon_next_ev);
            tr      = new();
            tr.a    = adder_if.a;
            tr.b    = adder_if.b;
            tr.mode = adder_if.mode;
            tr.s    = adder_if.s;
            tr.c    = adder_if.c;
            mon2scb_mbox.put(tr);
            tr.display("mon");          // debug message display
        end
    endtask  //
endclass //monitor

class scoreboard;
    transaction tr;
    mailbox #(transaction) mon2scb_mbox;
    event gen_next_ev;

    function new(mailbox #(transaction) mon2scb_mbox,
                 event gen_next_ev);
        this.mon2scb_mbox = mon2scb_mbox;
        this.gen_next_ev  = gen_next_ev;
    endfunction //new()

    task run();
        forever begin
            mon2scb_mbox.get(tr);
            tr.display("scb");          // debug message display
            // compare, pass, fail
            // 완성 필요
            //$display("%t:a=%d, b=%d, mode=%d, s=%d, c=%d", $time, tr.a, tr.b, tr.mode, tr.s, tr.c);
            -> gen_next_ev;
        end
    endtask //
endclass //scoreboard

class environment;
    generator  gen;
    driver     drv;
    monitor    mon;
    scoreboard scb;

    mailbox #(transaction) gen2drv_mbox; // gen -> drv // {keword} #(data_type) {name};
    mailbox #(transaction) mon2scb_mbox; // mon -> scb
    event gen_next_ev; // scb to gen
    event mon_next_ev; // drv to mon

    function new(virtual adder_interface adder_if);
        gen2drv_mbox = new();
        mon2scb_mbox = new();
        gen = new(gen2drv_mbox, gen_next_ev);
        drv = new(gen2drv_mbox, mon_next_ev, adder_if);
        mon = new(mon2scb_mbox, mon_next_ev, adder_if);
        scb = new(mon2scb_mbox, gen_next_ev);
    endfunction  //new()

    task run();
        fork
            gen.run(10);
            drv.run();
            mon.run();
            scb.run();
        join_any
        $stop;
    endtask  //
endclass  //environment

module tb_adder_verification ();

    adder_interface adder_if ();
    environment env;

    adder dut (
        .a   (adder_if.a),
        .b   (adder_if.b),
        .mode(adder_if.mode),
        .s   (adder_if.s),
        .c   (adder_if.c)
    );

    initial begin
        // constructor (생성자)
        env = new(adder_if);

        // exe (실행)
        env.run();
    end

endmodule
