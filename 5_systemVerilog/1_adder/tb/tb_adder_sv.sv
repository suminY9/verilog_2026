`timescale 1ns / 1ps

class transaction;

    rand bit [31:0] a;
    rand bit [31:0] b;
    bit             mode;

endclass  //className

interface adder_interface;
    logic [31:0] a;
    logic [31:0] b;
    logic [31:0] s;
    logic        c;
    logic        mode;
endinterface  //adder_interface

class generator;

    // variable 
    transaction tr;
    virtual adder_interface adder_interf_gen;

    // software socket
    function new(virtual adder_interface adder_interf_ext);
        adder_interf_gen = adder_interf_ext;
        tr               = new();
    endfunction

    task run();
        tr.randomize();
        adder_interf_gen.a = tr.a;
        adder_interf_gen.b = tr.b;
        adder_interf_gen.mode = tr.mode;

        // drive <- 시간을 전송하는 것. function은 시간 제어 불가. task만 시간 제어 가능.
        #10;
    endtask  //

endclass  //generator

module tb_adder_sv ();

    adder_interface adder_interf();
    generator       gen;

    adder dut (
        .a(adder_interf.a),
        .b(adder_interf.b),
        .mode(adder_interf.mode),
        .s(adder_interf.s),
        .c(adder_interf.c)
    );

    initial begin
        // class generator를 생성.
        // generator class의 function new가 실행됨
        // new 생성자
        gen = new(adder_interf); // 메모리 동적 할당
        gen.run(); // task 1회 실행
        $stop;
    end

endmodule
