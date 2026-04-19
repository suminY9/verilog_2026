`include "uvm_macros.svh"
import uvm_pkg::*;

interface spiS_if(input logic clk, input logic reset);
    // SPI Bus (Master Driven)
    logic sclk;
    logic mosi;
    logic cs_n;
    logic miso; // Slave Driven

    // Slave Logic Interface (Internal monitoring)
    logic [7:0] i_data;
    logic       i_done;

    int sclk_half_period;

    // Clocking block for Synchronous Drive/Sample
    // 시스템 클락(clk)에 동기화된 Slave의 반응을 정확히 잡기 위함
    clocking cb @(posedge clk);
        input  miso, i_data, i_done;
        output sclk, mosi, cs_n;
    endclocking
endinterface


/***** object *****/
class spiS_seq_item extends uvm_sequence_item;
    // [데이터 무결성용] Master가 보낼 데이터
    rand logic [7:0] tx_data;
    
    // [SCLK 동기화 검증용] SCLK 반주기(Half Period) 설정
    // 시스템 클락(clk) 주기에 대한 배수로 설정하여 Slave의 동기화 로직을 테스트
    rand int sclk_half_period; 

    // Monitor가 수집한 결과값 저장용
    logic [7:0] rx_data_collected;

    `uvm_object_utils_begin(spiS_seq_item)
        `uvm_field_int(tx_data, UVM_ALL_ON)
        `uvm_field_int(sclk_half_period, UVM_ALL_ON)
        `uvm_field_int(rx_data_collected, UVM_ALL_ON)
    `uvm_object_utils_end

    // Constraint: SCLK는 시스템 클락보다 충분히 느려야 동기화가 가능함 (최소 4배 권장)
    constraint c_sclk_stable {
        sclk_half_period inside {[2:20]}; // 시스템 클락 2~20주기 대기
    }

    function new(string name = "spiS_seq_item");
        super.new(name);
    endfunction
endclass


class spiS_stress_seq extends uvm_sequence #(spiS_seq_item);
	`uvm_object_utils(spiS_stress_seq)
	int num_loop = 10;

	function new(string name = "spiM_rand_seq");
		super.new(name);
	endfunction

    virtual task body();
        repeat(400) begin
            req = spiS_seq_item::type_id::create("req");
            start_item(req);
            // SCLK 주기를 시스템 클락의 4배~20배 사이로 랜덤화 (동기화 안정성 테스트)
            if(!req.randomize()) 
                `uvm_fatal("SEQ", "Randomization failed")
            finish_item(req);
        end
    endtask
endclass


