import uvm_pkg::*;
`include "uvm_macros.svh"

interface uart_if (input logic clk, input logic reset);
    logic [7:0] tx_data;
    logic       tx_start;
    logic       tx;
    logic       tx_busy;
    logic       rx;
    logic [7:0] rx_data;
    logic       rx_valid;

    clocking drv_cb @(posedge clk);
        default input #1step output #0;
        output tx_data;
        output tx_start;
        output tx;
        input tx_busy;
        input rx;
        input rx_data;
        input rx_valid;
    endclocking 
    
    clocking mon_cb @(posedge clk);
        default input #1step output #0;
        input tx_data;
        input tx_start;
        input tx;
        input tx_busy;
        input rx;
        input rx_data;
        input rx_valid;
    endclocking
endinterface


class uart_seq_item extends uvm_sequence_item;
    // `uvm_object_utils(uart_seq_item)

    rand logic [7:0] tx_data;
    logic      [7:0] rx_data;

    constraint c_tx_data {
        tx_data inside { [8'h00: 8'hff] };
    }

    `uvm_object_utils_begin(uart_seq_item)
        `uvm_field_int(tx_data, UVM_ALL_ON)
        `uvm_field_int(rx_data, UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "uart_base_seq");
        super.new(name);
    endfunction

    function string convert2string();
        return $sformatf("tx_data=0x%02h, rx_data=0x%02h", tx_data, rx_data);
    endfunction
endclass

class uart_rand_seq extends uvm_sequence #(uart_seq_item);
    `uvm_object_utils(uart_rand_seq)

    int num_trans = 10;

    function new(string name = "uart_rand_seq");
        super.new(name);
    endfunction

    task body();
        uart_seq_item item;
        repeat(num_trans) begin
            item = uart_seq_item::type_id::create("item");
            start_item(item);
                if(!item.randomize()) 
                    `uvm_fatal(get_type_name(), "uart_seq_item randomize() fail.")
                `uvm_info(get_type_name(), item.convert2string(), UVM_MEDIUM)
            finish_item(item);
        end
    endtask
endclass



class uart_coverage extends uvm_subscriber #(uart_seq_item);
    `uvm_component_utils(uart_coverage)

    logic [7:0] cov_tx_data;

    covergroup cg_data;
        cp_tx_data: coverpoint cov_tx_data { 
            bins zero     = {8'h00};
            bins alt_01   = {8'h55};
            bins alt_10   = {8'haa};
            bins lsb_only = {8'h01};
            bins msb_only = {8'h80};
            bins low      = {[8'h00 : 8'h3f]};
            bins mid      = {[8'h40 : 8'hbf]};
            bins high     = {[8'hc0 : 8'hff]};
        }
    endgroup

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        cov_tx_data = 0;
    endfunction
    function void write(uart_seq_item t);
        cov_tx_data = t.tx_data;
        cg_data.sample();
    endfunction
    function void report_phase(uvm_phase phase);
        `uvm_info(get_type_name(), $sformatf("Coverage: cg_data=%.1f%%", cg_data.get_coverage()), UVM_LOW)
    endfunction
endclass


