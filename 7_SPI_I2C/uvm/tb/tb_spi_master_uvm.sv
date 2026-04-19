`include "uvm_macros.svh"
import uvm_pkg::*;

interface spiM_if(input logic clk, input logic reset);
	logic       cpol;
	logic       cpha;
	logic [7:0] clk_div;
	logic [7:0] tx_data;
	logic       start;
	logic [7:0] rx_data;
	logic       done;
	logic       busy;
	logic       sclk;
	logic       mosi;
	logic       miso;
	logic       cs_n;
endinterface


/***** object *****/
class spiM_seq_item extends uvm_sequence_item;
	rand logic 		 cpol;
	rand logic  	 cpha;
	rand logic [7:0] tx_data; // master to slave
	rand logic [7:0] miso_data; // slave to master
	logic 	   [7:0] mosi_collected;
	logic	   [7:0] miso_collected;

	constraint c_cpol { cpol inside { 0, 1 };}
	constraint c_cpha { cpha inside { 0, 1 };}

	`uvm_object_utils_begin(spiM_seq_item)
		`uvm_field_int(cpol, UVM_ALL_ON)
		`uvm_field_int(cpha, UVM_ALL_ON)
		`uvm_field_int(tx_data, UVM_ALL_ON)
		`uvm_field_int(miso_data, UVM_ALL_ON)
		`uvm_field_int(miso_collected, UVM_ALL_ON)
	`uvm_object_utils_end
	
	function new(string name = "spiM_seq_item");
		super.new(name);
	endfunction

	function string convert2string ();
		return $sformatf("cpol=%0b cpha=%0b tx_data=%0h miso_data=%0h", cpol, cpha, tx_data, miso_data);
	endfunction
endclass


