`include "uvm_macros.svh"
import uvm_pkg::*;

class hello_test extends uvm_test;
    `uvm_component_utils(hello_test)

    int loop_count;

    function new(string name = "hello_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        loop_count = 0;
        `uvm_info("PHASE", "[1] build_phase - loop_count = 0 초기화", UVM_LOW)
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        `uvm_info("PHASE", "[2] connect_phase - 컴포넌트를 서로 연결하는 단계", UVM_LOW)
    endfunction

    virtual task run_phase(uvm_phase phase);
        phase.raise_objection(this);
        `uvm_info("PHASE", "[3] run_phase - 시뮬레이션 실행 시작.", UVM_LOW)
        
        for(int i=0; i<5; i++) begin
            loop_count = i + 1;
            `uvm_info("LOOP", $sformatf("테스트 반복 %0d/5 실행 중...", loop_count), UVM_LOW)
            #10;
        end

        `uvm_info("PHASE", "[3] run_phase - 시뮬레이션 실행 완료!", UVM_LOW)
        #100;
        phase.drop_objection(this);
    endtask

    virtual function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info("PHASE", $sformatf("[4] report_phase - loop_count %0d 동작", loop_count), UVM_LOW)
    endfunction
endclass

module test_uvm();
    initial begin
        run_test("hello_test");
    end
endmodule