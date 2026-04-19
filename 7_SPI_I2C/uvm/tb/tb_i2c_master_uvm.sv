`include "uvm_macros.svh"
import uvm_pkg::*;

interface i2cM_if(input logic clk, input logic reset);
    logic       cmd_start;
    logic       cmd_write;
    logic       cmd_read;
    logic       cmd_stop;
    logic [7:0] tx_data;
    logic       ack_in;
    logic [7:0] rx_data;
    logic       done;
    logic       ack_out;
    logic       busy;
	logic drive_sda_en; 
    logic sda_out;      

    logic scl;
    wire  sda;

    // Pull-up 저항 시뮬레이션 (중요: x 상태 방지)
    assign (weak0, weak1) sda = 1'b1;
    
    // Driver가 제어할 때만 sda를 드라이브
    assign sda = drive_sda_en ? (sda_out ? 1'bz : 1'b0) : 1'bz;
endinterface


/***** object *****/
typedef enum { CMD_START, CMD_WRITE, CMD_READ, CMD_STOP } i2c_cmd_e;

class i2cM_seq_item extends uvm_sequence_item;
    rand i2c_cmd_e  cmd;
    rand logic [7:0] data;     // Write시 전송 데이터 / Read시 Slave가 줄 데이터(가상)
    rand logic       ack_in;   // Master가 Read 후 보낼 ACK/NACK 값
    
    logic [7:0]      rx_data;  // Master가 읽어온 값
    logic            ack_out;  // Master가 수신한 ACK (from Slave)

    `uvm_object_utils_begin(i2cM_seq_item)
        `uvm_field_enum(i2c_cmd_e, cmd, UVM_ALL_ON)
        `uvm_field_int(data, UVM_ALL_ON)
        `uvm_field_int(ack_in, UVM_ALL_ON)
        `uvm_field_int(rx_data, UVM_ALL_ON)
        `uvm_field_int(ack_out, UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "i2cM_seq_item");
        super.new(name);
    endfunction
endclass


class i2cM_write_read_seq extends uvm_sequence #(i2cM_seq_item);
    `uvm_object_utils(i2cM_write_read_seq)
	int num_loop = 10;

	function new(string name = "i2cM_write_read_seq");
		super.new(name);
	endfunction

    virtual task body();
		repeat(num_loop) begin
  	    	i2cM_seq_item req;
	
  	    	// 1. START
  	    	`uvm_do_with(req, {cmd == CMD_START;})
  	    	// 2. WRITE (Address)
  	    	`uvm_do_with(req, {cmd == CMD_WRITE; data == 8'hA0;})
  	    	// 3. WRITE (Data)
  	    	`uvm_do_with(req, {cmd == CMD_WRITE; data == 8'h55;})
  	    	// 4. STOP
  	    	`uvm_do_with(req, {cmd == CMD_STOP;})
		end
    endtask
endclass


/***** structure *****/
class i2cM_driver extends uvm_driver #(i2cM_seq_item);
    `uvm_component_utils(i2cM_driver)
	uvm_analysis_port #(i2cM_seq_item) ap;
    virtual i2cM_if vif;
    logic drive_sda_en;
    logic sda_out;

    function new(string name, uvm_component parent);
        super.new(name, parent);
		ap = new("ap", this);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if(!uvm_config_db#(virtual i2cM_if)::get(this, "", "vif", vif))
            `uvm_fatal("DRV", "vif error")
    endfunction

    virtual task run_phase(uvm_phase phase);
        reset_signals();
        forever begin
            seq_item_port.get_next_item(req);
            drive_transfer(req);
            seq_item_port.item_done();
        end
    endtask

    task reset_signals();
        vif.cmd_start <= 0; vif.cmd_write <= 0; vif.cmd_read <= 0;
        vif.cmd_stop <= 0; drive_sda_en <= 0;
        wait(!vif.reset);
    endtask

    task drive_transfer(i2cM_seq_item item);
    	case(item.cmd)
    	    CMD_START: begin
    	        vif.cmd_start <= 1; @(posedge vif.clk); vif.cmd_start <= 0;
    	        wait(vif.done);
    	    end
    	    CMD_WRITE: begin
    	        vif.tx_data <= item.data;
    	        vif.cmd_write <= 1; @(posedge vif.clk); vif.cmd_write <= 0;
    	        // Slave ACK 시뮬레이션
    	        repeat(8) @(posedge vif.scl); 
    	        @(negedge vif.scl);
    	        vif.drive_sda_en <= 1; vif.sda_out <= 0; 
    	        @(negedge vif.scl);
    	        vif.drive_sda_en <= 0;
    	        wait(vif.done);
    	    end
    	    CMD_READ: begin
    	        vif.ack_in <= item.ack_in;
    	        vif.cmd_read <= 1; @(posedge vif.clk); vif.cmd_read <= 0;
    	        // Slave Data 전송 시뮬레이션
    	        for(int i=7; i>=0; i--) begin
    	            @(negedge vif.scl); // SCL이 Low일 때 데이터를 바꿔줘야 함
    	            vif.drive_sda_en <= 1; 
    	            vif.sda_out <= item.data[i];
    	        end
    	        @(negedge vif.scl);
    	        vif.drive_sda_en <= 0; // Master가 ACK를 줄 차례이므로 드라이브 해제
    	        wait(vif.done);
    	    end
    	    CMD_STOP: begin
    	        vif.cmd_stop <= 1; @(posedge vif.clk); vif.cmd_stop <= 0;
    	        wait(vif.done);
    	    end
    	endcase
    	ap.write(item);
	endtask
endclass


class i2cM_monitor extends uvm_monitor;
    `uvm_component_utils(i2cM_monitor)
    virtual i2cM_if vif;
    uvm_analysis_port #(i2cM_seq_item) ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        ap = new("ap", this);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if(!uvm_config_db#(virtual i2cM_if)::get(this, "", "vif", vif))
            `uvm_fatal("NOVIF", "Virtual interface not found")
    endfunction

    virtual task run_phase(uvm_phase phase);
    forever begin
        i2cM_seq_item item = i2cM_seq_item::type_id::create("item");

        // 1. 명령 시작 신호가 뜰 때까지 '절차적으로' 대기
        // 이전 루프의 잔상을 지우기 위해 level-sensitive wait를 사용하되, 
        // 감지 직후의 상태를 유지합니다.
        wait(vif.cmd_start || vif.cmd_write || vif.cmd_read || vif.cmd_stop);
        
        // 2. 신호가 뜬 직후의 커맨드를 즉시 고정 (Latching)
        if      (vif.cmd_start) item.cmd = CMD_START;
        else if (vif.cmd_stop)  item.cmd = CMD_STOP;
        else if (vif.cmd_write) item.cmd = CMD_WRITE;
        else if (vif.cmd_read)  item.cmd = CMD_READ;

        // 3. 데이터 샘플링 구간
        case (item.cmd)
            CMD_WRITE: begin
                // [수정] 8번의 SCL 상승 엣지를 추적
                for (int i=7; i>=0; i--) begin
                    @(posedge vif.scl); 
                    #2; // 안정적인 샘플링을 위해 딜레이를 약간 늘림 (2ns)
                    item.data[i] = vif.sda;
                end
                // 9번째 SCL (Slave ACK)
                @(posedge vif.scl); #2;
                item.ack_out = vif.sda;
            end
            
            CMD_READ: begin
                for (int i=7; i>=0; i--) begin
                    @(posedge vif.scl);
                    #2;
                    item.rx_data[i] = vif.sda;
                end
                @(posedge vif.scl); #2;
                item.ack_in = vif.sda;
            end
        endcase

        // 4. 완료 대기 (테스트벤치 태스크와 동일한 시점)
        // 여기서 wait(done)만 하면 안 되고, done이 뜬 '후'의 clk 엣지까지 봐야 합니다.
        wait(vif.done);
        @(posedge vif.clk); 

        // 데이터 전송
        ap.write(item);

        // 5. [가장 중요] 신호가 완전히 Clear 될 때까지 '확실히' 대기
        // cmd 신호들이 내려가지 않으면 다음 forever 루프가 바로 시작되어 버립니다.
        wait(!vif.cmd_start && !vif.cmd_write && !vif.cmd_read && !vif.cmd_stop);
        
        // 다음 명령과의 충돌을 막기 위해 1클락 더 여유를 둡니다.
		repeat(5) @(posedge vif.clk);
    end
endtask
endclass


class i2cM_agent extends uvm_agent;
	`uvm_component_utils(i2cM_agent)

	uvm_sequencer#(i2cM_seq_item) sqr;
	i2cM_driver drv;
	i2cM_monitor mon;

	function new(string name, uvm_component parent);
		super.new(name, parent);
	endfunction

	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		sqr = uvm_sequencer#(i2cM_seq_item)::type_id::create("sqr", this);
		drv = i2cM_driver::type_id::create("drv", this);
		mon = i2cM_monitor::type_id::create("mon", this);
	endfunction
	virtual function void connect_phase(uvm_phase phase);
		super.connect_phase(phase);
		drv.seq_item_port.connect(sqr.seq_item_export);
	endfunction
endclass


class i2cM_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(i2cM_scoreboard)
	uvm_tlm_analysis_fifo #(i2cM_seq_item) exp_fifo;
    uvm_tlm_analysis_fifo #(i2cM_seq_item) act_fifo; 

    function new(string name, uvm_component parent);
        super.new(name, parent);
		exp_fifo = new("exp_fifo", this);
        act_fifo = new("act_fifo", this);
    endfunction

    virtual task run_phase(uvm_phase phase);
        i2cM_seq_item exp_item;
        i2cM_seq_item act_item;

        forever begin
            // 두 FIFO에서 아이템이 들어올 때까지 대기 (Blocking Get)
            exp_fifo.get(exp_item);
            act_fifo.get(act_item);

            // 데이터 비교 수행
            compare_data(exp_item, act_item);
        end
    endtask

    // 세부 비교 로직
    virtual function void compare_data(i2cM_seq_item exp, i2cM_seq_item act);
        bit error = 0;

        // 1. 명령(Command) 일치 여부 확인
        if (exp.cmd !== act.cmd) begin
            `uvm_error("SCB_FAIL", $sformatf("Command Mismatch! Exp: %s, Act: %s", exp.cmd.name(), act.cmd.name()))
            error = 1;
        end

        // 2. Write 동작 시 데이터 무결성 체크
        if (exp.cmd == CMD_WRITE) begin
            if (exp.data !== act.data) begin
                `uvm_error("SCB_FAIL", $sformatf("Write Data Mismatch! Exp: 8'h%h, Act: 8'h%h", exp.data, act.data))
                error = 1;
            end
            // Slave가 준 ACK가 정상적으로 관측되었는지 확인 (보통 Slave ACK는 0(Low)이어야 함)
            if (act.ack_out !== 1'b0) begin
                `uvm_warning("SCB_WARN", "Slave NACK detected during Write operation.")
            end
        end

        // 3. Read 동작 시 데이터 무결성 체크
        if (exp.cmd == CMD_READ) begin
            // Read는 Driver(Slave 역할)가 준 데이터가 DUT(Master)를 거쳐 Monitor에 잘 찍혔는지 확인
            if (exp.data !== act.rx_data) begin
                `uvm_error("SCB_FAIL", $sformatf("Read Data Mismatch! Exp: 8'h%h, Act: 8'h%h", exp.data, act.rx_data))
                error = 1;
            end
        end

        // 통과 시 로그 출력
        if (!error) begin
            `uvm_info("SCB_PASS", $sformatf("Check Success: Cmd=%s, Data=8'h%h", exp.cmd.name(), (exp.cmd == CMD_READ) ? act.rx_data : act.data), UVM_LOW)
        end
    endfunction
endclass


class i2cM_coverage extends uvm_subscriber #(i2cM_seq_item);
    `uvm_component_utils(i2cM_coverage)
    
    covergroup i2c_cg;
        cp_cmd: coverpoint t.cmd;
        cp_data: coverpoint t.data {
            bins corners[] = {8'h00, 8'hFF, 8'h55, 8'hAA};
            bins ranges = {[8'h01:8'hFE]};
        }
        cross_cmd_data: cross cp_cmd, cp_data;
    endgroup

    i2cM_seq_item t;
    function new(string name, uvm_component parent);
        super.new(name, parent);
        i2c_cg = new();
    endfunction

    function void write(i2cM_seq_item t);
        this.t = t;
        i2c_cg.sample();
    endfunction
endclass


class i2cM_environment extends uvm_env;
	`uvm_component_utils(i2cM_environment)

	i2cM_agent agt;
	i2cM_scoreboard scb;
	i2cM_coverage cov;

	function new(string name, uvm_component parent);
		super.new(name, parent);
	endfunction

	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		agt = i2cM_agent::type_id::create("agt", this);
		scb = i2cM_scoreboard::type_id::create("scb", this);
		cov = i2cM_coverage::type_id::create("cov", this);
	endfunction
	virtual function void connect_phase(uvm_phase phase);
		super.connect_phase(phase);
		agt.drv.ap.connect(scb.exp_fifo.analysis_export);
		agt.mon.ap.connect(scb.act_fifo.analysis_export);
		agt.mon.ap.connect(cov.analysis_export);
	endfunction
endclass


class i2cM_test extends uvm_test;
	`uvm_component_utils(i2cM_test)

	i2cM_environment env;

	function new(string name, uvm_component parent);
		super.new(name, parent);
	endfunction

	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		env = i2cM_environment::type_id::create("env", this);
	endfunction
	virtual task run_phase(uvm_phase phase);
		i2cM_write_read_seq seq;

		phase.raise_objection(this);
			seq = i2cM_write_read_seq::type_id::create("seq");
			seq.num_loop = 40;
			seq.start(env.agt.sqr);
		phase.drop_objection(this);
	endtask
endclass



/***** dut *****/
module tb_i2c_master_uvm();
	logic clk;
	logic reset;
	i2cM_if vif(clk, reset);

	initial begin
		clk = 0;
		forever #5 clk = ~clk;
	end

	initial begin
        reset = 1;
		vif.ack_in = 0;
		
        #20;
        reset = 0;
    end

	I2C_Master dut(
    	.clk(clk),
    	.reset(reset),
    	.cmd_start(vif.cmd_start),
    	.cmd_write(vif.cmd_write),
    	.cmd_read(vif.cmd_read),
    	.cmd_stop(vif.cmd_stop),
    	.tx_data(vif.tx_data),
    	.ack_in(vif.ack_in),
    	.rx_data(vif.rx_data),
    	.done(vif.done),
    	.ack_out(vif.ack_out),
    	.busy(vif.busy),
    	.scl(vif.scl),
    	.sda(vif.sda)
	);

	initial begin
		uvm_config_db#(virtual i2cM_if)::set(null, "*", "vif", vif);
		run_test("i2cM_test");
	end
	
    initial begin
        $fsdbDumpfile("novas.fsdb");
        $fsdbDumpvars(0, tb_i2c_master_uvm, "+all");
    end
endmodule