class spiM_rand_seq extends uvm_sequence #(spiM_seq_item);
	`uvm_object_utils(spiM_rand_seq)
	int num_loop = 0;

	function new(string name = "spiM_rand_seq");
		super.new(name);
	endfunction

	virtual task body();
		for(int i = 0; i < num_loop; i++) begin
			spiM_seq_item item;
			item = spiM_seq_item::type_id::create("item");

			start_item(item);
				if(!item.randomize())
 	                   `uvm_fatal(get_type_name(), "randomization fail.");
			finish_item(item);
			`uvm_info(get_type_name(), item.convert2string(), UVM_MEDIUM)
		end
	endtask
endclass


/***** structure *****/
class spiM_driver extends uvm_driver #(spiM_seq_item);
	`uvm_component_utils(spiM_driver)
	uvm_analysis_port #(spiM_seq_item) ap;
	virtual spiM_if sif;

	function new(string name, uvm_component parent);
		super.new(name, parent);
		ap = new("ap", this);
	endfunction

	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		if(!uvm_config_db#(virtual spiM_if)::get(this, "", "sif", sif))
			`uvm_fatal(get_type_name(), "FAIL: CAN NOT FIND <r_if>")
		`uvm_info(get_type_name(), "build_phase COMPLETE.", UVM_HIGH);
	endfunction
	task drive_item(spiM_seq_item item);
 	   sif.tx_data <= item.tx_data;
 	   sif.cpol    <= item.cpol;
 	   sif.cpha    <= item.cpha;
 	   sif.start   <= 1'b1;
 	   @(posedge sif.clk);
 	   sif.start   <= 1'b0;

 	   for(int i=7; i>=0; i--) begin
 	       case ({item.cpol, item.cpha})
 	           // --- Mode 0 (CPOL=0, CPHA=0): Leading(Rise)=Sample, Trailing(Fall)=Setup ---
 	           2'b00: begin
 	               if (i == 7) wait(!sif.cs_n); // 첫 비트는 CS_N이 떨어지자마자 나감
 	               else @(negedge sif.sclk);    // 이후 비트는 하강 에지에서 Shift
 	               sif.miso <= item.miso_data[i];
 	           end

 	           // --- Mode 1 (CPOL=0, CPHA=1): Leading(Rise)=Setup, Trailing(Fall)=Sample ---
 	           2'b01: begin
 	               @(posedge sif.sclk);         // 상승 에지에서 Shift
 	               sif.miso <= item.miso_data[i];
 	           end

 	           // --- Mode 2 (CPOL=1, CPHA=0): Leading(Fall)=Sample, Trailing(Rise)=Setup ---
 	           2'b10: begin
 	               if (i == 7) wait(!sif.cs_n); // 첫 비트는 CS_N이 떨어지자마자 나감
 	               else @(posedge sif.sclk);    // 이후 비트는 상승 에지에서 Shift
 	               sif.miso <= item.miso_data[i];
 	           end

 	           // --- Mode 3 (CPOL=1, CPHA=1): Leading(Fall)=Setup, Trailing(Rise)=Sample ---
 	           2'b11: begin
 	               @(negedge sif.sclk);         // 하강 에지에서 Shift
 	               sif.miso <= item.miso_data[i];
 	           end
 	       endcase
    	end
		`uvm_info("DRV", "Wait for DONE start", UVM_LOW)
    	wait(sif.done);
		`uvm_info("DRV", "Wait for DONE finish", UVM_LOW)
    	@(posedge sif.clk);
	endtask
	virtual task run_phase(uvm_phase phase);
		spiM_seq_item item;
		
		`uvm_info(get_type_name(), "Waiting for reset release...", UVM_LOW)
	    wait(sif.reset == 1'b1);
	    wait(sif.reset == 1'b0);
	    repeat(5) @(posedge sif.clk);
	    `uvm_info(get_type_name(), "Reset released. Start driving!", UVM_LOW)

		forever begin
			seq_item_port.get_next_item(item);
			ap.write(item);
			drive_item(item);
			seq_item_port.item_done();
		end
	endtask
endclass


class spiM_monitor extends uvm_monitor;
	`uvm_component_utils(spiM_monitor)
	uvm_analysis_port #(spiM_seq_item) ap;
	virtual spiM_if sif;

	function new(string name, uvm_component parent);
		super.new(name, parent);
		ap = new("ap", this);
	endfunction

	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		if(!uvm_config_db#(virtual spiM_if)::get(this, "", "sif", sif))
			`uvm_fatal(get_type_name(), "FAIL: CAN NOT FIND <sif>")
		`uvm_info(get_type_name(), "build_phase COMPLETE.", UVM_HIGH);
	endfunction
	task collect_data();
    	spiM_seq_item item = spiM_seq_item::type_id::create("item");
    
    	wait(!sif.cs_n);
    	item.tx_data = sif.tx_data; // 입력을 바로 캡처 (비교 기준)

    	for(int i=7; i>=0; i--) begin
			case ({sif.cpol, sif.cpha})
        	    2'b00: begin // Mode 0
        	        @(posedge sif.sclk); // First Edge (Rising)에서 샘플링
    	    		item.mosi_collected[i] = sif.mosi;
        	    end
        	    2'b01: begin // Mode 1
        	        @(negedge sif.sclk); // Second Edge (Falling)에서 샘플링
    	    		item.mosi_collected[i] = sif.mosi;
        	    end
        	    2'b10: begin // Mode 2
        	        @(negedge sif.sclk); // First Edge (Falling)에서 샘플링
    	    		item.mosi_collected[i] = sif.mosi;
        	    end
        	    2'b11: begin // Mode 3
        	        @(posedge sif.sclk); // Second Edge (Rising)에서 샘플링
    	    		item.mosi_collected[i] = sif.mosi;
        	    end
        	endcase
    	end
    
    	wait(sif.done);

		`uvm_info("MON", "Wait for SCLK start", UVM_LOW)
		@(posedge sif.clk);
		`uvm_info("MON", "Wait for SCLK finish", UVM_LOW)
    	item.miso_collected = sif.rx_data;
		item.cpol = sif.cpol;
		item.cpha = sif.cpha;
		item.miso_data = item.miso_collected;
    	ap.write(item);
	endtask
	virtual task run_phase(uvm_phase phase);
		`uvm_info(get_type_name(), "Start SPI Master monitoring...", UVM_DEBUG);

		forever begin
			collect_data();	
		end
	endtask
endclass


class spiM_agent extends uvm_agent;
	`uvm_component_utils(spiM_agent)

	uvm_sequencer#(spiM_seq_item) sqr;
	spiM_driver drv;
	spiM_monitor mon;

	function new(string name, uvm_component parent);
		super.new(name, parent);
	endfunction

	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		sqr = uvm_sequencer#(spiM_seq_item)::type_id::create("sqr", this);
		drv = spiM_driver::type_id::create("drv", this);
		mon = spiM_monitor::type_id::create("mon", this);
	endfunction
	virtual function void connect_phase(uvm_phase phase);
		super.connect_phase(phase);
		drv.seq_item_port.connect(sqr.seq_item_export);
	endfunction
endclass


class spiM_scoreboard extends uvm_scoreboard;
	`uvm_component_utils(spiM_scoreboard)

	uvm_tlm_analysis_fifo #(spiM_seq_item) exp_fifo;
    uvm_tlm_analysis_fifo #(spiM_seq_item) act_fifo;

	int num_mosi = 0;
	int num_miso = 0;
	int num_err_mosi = 0;
	int num_err_miso = 0;

	function new(string name, uvm_component parent);
		super.new(name, parent);
		exp_fifo = new("exp_fifo", this);
		act_fifo = new("act_fifo", this);
	endfunction

	virtual task run_phase(uvm_phase phase);
        spiM_seq_item exp_item;
        spiM_seq_item act_item;

        forever begin
            // 두 FIFO에 데이터가 쌓일 때까지 기다렸다가 pop
            exp_fifo.get(exp_item);
            act_fifo.get(act_item);

            // 검증 1: MOSI 선로 데이터 확인 (이전 질문 내용)
            if (act_item.tx_data !== act_item.mosi_collected) begin
				num_err_mosi++;
                `uvm_error(get_type_name(), $sformatf("MOSI Protocol Error! Input:%h, Bus:%h", 
                            act_item.tx_data, act_item.mosi_collected))
			end else begin
				num_mosi++;
				`uvm_info(get_type_name(), $sformatf("==MOSI PASS== Input:%h BUS:%h", act_item.tx_data, act_item.mosi_collected), UVM_MEDIUM)
			end

            // 검증 2: MISO 데이터가 rx_data에 잘 들어왔는지 확인
            if (exp_item.miso_data !== act_item.miso_collected) begin
				num_err_miso++;
                `uvm_error(get_type_name(), $sformatf("MISO Integration Error! Sent:%h, Saved:%h", 
                            exp_item.miso_data, act_item.miso_collected))
            end else begin
				num_miso++;
                `uvm_info(get_type_name(), $sformatf("Success! Data:%h matched", act_item.miso_data), UVM_LOW)
            end
        end
    endtask
	virtual function void report_phase(uvm_phase phase);
		string result = ((num_err_miso + num_err_mosi) == 0) ? "** PASS **" : "** FAIL **";
        `uvm_info(get_type_name(), "========== SPI MASTER Summary ==========", UVM_MEDIUM)
        `uvm_info(get_type_name(), $sformatf(" Result      : %s", result), UVM_MEDIUM)
        `uvm_info(get_type_name(), $sformatf(" MISO PASSED : %0d", num_miso), UVM_MEDIUM)
        `uvm_info(get_type_name(), $sformatf(" MOSI PASSED : %0d", num_mosi), UVM_MEDIUM)
        `uvm_info(get_type_name(), $sformatf(" MISO ERROR  : %0d", num_err_miso), UVM_MEDIUM)
        `uvm_info(get_type_name(), $sformatf(" MOSI ERROR  : %0d", num_err_mosi), UVM_MEDIUM)
        `uvm_info(get_type_name(), "=======================================", UVM_MEDIUM)
	endfunction
endclass


class spiM_coverage extends uvm_subscriber #(spiM_seq_item);
	`uvm_component_utils(spiM_coverage)
	spiM_seq_item tx;

	covergroup spiM_cg;
		cp_cpol: coverpoint tx.cpol;
    	cp_cpha: coverpoint tx.cpha;
    	cp_mosi_data: coverpoint tx.tx_data { bins low    = {[8'h00:8'h3F]};
        								    	bins mid    = {[8'h40:8'hBF]};
        								   		bins high   = {[8'hc0:8'hFF]}; }
    	cp_miso_data: coverpoint tx.miso_data { bins low    = {[8'h00:8'h3F]};
        				    					  bins mid    = {[8'h40:8'hBF]};
        								   		  bins high   = {[8'hc0:8'hFF]}; }
		cross_mode: cross cp_cpol, cp_cpha;
	endgroup

	function new(string name, uvm_component parent);
		super.new(name, parent);
		spiM_cg = new();
	endfunction

	function void write(spiM_seq_item t);
		tx = t;
		spiM_cg.sample();
	endfunction
	virtual function void report_phase(uvm_phase phase);
        `uvm_info(get_type_name(), "  ===== Coverage Summary =====  ", UVM_LOW);
        `uvm_info(get_type_name(), $sformatf(" mosi_data : %.1f%%", spiM_cg.cp_mosi_data.get_coverage()), UVM_LOW);
        `uvm_info(get_type_name(), $sformatf(" miso_data : %.1f%%", spiM_cg.cp_miso_data.get_coverage()), UVM_LOW);
        `uvm_info(get_type_name(), $sformatf("      mode : %.1f%%", spiM_cg.cross_mode.get_coverage()), UVM_LOW);
        `uvm_info(get_type_name(), "  ===== Coverage Summary =====  \n\n", UVM_LOW);
    endfunction
endclass


class spiM_environment extends uvm_env;
	`uvm_component_utils(spiM_environment)

	spiM_agent agt;
	spiM_scoreboard scb;
	spiM_coverage cov;

	function new(string name, uvm_component parent);
		super.new(name, parent);
	endfunction

	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		agt = spiM_agent::type_id::create("agt", this);
		scb = spiM_scoreboard::type_id::create("scb", this);
		cov = spiM_coverage::type_id::create("cov", this);
	endfunction
	virtual function void connect_phase(uvm_phase phase);
		super.connect_phase(phase);
		agt.drv.ap.connect(scb.exp_fifo.analysis_export);
		agt.mon.ap.connect(scb.act_fifo.analysis_export);
		agt.mon.ap.connect(cov.analysis_export);
	endfunction
endclass


class spiM_test extends uvm_test;
	`uvm_component_utils(spiM_test)

	spiM_environment env;

	function new(string name, uvm_component parent);
		super.new(name, parent);
	endfunction

	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		env = spiM_environment::type_id::create("env", this);
	endfunction
	virtual task run_phase(uvm_phase phase);
		spiM_rand_seq seq;

		phase.raise_objection(this);
			seq = spiM_rand_seq::type_id::create("seq");
			seq.num_loop = 40;
			seq.start(env.agt.sqr);
		phase.drop_objection(this);
	endtask
endclass



/***** dut *****/
module tb_spi_master_uvm();
	logic clk;
	logic reset;

	initial begin
		clk = 0;
		sif.clk_div = 4;
		forever #5 clk = ~clk;
	end

	initial begin
        reset = 1;
        sif.clk_div = 4; 
        
        #20;
        reset = 0;
    end

	spiM_if sif(clk, reset);
	
	spi_master dut (
    	.clk(clk),
    	.reset(reset),
    	.cpol(sif.cpol),
    	.cpha(sif.cpha),
    	.clk_div(sif.clk_div),
    	.tx_data(sif.tx_data),
    	.start(sif.start),
    	.rx_data(sif.rx_data),
    	.done(sif.done),
    	.busy(sif.busy),
    	.sclk(sif.sclk),
    	.mosi(sif.mosi),
    	.miso(sif.miso),
    	.cs_n(sif.cs_n)
	);

	initial begin
		uvm_config_db#(virtual spiM_if)::set(null, "*", "sif", sif);
		run_test("spiM_test");
	end
	
    initial begin
        $fsdbDumpfile("novas.fsdb");
        $fsdbDumpvars(0, tb_spi_master_uvm, "+all");
    end
endmodule