`include "uvm_macros.svh"
import uvm_pkg::*;

interface ram_if(input logic clk);
	logic 	     we;
	logic [7:0]  addr;
	logic [15:0] wdata;
	logic [15:0] rdata;

	clocking drv_cb @(posedge clk);
		default input #1step output #0;
		output we;
		output addr;
		output wdata;
	endclocking

	clocking mon_cb @(posedge clk);
		default input #1step;
		input we;
		input addr;
		input wdata;
		input rdata;
	endclocking
endinterface


/* verification scenario
* 1. WRITE 512 times random addr, random wdata -> to comp_ram, dut
* 2. READ all data addr 0~255 & compare with comp_ram
* 3. check coverage */

/***** sequence *****/
class ram_seq_item extends uvm_sequence_item;
	rand bit	  we;
	rand logic [7:0]  addr;
	rand logic [15:0] wdata;
	logic [15:0] rdata;

	`uvm_object_utils_begin(ram_seq_item)
		`uvm_field_int(we, UVM_ALL_ON)
		`uvm_field_int(addr, UVM_ALL_ON)
		`uvm_field_int(wdata, UVM_ALL_ON)
		`uvm_field_int(rdata, UVM_ALL_ON)
	`uvm_object_utils_end
	
	function new(string name = "ram_seq_item");
		super.new(name);
	endfunction

	function string convert2string ();
		return $sformatf("we=0%b addr=%0h wdata=%0h rdata=%0h", we, addr, wdata, rdata);
	endfunction
endclass


class ram_write_seq extends uvm_sequence #(ram_seq_item);
	`uvm_object_utils(ram_write_seq)
	int write_cnt;

	function new(string name = "ram_write_seq");
		super.new(name);
		write_cnt = 256;
	endfunction

	virtual task body();
		ram_seq_item item;

		for(int i = 0; i<write_cnt; i++) begin
			item = ram_seq_item::type_id::create($sformatf("item_%0d", i));

			start_item(item);
			if(!item.randomize() with { we == 1; }) begin
				`uvm_error(get_type_name(), "Randomization failed")
			end
			finish_item(item);

			`uvm_info(get_type_name(), item.convert2string(), UVM_HIGH);
		end
	endtask
endclass


class ram_read_seq extends uvm_sequence #(ram_seq_item);
	`uvm_object_utils(ram_read_seq)
	int read_cnt;

	function new(string name = "ram_read_seq");
		super.new(name);
		read_cnt = 16;
	endfunction

	virtual task body();
		ram_seq_item item;

		for(int i = 0; i < read_cnt; i++) begin
			item = ram_seq_item::type_id::create($sformatf("item_%0d", i));

			start_item(item);
			if(!item.randomize() with { we == 0; addr == i; }) begin
				`uvm_error(get_type_name(), "Randomization failed")
			end
			finish_item(item);
		end
	endtask
endclass


class ram_master_seq extends uvm_sequence #(ram_seq_item);
	`uvm_object_utils(ram_master_seq)

	function new(string name = "ram_master_seq");
		super.new(name);
	endfunction

	virtual task body();
		ram_write_seq write_seq;
		ram_read_seq read_seq;
		
		`uvm_info(get_type_name(), "===== Phase 1: Write =====", UVM_MEDIUM)
			write_seq = ram_write_seq::type_id::create("write_seq");
			write_seq.write_cnt = 512;
			write_seq.start(m_sequencer);

		`uvm_info(get_type_name(), "===== Phase 2: Read =====", UVM_MEDIUM)
			read_seq = ram_read_seq::type_id::create("read_seq");
			read_seq.read_cnt = 256;
			read_seq.start(m_sequencer);

		`uvm_info(get_type_name(), "===== Master Sequence DONE =====", UVM_MEDIUM)
	endtask
endclass



