`ifndef RAM_TEST_SV
`define RAM_TEST_SV

`timescale 1ns/1ps
`include "uvm_macros.svh"
import uvm_pkg::*;

class ram_base_test extends uvm_test;
    `uvm_component_utils(ram_base_test)

    ram_env env;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = ram_env::type_id::create("env", this);
    endfunction
    virtual task run_phase(uvm_phase phase);
        //ram_sequence seq = ram_sequence::type_id::create("seq");

        phase.raise_objection(this);
        //seq.num_transaction = 10;
        //seq.start(env.agt.sqr);
        run_test_seq();
        phase.drop_objection(this);
        `uvm_info("TEST", "ram test 완료", UVM_NONE) // UVM_NONE: always display
    endtask
    virtual task run_test_seq();
        // 자식 클래스에서 해당 기능 구현
    endtask
endclass

class ram_write_read_test extends ram_base_test;
    `uvm_component_utils(ram_write_read_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual task run_test_seq();
        ram_write_read_sequence seq = ram_write_read_sequence::type_id::create("seq");
        seq.num_transaction = 10;
        seq.start(env.agt.sqr);
        `uvm_info("TEST", "ram_write_read_sequence test 완료", UVM_NONE) // UVM_NONE: always display
    endtask
endclass

class ram_full_sweep_test extends ram_base_test;
    `uvm_component_utils(ram_full_sweep_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual task run_test_seq();
        ram_full_sweep_sequence seq = ram_full_sweep_sequence::type_id::create("seq");
        seq.start(env.agt.sqr);
        `uvm_info("TEST", "ram_full_sweep_sequence test 완료", UVM_NONE) // UVM_NONE: always display
    endtask
endclass

class ram_random_test extends ram_base_test;
    `uvm_component_utils(ram_random_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual task run_test_seq();
        ram_random_sequence seq = ram_random_sequence::type_id::create("seq");
        seq.num_transaction = 100;
        seq.start(env.agt.sqr);
        `uvm_info("TEST", "ram_random_sequence test 완료", UVM_NONE) // UVM_NONE: always display
    endtask
endclass
`endif 