/***** structure *****/
class spiS_driver extends uvm_driver #(spiS_seq_item);
	`uvm_component_utils(spiS_driver)
	uvm_analysis_port #(spiS_seq_item) ap;
	virtual spiS_if sif;

	function new(string name, uvm_component parent);
		super.new(name, parent);
		ap = new("ap", this);
	endfunction

	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		if(!uvm_config_db#(virtual spiS_if)::get(this, "", "sif", sif))
			`uvm_fatal(get_type_name(), "FAIL: CAN NOT FIND <sif>")
		`uvm_info(get_type_name(), "build_phase COMPLETE.", UVM_HIGH);
	endfunction
	task drive_item(spiS_seq_item item);
	    // Setup SPI Mode 0
	    sif.cs_n <= 1'b1;
	    sif.sclk <= 1'b0;
	    sif.mosi <= 1'b0;
        sif.sclk_half_period <= item.sclk_half_period;
	    repeat(2) @(posedge sif.clk);

	    sif.cs_n <= 1'b0; // CS_N Assert

	    for (int i=7; i>=0; i--) begin
	        sif.mosi <= item.tx_data[i];
	
	        // sclk_half_period 만큼 시스템 클락 대기 (동기화 테스트 핵심)
	        repeat(item.sclk_half_period) @(posedge sif.clk); 
	
	        sif.sclk <= 1'b1; // Rising Edge (Sample)
	
	        repeat(item.sclk_half_period) @(posedge sif.clk);
	
	        sif.sclk <= 1'b0; // Falling Edge (Setup next bit)
	    end

	    repeat(2) @(posedge sif.clk);
	    sif.cs_n <= 1'b1; // CS_N De-assert
	endtask
	virtual task run_phase(uvm_phase phase);
		spiS_seq_item item;
		
		`uvm_info(get_type_name(), "Waiting for reset release...", UVM_LOW)
	    wait(sif.reset == 1'b1); // 리셋이 걸리는 것을 확인 (Active High 기준)
	    wait(sif.reset == 1'b0); // 리셋이 해제되는 것을 확인
	    repeat(5) @(posedge sif.clk); // 해제 후 안정화를 위해 몇 클락 더 대기
	    `uvm_info(get_type_name(), "Reset released. Start driving!", UVM_LOW)

		forever begin
			seq_item_port.get_next_item(item);
			ap.write(item);
			drive_item(item);
			seq_item_port.item_done();
		end
	endtask
endclass


class spiS_monitor extends uvm_monitor;
    `uvm_component_utils(spiS_monitor)
    uvm_analysis_port #(spiS_seq_item) ap;
    virtual spiS_if sif; 


	function new(string name, uvm_component parent);
		super.new(name, parent);
		ap = new("ap", this);
	endfunction

	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		if(!uvm_config_db#(virtual spiS_if)::get(this, "", "sif", sif))
			`uvm_fatal(get_type_name(), "FAIL: CAN NOT FIND <sif>")
		`uvm_info(get_type_name(), "build_phase COMPLETE.", UVM_HIGH);
	endfunction
    task collect_data();
        forever begin
            spiS_seq_item item = spiS_seq_item::type_id::create("item");
            
            // 1. Slave가 수신 완료 신호를 보낼 때까지 대기
            wait(sif.i_done === 1'b1);
            
            // 2. Slave의 출력 포트 데이터 캡처
            item.rx_data_collected = sif.i_data;
            
            // 3. (옵션) 당시의 SCLK 속도를 기록하고 싶다면 수동으로 계산하거나 
            // 드라이버에서 넘겨받은 값을 사용할 수 있습니다.
            
            item.tx_data = sif.i_data;
            item.sclk_half_period = sif.sclk_half_period;
            ap.write(item);
            `uvm_info("MON", $sformatf("Captured Slave i_data: %h", item.rx_data_collected), UVM_MEDIUM)
            
            // 4. i_done이 떨어질 때까지 대기 (Handshake)
            wait(sif.i_done === 1'b0);
        end
    endtask

    virtual task run_phase(uvm_phase phase);
        collect_data();
    endtask
endclass


class spiS_agent extends uvm_agent;
	`uvm_component_utils(spiS_agent)

	uvm_sequencer#(spiS_seq_item) sqr;
	spiS_driver drv;
	spiS_monitor mon;

	function new(string name, uvm_component parent);
		super.new(name, parent);
	endfunction

	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		sqr = uvm_sequencer#(spiS_seq_item)::type_id::create("sqr", this);
		drv = spiS_driver::type_id::create("drv", this);
		mon = spiS_monitor::type_id::create("mon", this);
	endfunction
	virtual function void connect_phase(uvm_phase phase);
		super.connect_phase(phase);
		drv.seq_item_port.connect(sqr.seq_item_export);
	endfunction
endclass


class spiS_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(spiS_scoreboard)

    // FIFO 선언
    uvm_tlm_analysis_fifo #(spiS_seq_item) exp_fifo; // Driver로부터 수신 (Expected)
    uvm_tlm_analysis_fifo #(spiS_seq_item) act_fifo; // Monitor로부터 수신 (Actual)

    // 통계용 변수
    int match_cnt = 0;
    int error_cnt = 0;

    function new(string name = "spiS_scoreboard", uvm_component parent = null);
        super.new(name, parent);
        exp_fifo = new("exp_fifo", this);
        act_fifo = new("act_fifo", this);
    endfunction

    virtual task run_phase(uvm_phase phase);
        spiS_seq_item exp, act;

        forever begin
            // 1. 양쪽 FIFO에서 데이터가 들어올 때까지 대기
            exp_fifo.get(exp);
            act_fifo.get(act);

            `uvm_info("SCB", $sformatf("Comparing Trans: SCLK_Half_Period=%0d clk cycles", exp.sclk_half_period), UVM_MEDIUM)

            // [검증 1: 데이터 무결성 체크]
            // Master(Driver)가 쏜 8-bit MOSI와 Slave가 복원한 i_data를 비교
            if (exp.tx_data === act.rx_data_collected) begin
                match_cnt++;
                `uvm_info("PASS", $sformatf("Data Integrity OK! [Sent: %h | Recv: %h]", 
                          exp.tx_data, act.rx_data_collected), UVM_LOW)
            end else begin
                error_cnt++;
                `uvm_error("FAIL", $sformatf("Data Mismatch! [Sent: %h | Recv: %h] at SCLK_Half_Period: %0d", 
                           exp.tx_data, act.rx_data_collected, exp.sclk_half_period))
            end

            // [검증 2: 동기화 및 타이밍 체크]
            // Slave가 i_done을 발생시켜 데이터를 유효하게 출력했는지 여부 확인
            // Monitor가 act_item을 보냈다는 것 자체가 i_done을 감지했다는 의미임.
            if (act.rx_data_collected === 8'hXX || act.rx_data_collected === 8'hZZ) begin
                `uvm_error("PROTOCOL_ERR", "Slave output is invalid (X or Z). Synchronization failed!")
            end
        end
    endtask
    virtual function void report_phase(uvm_phase phase);
		string result = (!error_cnt) ? "** PASS **" : "** FAIL **";
        `uvm_info(get_type_name(), "========== SPI SLAVE Summary ==========", UVM_MEDIUM)
        `uvm_info(get_type_name(), $sformatf(" Result      : %s", result), UVM_MEDIUM)
        `uvm_info(get_type_name(), $sformatf(" PASSED      : %0d", match_cnt), UVM_MEDIUM)
        `uvm_info(get_type_name(), $sformatf(" ERROR       : %0d", error_cnt), UVM_MEDIUM)
        `uvm_info(get_type_name(), "=======================================", UVM_MEDIUM)
	endfunction
endclass


class spiS_coverage extends uvm_subscriber #(spiS_seq_item);
    `uvm_component_utils(spiS_coverage)

    spiS_seq_item t;

    covergroup spiS_cg;
        // 1. 데이터 무결성: 다양한 데이터 패턴이 전송되었는가?
        cp_tx_data: coverpoint t.tx_data { bins low    = {[8'h00:8'h3F]};
        								   bins mid    = {[8'h40:8'hBF]};
        								   bins high   = {[8'hc0:8'hFF]}; }

        // 2. SCLK 동기화: 다양한 클락 속도에서 테스트되었는가?
        cp_sclk_speed: coverpoint t.sclk_half_period {
            bins fast   = {2, 3};      // 동기화 한계점 근처 (위험)
            bins mid    = {[4:10]};    // 일반적 속도
            bins slow   = {[11:20]};   // 안정적 속도
        }

        // 3. Cross Coverage: 특정 데이터가 특정 속도에서 깨지지 않는가?
        cross_data_speed: cross cp_tx_data, cp_sclk_speed;
    endgroup

    function new(string name, uvm_component parent);
        super.new(name, parent);
        spiS_cg = new();
    endfunction

    function void write(spiS_seq_item t);
        this.t = t;
        spiS_cg.sample();
    endfunction
	virtual function void report_phase(uvm_phase phase);
	    `uvm_info(get_type_name(), "  ===== Slave Coverage Summary =====  ", UVM_LOW);
	    `uvm_info(get_type_name(), $sformatf(" mosi_data  : %.1f%%", spiS_cg.cp_tx_data.get_coverage()), UVM_LOW);
	    `uvm_info(get_type_name(), $sformatf(" sclk_speed : %.1f%%", spiS_cg.cp_sclk_speed.get_coverage()), UVM_LOW);
	    `uvm_info(get_type_name(), $sformatf(" cross_sync : %.1f%%", spiS_cg.cross_data_speed.get_coverage()), UVM_LOW);
	    `uvm_info(get_type_name(), "  ==================================  \n", UVM_LOW);
	endfunction
endclass


class spiS_environment extends uvm_env;
	`uvm_component_utils(spiS_environment)

	spiS_agent agt;
	spiS_scoreboard scb;
	spiS_coverage cov;

	function new(string name, uvm_component parent);
		super.new(name, parent);
	endfunction

	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		agt = spiS_agent::type_id::create("agt", this);
		scb = spiS_scoreboard::type_id::create("scb", this);
		cov = spiS_coverage::type_id::create("cov", this);
	endfunction
	virtual function void connect_phase(uvm_phase phase);
		super.connect_phase(phase);
		agt.drv.ap.connect(scb.exp_fifo.analysis_export);
		agt.mon.ap.connect(scb.act_fifo.analysis_export);
        agt.mon.ap.connect(cov.analysis_export);
	endfunction
endclass


class spiS_test extends uvm_test;
	`uvm_component_utils(spiS_test)

	spiS_environment env;

	function new(string name, uvm_component parent);
		super.new(name, parent);
	endfunction

	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		env = spiS_environment::type_id::create("env", this);
	endfunction
	virtual task run_phase(uvm_phase phase);
		spiS_stress_seq seq;

		phase.raise_objection(this);
			seq = spiS_stress_seq::type_id::create("seq");
			seq.num_loop = 400;
			seq.start(env.agt.sqr);
		phase.drop_objection(this);
	endtask
endclass



/***** dut *****/
module tb_spi_slave_uvm();
	logic clk;
	logic reset;

	initial begin
		clk = 0;
		forever #5 clk = ~clk;
	end

	initial begin
        reset = 1;
        
        #20;
        reset = 0;
    end

	spiS_if sif(clk, reset);
	
	spi_slave dut (
    	.clk(clk),
    	.reset(reset),
    	.sclk(sif.sclk),
    	.mosi(sif.mosi),
    	.miso(sif.miso),
    	.cs_n(sif.cs_n),
    	.i_done(sif.i_done),
    	.i_data(sif.i_data)
	);

	initial begin
		uvm_config_db#(virtual spiS_if)::set(null, "*", "sif", sif);
		run_test("spiS_test");
	end
	
    initial begin
        $fsdbDumpfile("novas.fsdb");
        $fsdbDumpvars(0, tb_spi_slave_uvm, "+all");
    end
endmodule