/***** structure *****/
class ram_driver extends uvm_driver #(ram_seq_item);
	`uvm_component_utils(ram_driver)
	virtual ram_if r_if;

	function new(string name, uvm_component parent);
		super.new(name, parent);
	endfunction

	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		if(!uvm_config_db#(virtual ram_if)::get(this, "", "r_if", r_if))
			`uvm_fatal(get_type_name(), "FAIL: CAN NOT FIND <r_if>")
		`uvm_info(get_type_name(), "build_phase COMPLETE.", UVM_HIGH);
	endfunction
	virtual task drive_item(ram_seq_item item);
		@(r_if.drv_cb);
		r_if.drv_cb.we <= item.we;
		r_if.drv_cb.addr <= item.addr;
		r_if.drv_cb.wdata <= item.wdata;
		if(!item.we) begin
			@(r_if.drv_cb);
		end
	endtask
	virtual task run_phase(uvm_phase phase);
		ram_seq_item item;
		forever begin
			seq_item_port.get_next_item(item);
			drive_item(item);
			seq_item_port.item_done();
		end
	endtask
endclass


class ram_monitor extends uvm_monitor;
	`uvm_component_utils(ram_monitor)
	virtual ram_if r_if;
	uvm_analysis_port #(ram_seq_item) ap;

	function new(string name, uvm_component parent);
		super.new(name, parent);
		ap = new("ap", this);
	endfunction

	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		if(!uvm_config_db#(virtual ram_if)::get(this, "", "r_if", r_if))
			`uvm_fatal(get_type_name(), "FAIL: CAN NOT FIND <r_if>")
	endfunction
	virtual task run_phase(uvm_phase phase);
		logic [7:0] last_addr;

		forever begin
			ram_seq_item item = ram_seq_item::type_id::create("item");

			@(r_if.mon_cb);
			item.we = r_if.mon_cb.we;
			item.addr = r_if.mon_cb.addr;
			item.wdata = r_if.mon_cb.wdata;
			if(!r_if.mon_cb.we) begin
				@(r_if.mon_cb);
				item.rdata = r_if.mon_cb.rdata;
			end

			ap.write(item);
			`uvm_info(get_type_name(), item.convert2string(), UVM_MEDIUM);
			//if(r_if.we) begin
			//	comp_ram[r_if.addr] = r_if.wdata;
			//	`uvm_info(get_type_name(), $sformatf("==WRITE== Mem[%0d]=%0h", r_if.addr, r_if.wdata), UVM_LOW)
			//end else begin
			//	if(comp_ram.exists(r_if.addr)) begin //**************************
			//		if(r_if.rdata == comp_ram[r_if.addr]) begin
			//			`uvm_info(get_type_name(), $sformatf("==PASS==  Mem[%0d]=%0h, expect_data=%0h", r_if.addr, r_if.rdata, comp_ram[r_if.addr]), UVM_LOW)
			//		end else begin
			//			`uvm_error(get_type_name(), $sformatf("==FAIL==  Mem[%0d]!=%0h, expect_data=%0h", r_if.addr, r_if.rdata, comp_ram[r_if.addr]))
			//		end
			//	end
			//end
		end
	endtask
endclass


class ram_coverage extends uvm_subscriber#(ram_seq_item);
	`uvm_component_utils(ram_coverage)

	ram_seq_item item;

	covergroup ram_cg;
		cp_we: coverpoint item.we { bins write = {1}; bins read = {0}; }
		cp_addr: coverpoint item.addr { bins zero = {0};
										bins low  = {[1:127]};
										bins high = {[128:254]};
										bins max  = {255}; }
		cx_write_addr: cross cp_we, cp_addr;
	endgroup

	function new(string name, uvm_component parent);
		super.new(name, parent);
		ram_cg = new();
	endfunction

	virtual function void write(ram_seq_item t);
		item = t;
		ram_cg.sample();
		`uvm_info(get_type_name(), $sformatf("counter_cb sampled: %s", item.convert2string()), UVM_MEDIUM)
	endfunction
	virtual function void report_phase(uvm_phase phase);
		`uvm_info(get_type_name(), "\n\n===== Coverage Summary =====", UVM_LOW);
		`uvm_info(get_type_name(), $sformatf("   Overall: %.1f%%", ram_cg.get_coverage()), UVM_LOW);
		`uvm_info(get_type_name(), $sformatf("   we: %.1f%%", ram_cg.cp_we.get_coverage()), UVM_LOW);
		`uvm_info(get_type_name(), $sformatf("   addr: %.1f%%", ram_cg.cp_addr.get_coverage()), UVM_LOW);
		`uvm_info(get_type_name(), $sformatf("   cross(we, addr): %.1f%%", ram_cg.cx_write_addr.get_coverage()), UVM_LOW);
		`uvm_info(get_type_name(), "===== Coverage Summary =====\n\n", UVM_LOW);
	endfunction
endclass


class ram_scoreboard extends uvm_scoreboard;
	`uvm_component_utils(ram_scoreboard)
	uvm_analysis_imp #(ram_seq_item, ram_scoreboard) ap_imp;

	logic [15:0] comp_ram[0:255];
	int error_cnt;
	int match_cnt;
	bit first_tr;

	function new(string name, uvm_component parent);
		super.new(name, parent);
		ap_imp = new("ap_imp", this);
		error_cnt = 0;
		match_cnt = 0;
		first_tr = 1;
	endfunction

	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);
	endfunction

	virtual function void write(ram_seq_item item);
		`uvm_info(get_type_name(), $sformatf("Reveibed: %s", item.convert2string()), UVM_MEDIUM);

		// Write comp_ram, dut
		if(first_tr) begin
			`uvm_info(get_type_name(), $sformatf("Initial"), UVM_MEDIUM)
			first_tr = 0;
			return;
		end
		if(item.we) begin
			comp_ram[item.addr] = item.wdata;
		end else begin
		// Read & compare -> verification
			if(comp_ram[item.addr] !== item.rdata) begin
				`uvm_error(get_type_name(), $sformatf("==MISMATCH!== comp_ram[%0d]=%0h, actual ram[%0d]=%0h", item.addr, comp_ram[item.addr], item.addr, item.rdata))
				error_cnt++;
			end else begin
				`uvm_info(get_type_name(), $sformatf("== MATCH! == comp_ram[%0d]=%0h, actual ram[%0d]=%0h", item.addr, comp_ram[item.addr], item.addr, item.rdata), UVM_LOW)
				match_cnt++;
			end
		end
	endfunction
	virtual function void report_phase(uvm_phase phase);
		super.report_phase(phase);
		`uvm_info(get_type_name(), " ===== Scoreboard Summary =====", UVM_LOW);
		`uvm_info(get_type_name(), $sformatf("  Total transactions: %0d", match_cnt + error_cnt), UVM_LOW)
		`uvm_info(get_type_name(), $sformatf("  Matches: %0d", match_cnt), UVM_LOW)
		`uvm_info(get_type_name(), $sformatf("  Error: %0d", error_cnt), UVM_LOW)
		
		if(error_cnt > 0) begin
			`uvm_error(get_type_name(), $sformatf("TEST FAILED: %0d mismatches detected.", error_cnt))
		end else begin
			`uvm_info(get_type_name(), $sformatf("TEST PASSED: %0d mtches detected.", error_cnt), UVM_LOW)
		end
	endfunction
endclass


class ram_agent extends uvm_agent;
	`uvm_component_utils(ram_agent)

	uvm_sequencer#(ram_seq_item) sqr;
	ram_driver drv;
	ram_monitor mon;

	function new(string name, uvm_component parent);
		super.new(name, parent);
	endfunction

	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		sqr = uvm_sequencer#(ram_seq_item)::type_id::create("sqr", this);
		`uvm_info(get_type_name(), "CREATE sqr", UVM_DEBUG);
		drv = ram_driver::type_id::create("drv", this);
		`uvm_info(get_type_name(), "CREATE drv", UVM_DEBUG);
		mon = ram_monitor::type_id::create("mon", this);
		`uvm_info(get_type_name(), "CREATE mon", UVM_DEBUG);
	endfunction
	virtual function void connect_phase(uvm_phase phase);
		super.connect_phase(phase);
		drv.seq_item_port.connect(sqr.seq_item_export);
	endfunction
endclass


class ram_environment extends uvm_env;
	`uvm_component_utils(ram_environment)

	ram_agent agt;
	ram_scoreboard scb;
	ram_coverage cov;

	function new(string name, uvm_component parent);
		super.new(name, parent);
		agt = ram_agent::type_id::create("agt", this);
		scb = ram_scoreboard::type_id::create("scb", this);
		cov = ram_coverage::type_id::create("cov", this);
	endfunction

	virtual function void connect_phase(uvm_phase phase);
		super.connect_phase(phase);
		agt.mon.ap.connect(scb.ap_imp);
		agt.mon.ap.connect(cov.analysis_export);
	endfunction
endclass


class ram_test extends uvm_test;
	`uvm_component_utils(ram_test)

	ram_environment env;

	function new(string name, uvm_component parent);
		super.new(name, parent);
	endfunction

	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		env = ram_environment::type_id::create("env", this);
		`uvm_info(get_type_name(), "CREATE env", UVM_DEBUG);
	endfunction
	virtual task run_phase(uvm_phase phase);
		ram_master_seq master_seq;

		phase.raise_objection(this);
			master_seq = ram_master_seq::type_id::create("master_seq");
			master_seq.start(env.agt.sqr);
			#1000;
		phase.drop_objection(this);
	endtask
	virtual function void report_phase(uvm_phase phase);
		uvm_report_server svr = uvm_report_server::get_server();
		if(svr.get_severity_count(UVM_ERROR) == 0)
			`uvm_info(get_type_name(), "===== TEST PASS! =====", UVM_LOW)
		else `uvm_info(get_type_name(), "===== TEST FAIL! =====", UVM_LOW)
		uvm_top.print_topology();
	endfunction
endclass



/***** dut *****/
module tb_ram();
	logic clk;

	initial begin
		clk = 0;
		forever #5 clk = ~clk;
	end

	ram_if r_if(clk);

	ram dut(
		.clk(clk),
		.we(r_if.we),
		.addr(r_if.addr),
		.wdata(r_if.wdata),
		.rdata(r_if.rdata)
	);

	initial begin
		uvm_config_db#(virtual ram_if)::set(null, "*", "r_if", r_if);
		run_test("ram_test");
	end
endmodule