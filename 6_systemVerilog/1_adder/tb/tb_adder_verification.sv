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
    randc bit [31:0] a;
    randc bit [31:0] b;
    randc bit        mode;
    logic    [31:0] s;
    logic           c;

    // to deburg
    task display(string name);
        $display("%t: [%s] a = %h, b = %h, mode = %h, sum = %h, carry = %h",
                 $time, name, a, b, mode, s, c);        
    endtask //display

    /* constraint randomize */
    // 범위 지정
    //constraint range {
    //    a > 10;
    //    b > 32'hFFFF_0000;
    //}

    // 확률 지정
    //constraint dist_patten {
    //    a dist {
    //        0 :/ 80,                   //  10번 중 8번
    //        32'hffff_ffff :/ 10,       //  10번 중 1번
    //        [1:32'hffff_fffe] :/ 10    //  10번 중 1번
    //    };
    //}

    // 범위 지정 방법 2
    constraint list_pattern {
        a inside {[ 0:16 ]};            // a의 범위 지정
    }
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
            tr.display("gen");      // deburg message display
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
            tr.display("drv");          // deburg message display
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
            tr.display("mon");          // deburg message display
        end
    endtask  //
endclass //monitor

class scoreboard;
    transaction tr;
    mailbox #(transaction) mon2scb_mbox;
    event gen_next_ev;
    // to compare
    bit [31:0] expected_sum;
    bit        expected_carry;
    int        pass_cnt, fail_cnt;

    function new(mailbox #(transaction) mon2scb_mbox,
                 event gen_next_ev);
        this.mon2scb_mbox = mon2scb_mbox;
        this.gen_next_ev  = gen_next_ev;
    endfunction //new()

    task run();
        forever begin
            mon2scb_mbox.get(tr);
            tr.display("scb");          // deburg message display
            
            // compare, pass, fail
            // generate for compare expected data
            if(tr.mode == 0)  {expected_carry, expected_sum} = tr.a + tr.b;
            else              {expected_carry, expected_sum} = tr.a - tr.b;
            if((expected_sum == tr.s) && (expected_carry == tr.c)) begin
                $display("[pass]:a=%d, b=%d, mode=%d, s=%d, c=%d",
                         tr.a, tr.b, tr.mode, tr.s, tr.c);
                pass_cnt++;
            end else begin
                $display("[fail]:a=%d, b=%d, mode=%d, s=%d, c=%d",
                         tr.a, tr.b, tr.mode, tr.s, tr.c);
                fail_cnt++;
                $display("expected sum = %d", expected_sum);
                $display("expected carry = %d", expected_carry);
            end
            
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

    // try
    int i;

    function new(virtual adder_interface adder_if);
        gen2drv_mbox = new();
        mon2scb_mbox = new();
        gen = new(gen2drv_mbox, gen_next_ev);
        drv = new(gen2drv_mbox, mon_next_ev, adder_if);
        mon = new(mon2scb_mbox, mon_next_ev, adder_if);
        scb = new(mon2scb_mbox, gen_next_ev);
    endfunction  //new()

    task run();
        i = 100;

        fork
            gen.run(i);
            drv.run();
            mon.run();
            scb.run();
        join_any
        #20;    // 모든 class들이 연산을 마칠 때까지 기다림. 안정적으로 값을 뽑기 위한 delay
        
        // total pass/fail
        $display("______________________________");
        $display("** 32bit Adder Verification **");
        $display("------------------------------");
        $display("** Total test cnt = %3d     **", i);
        $display("** Total pass cnt = %3d     **", scb.pass_cnt);
        $display("** Total fail cnt = %3d     **", scb.fail_cnt);
        $display("------------------------------");
        $display("______________________________");

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
