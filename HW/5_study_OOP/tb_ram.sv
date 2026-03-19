`timescale 1ns / 1ps

interface ram_if (
    input logic clk
);
    logic we;
    logic [7:0] addr;
    logic [7:0] wdata;
    logic [7:0] rdata;
endinterface

class test;

    virtual ram_if r_if;  // SW의 interface (not HW)
    // virtual -> HW와 연결하겠다는 SW의 virtual

    function new(virtual ram_if r_if);
        this.r_if = r_if;
    endfunction

    virtual task write(logic [7:0] waddr, logic [7:0] data);
        // virtual -> class의 기능. override(덮어쓰기)에 대한 기능.
        // 자식 class에서 재정의(똑같은 이름, 똑같은 매개변수의 task)를 해도 된다 라는 뜻
        r_if.we    = 1;
        r_if.addr  = waddr;
        r_if.wdata = data;
        @(posedge r_if.clk);
    endtask

    virtual task read(logic [7:0] raddr);
        r_if.we   = 0;
        r_if.addr = raddr;
        @(posedge r_if.clk);
    endtask
endclass


class test_burst extends test;  // 기존 test class를 확장 -> 상속
    function new(virtual ram_if r_if);  // new: 생성자
        super.new(r_if);
    endfunction

    task write_burst(logic [7:0] waddr, logic [7:0] data, int len);
        for (int i = 0; i < len; i++) begin
            super.write(waddr,
                        data);  // super -> 부모클래스의 write task를 쓰겠다는 의미
            waddr++;
        end
    endtask

    task write(
        logic [7:0] waddr, logic [7:0] data
    );  // 부모클래스에 있는 write task 재정의
        r_if.we    = 1;
        r_if.addr  = waddr + 1;  // 부모 클래스와 다르게 waddr + 1.
        r_if.wdata = data;
        @(posedge r_if.clk);
        waddr++;
    endtask
endclass


class transaction;
    logic            we;
    rand logic [7:0] addr;
    rand logic [7:0] wdata;
    logic      [7:0] rdata;

    //특정 영역만 테스트하고 싶을 때 -> 제약사항을 제시
    //0x00 ~ 0x10 값만 나오도록 제약.
    constraint c_addr  {addr inside {[8'h00 : 8'h10]};}
    constraint c_wdata {wdata inside {[8'h10 : 8'h10]};}

    function print(string name);
        $display("[name] we:%0d, addr:0x%0x, wdata:0x%0x, rdata:0x%0x",
                 name, we, addr, wdata, rdata);
    endfunction
endclass


class test_rand extends test;
    transaction tr; // -> tr을 선언함으로써 stack 공간에 memory 영역이 잡힘

    function new(virtual ram_if r_if);
        super.new(r_if);
    endfunction

    task write_rand(int loop);
        repeat(loop) begin
            tr = new(); // -> transaction 코드들이 heap 영역에 잡힘(instance). <- 실체화, 메모리 영역에 잡히면서 그 데이터들이 tr handler 안에 들어감.
            tr.randomize();
            r_if.we    = 1;
            r_if.addr  = tr.addr; // 여기서 tr은 메모리 주소
            r_if.wdata = tr.wdata;
            @(posedge r_if.clk);
        end
    endtask
endclass


module tb_ram ();
    logic clk;
    test  BTS;
    test_rand  BlackPink;

    ram_if r_if (clk);

    ram dut (
        .clk(r_if.clk),
        .we(r_if.we),
        .addr(r_if.addr),
        .wdata(r_if.wdata),
        .rdata(r_if.rdata)
    );

    initial clk = 0;  // test하기 위한 clk 초기화를 따로 분리
    always #5 clk = ~clk;


    initial begin
        repeat (5) @(posedge clk);
        BTS = new(r_if);  // 실체화
        BlackPink = new(r_if);

        $display("addr = 0x%0h", BTS);
        $display("addr = 0x%0h", BlackPink);

        BTS.write(8'h00, 8'h01);
        BTS.write(8'h01, 8'h02);
        BTS.write(8'h02, 8'h03);
        BTS.write(8'h03, 8'h04);

        //BlackPink.write_burst(8'h00, 8'h01, 4);
        BlackPink.write_rand(10);

        //ram_write(8'h00, 8'h01); // 사용자가 몰라도 되는 것은 모른 채로 필요한 것만 사용. -> 추상화
        //ram_write(8'h01, 8'h02);
        //ram_write(8'h02, 8'h03);
        //ram_write(8'h03, 8'h04);

        BTS.read(8'h00);
        BTS.read(8'h01);
        BTS.read(8'h02);
        BTS.read(8'h03);
        //ram_read(8'h00);
        //ram_read(8'h01);
        //ram_read(8'h02);
        //ram_read(8'h03);

        //we    = 1;
        //addr  = 8'h00;
        //wdata = 8'h01;
        //@(posedge clk);

        //we    = 1;
        //addr  = 8'h01;
        //wdata = 8'h02;
        //@(posedge clk);

        //we    = 1;
        //addr  = 8'h02;
        //wdata = 8'h03;
        //@(posedge clk);

        //we   = 0;
        //addr = 8'h02;
        //@(posedge clk);

        #20;
        $finish;  // finish 반드시 넣어주기. 무한루프 방지.
    end
endmodule
