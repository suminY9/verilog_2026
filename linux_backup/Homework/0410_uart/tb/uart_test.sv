`ifndef TEST_SV
`define TEST_SV

class uart_base_test extends uvm_test;
    `uvm_component_utils(uart_base_test)
    uart_env env;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = uart_env::type_id::create("env", this);
    endfunction
    virtual function void end_of_elaboration_phase(uvm_phase phase); // run phase 직전
        `uvm_info(get_type_name(), "===== UVM 계층 구조 =====", UVM_MEDIUM)
        uvm_top.print_topology();
    endfunction
endclass

class uart_rand_test extends uart_base_test;
    `uvm_component_utils(uart_rand_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual task run_phase(uvm_phase phase);
        uart_rand_seq seq;

        phase.raise_objection(this);
        seq = uart_rand_seq::type_id::create("seq");
        seq.num_loop = 10;
        seq.start(env.agt.sqr);
        phase.drop_objection(this);
    endtask
endclass

`endif 