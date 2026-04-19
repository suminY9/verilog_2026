`include "uvm_macros.svh"
import uvm_pkg::*;

//------------------------------------------------------------------------------
// 1. Interface
//------------------------------------------------------------------------------
interface i2c_if(input logic clk, input logic reset);
    logic scl;
    wire  sda;
    logic sda_out, sda_en;
    assign sda = sda_en ? sda_out : 1'bz;

    logic [7:0] i_data; // RTL Output
    logic       i_done; // RTL Output 완료 펄스
endinterface

//------------------------------------------------------------------------------
// 2. Sequence Item & Sequence
//------------------------------------------------------------------------------
class i2c_item extends uvm_sequence_item;
    rand logic [6:0] addr;
    rand logic       is_read;
    rand logic [7:0] data;

    `uvm_object_utils_begin(i2c_item)
        `uvm_field_int(addr,    UVM_ALL_ON)
        `uvm_field_int(is_read, UVM_ALL_ON)
        `uvm_field_int(data,    UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "i2c_item"); super.new(name); endfunction
endclass

// [Sequence] 특정 시나리오 생성
class i2c_write_seq extends uvm_sequence #(i2c_item);
    `uvm_object_utils(i2c_write_seq)
    function new(string name = "i2c_write_seq"); super.new(name); endfunction

    virtual task body();
        repeat(30) begin
            req = i2c_item::type_id::create("req");
            start_item(req);
            if(!req.randomize() with { 
                addr == 7'h40;   // Slave 주소 고정
                is_read == 1'b0; // Write 동작 고정
            }) `uvm_fatal("SEQ", "Randomization failed")
            finish_item(req);
        end
    endtask
endclass

//------------------------------------------------------------------------------
// 3. Coverage Collector (Subscriber)
//------------------------------------------------------------------------------
class i2c_coverage extends uvm_subscriber #(i2c_item);
    `uvm_component_utils(i2c_coverage)

    i2c_item tr;
    
    covergroup i2c_cg;
        option.per_instance = 1;
        
        // 주소 커버리지
        ADDR: coverpoint tr.addr {
            bins target = {7'h40};
            bins legal  = {[7'h00:7'h7F]};
        }
        // 데이터 패턴 커버리지
        DATA: coverpoint tr.data {
            bins zeros = {8'h00};
            bins ones  = {8'hFF};
            bins alt   = {8'hAA, 8'h55};
            bins others = {[8'h01:8'hFE]};
        }
        // 동작 모드
        MODE: coverpoint tr.is_read {
            bins write = {0};
            bins read  = {1};
        }
        // 크로스 커버리지
        ADDR_x_MODE: cross ADDR, MODE;
    endgroup

    function new(string name, uvm_component parent);
        super.new(name, parent);
        i2c_cg = new();
    endfunction

    virtual function void write(i2c_item t);
        this.tr = t;
        i2c_cg.sample();
    endfunction

    virtual function void report_phase(uvm_phase phase);
        `uvm_info("COV", $sformatf("Overall Coverage: %0.2f%%", i2c_cg.get_inst_coverage()), UVM_LOW)
    endfunction
endclass

//------------------------------------------------------------------------------
// 4. Monitor & Driver (Agent 구성요소)
//------------------------------------------------------------------------------
class i2c_monitor extends uvm_monitor;
    `uvm_component_utils(i2c_monitor)
    virtual i2c_if vif;
    uvm_analysis_port #(i2c_item) ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        ap = new("ap", this);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        void'(uvm_config_db#(virtual i2c_if)::get(this, "", "vif", vif));
    endfunction

    virtual task run_phase(uvm_phase phase);
    i2c_item item;
    forever begin
        // 1. Start Condition 감지
        wait(vif.scl === 1'b1 && vif.sda === 1'b1);
        wait(vif.sda === 1'b0);
        
        item = i2c_item::type_id::create("item");

        // 2. Address (7-bit) + RW (1-bit) = 8 bits
        for(int i=7; i>=0; i--) begin
            @(posedge vif.scl);
            #5ns; // SCL High 구간의 중간쯤에서 안정적으로 샘플링
            if(i > 0) item.addr[i-1] = (vif.sda === 1'b0) ? 1'b0 : 1'b1;
            else      item.is_read = (vif.sda === 1'b0) ? 1'b0 : 1'b1;
        end

        // 3. [중요] Address ACK 구간 건너뛰기
        @(posedge vif.scl); 
        #5ns; 

        // 4. Data (8-bit) 수집
        for(int i=7; i>=0; i--) begin
            @(posedge vif.scl);
            #5ns; // 안정적인 샘플링
            item.data[i] = (vif.sda === 1'b0) ? 1'b0 : 1'b1;
        end

        // 5. [중요] Data ACK 구간 건너뛰기
        @(posedge vif.scl);
        #5ns;

        // 6. Stop Condition 대기
        wait(vif.scl === 1'b1);
        wait(vif.sda === 1'b1);
        
        ap.write(item);
    end
endtask
endclass

class i2c_driver extends uvm_driver #(i2c_item);
    `uvm_component_utils(i2c_driver)
    virtual i2c_if vif;

    function new(string name, uvm_component parent); super.new(name, parent); endfunction

    virtual function void build_phase(uvm_phase phase);
        void'(uvm_config_db#(virtual i2c_if)::get(this, "", "vif", vif));
    endfunction

    task drive_byte(logic [7:0] data);
        vif.sda_en <= 1;
        for(int i=7; i>=0; i--) begin
            vif.sda_out <= data[i]; #10ns;
            vif.scl <= 1; #20ns;
            vif.scl <= 0; #10ns;
        end
        vif.sda_en <= 0; vif.scl <= 1; #20ns; // ACK 구간
        vif.scl <= 0; #10ns;
    endtask

    virtual task run_phase(uvm_phase phase);
        i2c_item item;
        forever begin
            seq_item_port.get_next_item(item);
            vif.sda_en <= 1; vif.sda_out <= 1; vif.scl <= 1; #20ns;
            vif.sda_out <= 0; #20ns; vif.scl <= 0; #10ns; // Start
            drive_byte({item.addr, item.is_read});
            drive_byte(item.data);
            vif.sda_en <= 1; vif.sda_out <= 0; #10ns; // Stop
            vif.scl <= 1; #20ns; vif.sda_out <= 1; #20ns;
            vif.sda_en <= 0;
            seq_item_port.item_done();
        end
    endtask
endclass

//------------------------------------------------------------------------------
// 5. Scoreboard
//------------------------------------------------------------------------------
class i2c_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(i2c_scoreboard)
    uvm_tlm_analysis_fifo #(i2c_item) bus_fifo;
    virtual i2c_if vif;
    
    // 데이터를 순서대로 저장할 큐
    i2c_item monitor_q[$]; 
    int match_count = 0;
    int mismatch_count = 0;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        bus_fifo = new("bus_fifo", this);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        void'(uvm_config_db#(virtual i2c_if)::get(this, "", "vif", vif));
    endfunction

    virtual task run_phase(uvm_phase phase);
        // Thread 1: Monitor 데이터를 큐에 저장
        fork
            forever begin
                i2c_item item;
                bus_fifo.get(item);
                monitor_q.push_back(item);
            end
            
            // Thread 2: RTL i_done 신호에 맞춰 큐에서 꺼내 비교
            forever begin
                i2c_item exp_item;
                @(posedge vif.i_done); // RTL 전송 완료 시점까지 대기
                #1ps; // 시뮬레이션 델타 타임 지연
                
                if (monitor_q.size() > 0) begin
                    exp_item = monitor_q.pop_front();
                    if (vif.i_data === exp_item.data) begin
                        `uvm_info("SCB_PASS", $sformatf("MATCH! Data: 0x%h", vif.i_data), UVM_LOW)
                        match_count++;
                    end else begin
                        `uvm_error("SCB_FAIL", $sformatf("MISMATCH! Bus:0x%h, RTL:0x%h", exp_item.data, vif.i_data))
                        mismatch_count++;
                    end
                end else begin
                    `uvm_error("SCB_EMPTY", "RTL asserted i_done but no data captured by monitor!")
                end
            end
        join
    endtask

    virtual function void report_phase(uvm_phase phase);
        `uvm_info("REPORT", $sformatf("MATCH: %0d, MISMATCH: %0d", match_count, mismatch_count), UVM_LOW)
    endfunction
endclass

//------------------------------------------------------------------------------
// 6. Agent & Environment
//------------------------------------------------------------------------------
class i2c_agent extends uvm_agent;
    `uvm_component_utils(i2c_agent)
    i2c_driver drv;
    i2c_monitor mon;
    uvm_sequencer#(i2c_item) sqr;

    function new(string name, uvm_component parent); super.new(name, parent); endfunction

    virtual function void build_phase(uvm_phase phase);
        drv = i2c_driver::type_id::create("drv", this);
        mon = i2c_monitor::type_id::create("mon", this);
        sqr = uvm_sequencer#(i2c_item)::type_id::create("sqr", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        drv.seq_item_port.connect(sqr.seq_item_export);
    endfunction
endclass

class i2c_env extends uvm_env;
    `uvm_component_utils(i2c_env)
    i2c_agent agt;
    i2c_scoreboard scb;
    i2c_coverage cov;

    function new(string name, uvm_component parent); super.new(name, parent); endfunction

    virtual function void build_phase(uvm_phase phase);
        agt = i2c_agent::type_id::create("agt", this);
        scb = i2c_scoreboard::type_id::create("scb", this);
        cov = i2c_coverage::type_id::create("cov", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        agt.mon.ap.connect(scb.bus_fifo.analysis_export);
        agt.mon.ap.connect(cov.analysis_export);
    endfunction
endclass

//------------------------------------------------------------------------------
// 7. Test & Top
//------------------------------------------------------------------------------
class i2c_test extends uvm_test;
    `uvm_component_utils(i2c_test)
    i2c_env env;
    function new(string name, uvm_component parent); super.new(name, parent); endfunction

    virtual function void build_phase(uvm_phase phase);
        env = i2c_env::type_id::create("env", this);
    endfunction

    virtual task run_phase(uvm_phase phase);
        i2c_write_seq seq = i2c_write_seq::type_id::create("seq");
        phase.raise_objection(this);
        seq.start(env.agt.sqr);
        #500ns;
        phase.drop_objection(this);
    endtask
endclass

module tb_top;
    logic clk, reset;
    initial begin
        clk = 0;
        reset = 1;
        #50 reset = 0;
    end
    always #5 clk = ~clk;

    i2c_if vif(clk, reset);
    i2c_slave dut (
        .clk(vif.clk), .reset(vif.reset),
        .scl(vif.scl), .sda(vif.sda),
        .i_data(vif.i_data), .i_done(vif.i_done)
    );

    initial begin
        uvm_config_db#(virtual i2c_if)::set(null, "*", "vif", vif);
        run_test("i2c_test");
    end

    initial begin
        $fsdbDumpfile("novas.fsdb");
        $fsdbDumpvars(0, tb_top, "+all");
    end
endmodule