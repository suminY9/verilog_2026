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
endclass  //transaction

// generator for randomize stimulus
class generator;
    // tr: transaction handler
    transaction tr;
    mailbox #(transaction) gen2drv_mbox;
    event gen_next_ev;

    function new(mailbox#(transaction) gen2drv_mbox,
                 event gen_next_ev);
        this.gen_next_ev  = gen_next_ev;
        this.gen2drv_mbox = gen2drv_mbox;
    endfunction  //new()

    task run(int count);
        repeat(count) begin
            tr = new();
            tr.randomize();
            gen2drv_mbox.put(tr);
            @(gen_next_ev);
        end
    endtask  //
endclass  //generator

class driver;
    transaction tr;  // 다른 class이므로 이름 같아도 됨
    virtual adder_interface adder_if;   // 외부와 연결하기 위한 virtual interface
    mailbox #(transaction) gen2drv_mbox;
    event gen_next_ev;

    function new(mailbox#(transaction) gen2drv_mbox,
                 event gen_next_ev,
                 virtual adder_interface adder_if);
        this.adder_if     = adder_if;
        this.gen_next_ev  = gen_next_ev;
        this.gen2drv_mbox = gen2drv_mbox;
    endfunction  //new()

    task run();
        forever begin
            gen2drv_mbox.get(tr);
            adder_if.a    = tr.a;
            adder_if.b    = tr.b;
            adder_if.mode = tr.mode;
            #10;
            // event generation
            -> gen_next_ev;
        end
    endtask  //
endclass  //driver

class environment;
    generator gen;
    driver    drv;
    mailbox #(transaction) gen2drv_mbox; // {keword} #(data_type) {name};
    event gen_next_ev;

    function new(virtual adder_interface adder_if,
                 event gen_next_ev);
        gen2drv_mbox = new();
        gen = new(gen2drv_mbox, gen_next_ev);
        drv = new(gen2drv_mbox, gen_next_ev, adder_if);
    endfunction  //new()

    task run();
        fork
            gen.run(10);
            drv.run();
        join
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
        env = new(adder_if, gen_next_ev);

        // exe (실행)
        env.run();
    end

endmodule
