`include "uvm_macros.svh"
import uvm_pkg::*;

interface counter_if(input logic clk);
    logic       rst_n;
    logic       enable;
    logic [3:0] count;
endinterface


/***** sequence *****/
class counter_seq_item extends uvm_sequence_item;
    rand bit rst_n;
    rand bit enable;
    rand bit cycles;
    logic [3:0] count;

    constraint c_cycles {cycles inside {[1 : 20]};}

    `uvm_object_utils_begin(counter_seq_item)
        `uvm_field_int(rst_n, UVM_ALL_ON)
        `uvm_field_int(enable, UVM_ALL_ON)
        `uvm_field_int(cycles, UVM_ALL_ON)
        `uvm_field_int(count, UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "counter_seq_item");
        super.new(name);
    endfunction

    function string convert2string();
        return $sformatf("rst_n=%0b enable=%0b cycles=%0d count=%0h", rst_n, enable, cycles, count);
    endfunction
endclass


class counter_reset_seq extends uvm_sequence #(counter_seq_item);
    `uvm_object_utils(counter_reset_seq)

    function new(string name = "counter_reset_seq");
        super.new(name);
    endfunction

    virtual task body();
        counter_seq_item item;
        item = counter_seq_item::type_id::create("item");

        start_item(item);
        item.rst_n = 0;
        item.enable = 0;
        item.cycles = 2;
        finish_item(item);
        `uvm_info(get_type_name(), "Reset Done!", UVM_MEDIUM)
    endtask
endclass


class counter_count_seq extends uvm_sequence #(counter_seq_item);
    `uvm_object_utils(counter_count_seq)
    int num_transactions;

    function new(string name = "counter_count_seq");
        super.new(name);
        num_transactions = 0;
    endfunction

    virtual task body();
        counter_seq_item item;
        for(int i = 0; i < num_transactions; i++) begin
            item = counter_seq_item::type_id::create($sformatf("item_%0d", i));

            start_item(item);
            if(!item.randomize() with {
                rst_n == 1;
                enable == 1;
                cycles inside {[1:5]};
                })
                `uvm_fatal(get_type_name(), "Randomization failed")
            finish_item(item);

            `uvm_info(get_type_name(), $sformatf("[%0d/%0d] %s", i + 1, num_transactions, item.convert2string()), UVM_HIGH)
        end
    endtask
endclass


class counter_master_seq extends uvm_sequence #(counter_seq_item);
    `uvm_object_utils(counter_master_seq)

    function new(string name = "counter_master_seq");
        super.new(name);
    endfunction

    virtual task body();
        counter_reset_seq reset_seq;
        counter_count_seq count_seq;

        `uvm_info(get_type_name(), "===== Phase 1: Reset =====", UVM_MEDIUM)
            reset_seq = counter_reset_seq::type_id::create("reset_seq");
            reset_seq.start(m_sequencer);

        `uvm_info(get_type_name(), "===== Phase 2: Count =====", UVM_MEDIUM)
            count_seq = counter_count_seq::type_id::create("count_seq");
            count_seq.num_transactions = 5;
            count_seq.start(m_sequencer);

        `uvm_info(get_type_name(), "===== Master Sequence DONE =====", UVM_MEDIUM)
    endtask
endclass


/***** structure *****/
class counter_driver extends uvm_driver #(counter_seq_item);
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

    virtual task drive_item(counter_seq_item item);
        c_if.rst_n  <= item.rst_n;
        c_if.enable <= item.enable;
        repeat(item.cycles) @(posedge c_if.clk);
        `uvm_info(get_type_name(), $sformatf("drive_cycles: %0d", item.cycles), UVM_HIGH);
    endtask

    virtual task run_phase(uvm_phase phase);
        counter_seq_item item;
        forever begin
            seq_item_port.get_next_item(item);
            drive_item(item);
            seq_item_port.item_done();
        end
    endtask
endclass