class uart_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(uart_scoreboard)
    uvm_analysis_imp #(uart_seq_item, uart_scoreboard) ap_imp; // 수신부
    
    int pass_cnt = 0;
    int fail_cnt = 0;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        ap_imp = new("ap_imp", this);
    endfunction
    function void write(uart_seq_item item);
        if(item.tx_data !== item.rx_data) begin
            fail_cnt++;
            `uvm_error(get_type_name(), $sformatf("==Mismatch== tx_data=0x%02h, rx_data=0x%02h", item.tx_data, item.rx_data))
        end else begin
            pass_cnt++;
            `uvm_info(get_type_name(), $sformatf("==Match== tx_data=0x%02h, rx_data=0x%02h", item.tx_data, item.rx_data), UVM_MEDIUM)
        end
    endfunction
    function void report_phase(uvm_phase phase);
        `uvm_info(get_type_name(), "\n\n", UVM_LOW)
        `uvm_info(get_type_name(), "********** summary report **********", UVM_MEDIUM)
        `uvm_info(get_type_name(), $sformatf("  Total transactions: %0d", pass_cnt + fail_cnt), UVM_MEDIUM)
        `uvm_info(get_type_name(), $sformatf("  Pass: %0d", pass_cnt), UVM_MEDIUM)
        `uvm_info(get_type_name(), $sformatf("  Fail: %0d", fail_cnt), UVM_MEDIUM)
        `uvm_info(get_type_name(), "************************************", UVM_MEDIUM)

        if(fail_cnt > 0) begin
            `uvm_error(get_type_name(), $sformatf("TEST FAILED: %0d mismatches detected.", fail_cnt))
        end else begin
            `uvm_error(get_type_name(), $sformatf("TEST FAILED: %0d mismatches detected.", fail_cnt))
        end
        `uvm_info(get_type_name(), "\n\n", UVM_LOW)
    endfunction
endclass



class uart_monitor extends uvm_monitor;
    `uvm_component_utils(uart_monitor)
    uvm_analysis_port #(uart_seq_item) ap;  // 발신이 port
    uart_seq_item item = uart_seq_item::type_id::create("item");
    virtual uart_if u_if;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        ap = new("ap", this);
        if(!uvm_config_db #(virtual uart_if)::get(this, "", "u_if", u_if)) 
            `uvm_fatal(get_type_name(), "uart_if를 config_db에서 찾을 수 없음.");
    endfunction
    task run_phase(uvm_phase phase);
        forever begin
            @(u_if.mon_cb);
            if(u_if.mon_cb.tx_start) begin
                item.tx_data = u_if.mon_cb.tx_data;
                `uvm_info(get_type_name(), $sformatf("[TX] tx_data=0x%02h", item.tx_data), UVM_HIGH)
            end
            if(u_if.mon_cb.rx_valid) begin
                item.rx_data = u_if.mon_cb.rx_data;
                `uvm_info(get_type_name(), $sformatf("[RX] rx_data=0x%02h", item.rx_data), UVM_HIGH)
                ap.write(item);
            end
        end
    endtask
endclass

class uart_driver extends uvm_driver #(uart_seq_item);
    `uvm_component_utils(uart_driver)

    virtual uart_if u_if;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if(!uvm_config_db #(virtual uart_if)::get(this, "", "u_if", u_if)) begin
            `uvm_fatal(get_type_name(), "uart interface를 config db에서 찾을 수 없음.");
        end
    endfunction
    task run_phase(uvm_phase phase);
        uart_seq_item item;
        
        u_if.tx_data <= 8'h00;
        u_if.tx_start <= 1'b0;
        //@(negedge u_if.reset);
        wait (u_if.reset == 0);
        repeat(3) @(u_if.drv_cb);

        forever begin
            seq_item_port.get_next_item(item);
            
            while(u_if.drv_cb.tx_busy) @(u_if.drv_cb);
            @(u_if.drv_cb);
            u_if.tx_data  <= item.tx_data;
            u_if.tx_start <= 1'b1;
            @(u_if.drv_cb);
            u_if.tx_start <= 1'b0;
            `uvm_info(get_type_name(), $sformatf("전송 시작: tx_data=0x%02h", item.tx_data), UVM_HIGH)
            @(u_if.drv_cb);
            while(!u_if.drv_cb.tx_busy) @(u_if.drv_cb); // busy가 올라갈 때까지 대기
            while(u_if.drv_cb.tx_busy) @(u_if.drv_cb); // busy가 내려갈 때까지 대기
            `uvm_info(get_type_name(), $sformatf("전송 완료: tx_data=0x%02h", item.tx_data), UVM_HIGH)

            while(!u_if.drv_cb.rx_valid) @(u_if.drv_cb); // rx_data 수신 확인 
            item.rx_data = u_if.drv_cb.rx_data;
            `uvm_info(get_type_name(), $sformatf("Monitor 수신 완료: rx_data=0x%02h", item.rx_data), UVM_HIGH)
            @(u_if.drv_cb);

            seq_item_port.item_done();
        end
    endtask
endclass


class uart_agent extends uvm_agent;
    `uvm_component_utils(uart_agent)

    uart_driver drv;
    uart_monitor mon;
    uvm_sequencer#(uart_seq_item) sqr;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        drv = uart_driver::type_id::create("drv", this);
        mon = uart_monitor::type_id::create("mon", this);
        sqr = uvm_sequencer#(uart_seq_item)::type_id::create("sqr", this);
    endfunction
    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        drv.seq_item_port.connect(sqr.seq_item_export);
    endfunction
endclass


class uart_env extends uvm_env;
    `uvm_component_utils(uart_env)

    uart_agent agt;
    uart_scoreboard scb;
    uart_coverage cov;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agt = uart_agent::type_id::create("agt", this);
        scb = uart_scoreboard::type_id::create("scb", this);
        cov = uart_coverage::type_id::create("cov", this);
    endfunction
    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        agt.mon.ap.connect(scb.ap_imp);
        agt.mon.ap.connect(cov.analysis_export);
    endfunction
endclass


class uart_base_test extends uvm_test;
    `uvm_component_utils(uart_base_test)

    uart_env env;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = uart_env::type_id::create("env", this);
    endfunction
    task run_phase(uvm_phase phase);
        uart_rand_seq seq;
        
        phase.raise_objection(this);
        seq = uart_rand_seq::type_id::create("seq");
        seq.num_trans = 10;
        seq.start(env.agt.sqr);
        phase.drop_objection(this);
    endtask
endclass


module tb_uart_uvm();

    logic clk;
    logic reset;

    always #5 clk = ~clk;

    initial begin
        clk = 0;
        reset = 1;
        repeat(3) @(posedge clk);
        reset = 0;
        @(posedge clk);
    end

    uart_if u_if(clk, reset);

    uart #(
        .BAUD_RATE(9600)
    ) dut (
        .clk(clk),
        .reset(reset),
        .tx_data(u_if.tx_data),
        .tx_start(u_if.tx_start),
        .tx(u_if.tx),
        .tx_busy(u_if.tx_busy),
        .rx(u_if.rx),
        .rx_data(u_if.rx_data),
        .rx_valid(u_if.rx_valid)
    );

    assign u_if.rx = u_if.tx;

    initial begin
        uvm_config_db#(virtual uart_if)::set(null, "*", "u_if", u_if);
        run_test("uart_base_test");
    end

    initial begin
        $fsdbDumpfile("novas.fsdb");
        $fsdbDumpvars(0, tb_uart_uvm, "+all");
        //$fsdbDumpvars(0);
    end
endmodule
