`include "uvm_macros.svh"
import uvm_pkg::*;

class hello_test extends uvm_test;
    `uvm_component_utils(hello_test)

    function new(string name = "hello_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        `uvm_info("PHASE", "[1] build_phase - 컴포넌트를 만드는 단계", UVM_LOW)
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        `uvm_info("PHASE", "[2] connect_phase - 컴포넌트를 서로 연결하는 단계", UVM_LOW)
    endfunction

    virtual task run_phase(uvm_phase phase);
        phase.raise_objection(this);
        `uvm_info("PHASE", "[3] run_phase - 시뮬레이션 실행 시작.", UVM_LOW)
        `uvm_info("HELLO", "첫 번째 UVM 프로그램이 실행되었습니다.", UVM_LOW)
        `uvm_info("HELLO", "UVM 환경 설정 성공! 다음 준비 완료.", UVM_LOW)
        `uvm_warning("WARN", "UVM 환경 설정 경고! 현재 중비 상태 확인 필요!")
        `uvm_error("ERROR", "UVM 환경 설정 에러! 다음 준비 미완료.")
        `uvm_info("PHASE", "[3] run_phase - 시뮬레이션 실행 완료!", UVM_LOW)
        #100;
        phase.drop_objection(this);
    endtask

    virtual function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info("PHASE", "[4] report_phase - 결과를 정리하는 단계", UVM_LOW)
    endfunction
endclass

module test_uvm();
    initial begin
        run_test("hello_test");
    end
endmodule