class counter_monitor extends uvm_monitor;
    `uvm_component_utils(counter_monitor)
    virtual counter_if c_if;
    uvm_analysis_port #(counter_seq_item) ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        ap = new("ap", this);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if(!uvm_config_db#(virtual counter_if)::get(this, "", "c_if", c_if))
            `uvm_fatal(get_type_name(), "c_if를 찾을 수 없습니다.")
    endfunction

    virtual task run_phase(uvm_phase phase);
        forever begin
            counter_seq_item item = counter_seq_item::type_id::create("item");
            // ...... interface 신호 수집
            @(c_if.clk);
            #1;
            item.rst_n = c_if.rst_n;
            item.enable = c_if.enable;
            item.count = c_if.count;
            ap.write(item);
            `uvm_info(get_type_name(), item.convert2string(), UVM_MEDIUM);
        end
    endtask
endclass


class counter_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(counter_scoreboard)
    // analysis implementation 선언, write 함수를 구현하는 부분
    uvm_analysis_imp #(counter_seq_item, counter_scoreboard) ap_imp;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        ap_imp = new("ap_imp", this);
    endfunction

    virtual function void write(counter_seq_item item);
        `uvm_info(get_type_name(), $sformatf("Received: %s", item.convert2string()), UVM_MEDIUM);
        // 검증 로직
    endfunction
endclass


class counter_agent extends uvm_agent;
    `uvm_component_utils(counter_agent)

    uvm_sequencer#(counter_seq_item) sqr;
    counter_driver drv;
    counter_monitor mon;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    /***** phase *****/
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        sqr = uvm_sequencer#(counter_seq_item)::type_id::create("sqr", this);
        `uvm_info(get_type_name(), "sqr 생성", UVM_DEBUG);
        drv = counter_driver::type_id::create("drv", this);
        `uvm_info(get_type_name(), "drv 생성", UVM_DEBUG);
        mon = counter_monitor::type_id::create("mon", this);
        `uvm_info(get_type_name(), "mon 생성", UVM_DEBUG);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        drv.seq_item_port.connect(sqr.seq_item_export);
    endfunction
endclass


class counter_environment extends uvm_env;
    `uvm_component_utils(counter_environment)

    counter_agent agt;
    counter_scoreboard scb;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        `uvm_info(get_type_name(), "new 실행", UVM_DEBUG);
    endfunction

    /***** phase *****/
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agt = counter_agent::type_id::create("agt", this);
        scb = counter_scoreboard::type_id::create("scb", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        agt.mon.ap.connect(scb.ap_imp); // caller: monitor, callee: scoreboard
    endfunction
endclass


class counter_test extends uvm_test;
    `uvm_component_utils(counter_test)

    counter_environment env;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        `uvm_info(get_type_name(), "new 생성", UVM_DEBUG);
    endfunction

    /***** phase *****/
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = counter_environment::type_id::create("env", this);
        `uvm_info(get_type_name(), "env 생성", UVM_DEBUG);
    endfunction
   
    virtual task run_phase(uvm_phase phase);
        //counter_master_seq seq;
        counter_reset_seq reset_seq;
        counter_count_seq count_seq;

        phase.raise_objection(this);
        //seq = counter_master_seq::type_id::create("seq");
        //seq.start(env.agt.sqr);
        reset_seq = counter_reset_seq::type_id::create("reset_seq");
        reset_seq.start(env.agt.sqr);

        count_seq = counter_count_seq::type_id::create("count_seq");
        count_seq.num_transactions = 10;
        count_seq.start(env.agt.sqr);

        //#100;
        phase.drop_objection(this);
    endtask

    virtual function void report_phase(uvm_phase phase);
        uvm_report_server svr = uvm_report_server::get_server();
        if(svr.get_severity_count(UVM_ERROR) == 0)
            `uvm_info(get_type_name(), "===== TEST PASS ! =====", UVM_LOW)
        else `uvm_info(get_type_name(), "===== TEST FAIL ! =====", UVM_LOW)
    endfunction
endclass



/***** dut *****/
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