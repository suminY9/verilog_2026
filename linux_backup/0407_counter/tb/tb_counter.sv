`include "uvm_macros.svh"
import uvm_pkg::*;

interface counter_if(input logic clk);
    logic       rst_n;
    logic       enable;
    logic [3:0] count;
endinterface


class counter_driver extends uvm_component;
    `uvm_component_utils(counter_driver)
    virtual counter_if c_if;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction


    /***** phase *****/
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if(!uvm_config_db#(virtual counter_if)::get(this, "", "c_if", c_if))
            `uvm_fatal(get_type_name(), "c_if를 찾을 수 없습니다.")
        `uvm_info(get_type_name(), "build_phase 실행 완료.", UVM_HIGH);
    endfunction


    virtual task drive_count(int num_clocks);
        c_if.enable = 1;
        repeat(num_clocks) @(posedge c_if.clk);
        c_if.enable = 0;
        `uvm_info(get_type_name(), $sformatf("drive_count: %0d", num_clocks), UVM_HIGH);
    endtask
    virtual task reset_dut();
        c_if.rst_n  = 0;
        c_if.enable = 0;
        repeat(2) @(posedge c_if.clk);
        c_if.rst_n  = 1;
        @(posedge c_if.clk);
        `uvm_info(get_type_name(), "리셋 완료.", UVM_HIGH);
    endtask
    virtual task run_phase(uvm_phase phase);
        phase.raise_objection(this);

        /*** scenario ***/
        // reset 실행
        reset_dut();
        // 10 clock count
        drive_count(10);
        // 3 clock stop, recount 5 clock
        repeat(3) @(posedge c_if.clk);
        drive_count(5);
        
        #20;
        phase.drop_objection(this);
    endtask
endclass


class counter_monitor extends uvm_component;
    `uvm_component_utils(counter_monitor)
    virtual counter_if c_if;
    int expected_count; //판단을 위한 비교 변수

    function new(string name, uvm_component parent);
        super.new(name, parent);
        expected_count = 0;
    endfunction

    /***** phase *****/
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if(!uvm_config_db#(virtual counter_if)::get(this, "", "c_if", c_if))
            `uvm_fatal(get_type_name(), "c_if를 찾을 수 없습니다.")
        `uvm_info(get_type_name(), "build_phase 실행 완료.", UVM_HIGH);
    endfunction
    
    virtual task run_phase(uvm_phase phase);
        @(posedge c_if.rst_n); // wait until reset == 1
        
        forever begin
            @(posedge c_if.clk);
            #1;

            if(!c_if.rst_n) begin
                expected_count = 0;
            end else if (c_if.enable) begin
                expected_count = (expected_count + 1) % 16; // count 0~15

                if(c_if.count != expected_count) begin
                    `uvm_error(get_type_name(), $sformatf("불일치! 예상=%0d, 실제=%0d", expected_count, c_if.count))
                end else begin
                    `uvm_info(get_type_name(), $sformatf("일치! count=%0d", c_if.count), UVM_LOW)
                end
            end
        end
    endtask
    
    virtual function void report_phase(uvm_phase phase);
        super.report_phase(phase);
    endfunction
endclass


class counter_agent extends uvm_component;
    `uvm_component_utils(counter_agent)

    counter_driver drv;
    counter_monitor mon;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    /***** phase *****/
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        drv = counter_driver::type_id::create("drv", this);
        mon = counter_monitor::type_id::create("mon", this);
    endfunction
endclass


class counter_environment extends uvm_component;
    `uvm_component_utils(counter_environment)

    counter_agent agt;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    /***** phase *****/
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agt = counter_agent::type_id::create("agt", this);
    endfunction
endclass


class counter_test extends uvm_component;
    `uvm_component_utils(counter_test)

    counter_environment env;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    /***** phase *****/
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = counter_environment::type_id::create("env", this);
    endfunction
   
    virtual function void report_phase(uvm_phase phase);
        uvm_report_server svr = uvm_report_server::get_server();
        if(svr.get_severity_count(UVM_ERROR) == 0)
            `uvm_info(get_type_name(), "===== TEST PASS ! =====", UVM_LOW)
        else `uvm_info(get_type_name(), "===== TEST FAIL ! =====", UVM_LOW)
    endfunction
endclass




module tb_counter();
    logic clk;

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    counter_if c_if(clk);

    counter dut(
        .clk(clk),
        .rst_n(c_if.rst_n),
        .enable(c_if.enable),
        .count(c_if.count)
    );

    initial begin
        uvm_config_db#(virtual counter_if)::set(null, "*", "c_if", c_if);
        run_test("counter_test");
    end
endmodule