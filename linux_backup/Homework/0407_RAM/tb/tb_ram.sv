`include "uvm_macros.svh"
import uvm_pkg::*;

interface ram_if(input logic clk);
	logic 	     we;
	logic [7:0]  addr;
	logic [15:0] wdata;
	logic [15:0] rdata;
endinterface


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

	function new(string name = "ram_write_seq");
		super.new(name);
	endfunction

	virtual task body();
		ram_seq_item item;

		for(int i = 0; i<16; i++) begin
			item = ram_seq_item::type_id::create($sformatf("item_%0d", i));

			start_item(item);
			if(!item.randomize() with { we == 1; addr == i; }) begin
				`uvm_error(get_type_name(), "Randomization failed")
			end
			finish_item(item);

			`uvm_info(get_type_name(), item.convert2string(), UVM_HIGH);
		end
	endtask
endclass


class ram_read_seq extends uvm_sequence #(ram_seq_item);
	`uvm_object_utils(ram_read_seq)

	function new(string name = "ram_read_seq");
		super.new(name);
	endfunction

	virtual task body();
		ram_seq_item item;

		for(int i = 0; i < 16; i++) begin
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
			write_seq.start(m_sequencer);

		`uvm_info(get_type_name(), "===== Phase 2: Read =====", UVM_MEDIUM)
			read_seq = ram_read_seq::type_id::create("read_seq");
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
		r_if.we <= item.we;
		r_if.addr <= item.addr;
		r_if.wdata <= item.wdata;
		@(posedge r_if.clk);
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
	logic [15:0] comp_ram[logic [7:0]];

	function new(string name, uvm_component parent);
		super.new(name, parent);
	endfunction

	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		if(!uvm_config_db#(virtual ram_if)::get(this, "", "r_if", r_if))
			`uvm_fatal(get_type_name(), "FAIL: CAN NOT FIND <r_if>")
		`uvm_info(get_type_name(), "build_phase COMPLETE.", UVM_HIGH);
	endfunction
	virtual task run_phase(uvm_phase phase);
		`uvm_info(get_type_name(), "run_phase START", UVM_DEBUG);

		forever begin
			@(posedge r_if.clk);
			`uvm_info(get_type_name(), "@(posege r_if.clk) ***WAIT***", UVM_DEBUG)
			#1;

			if(r_if.we) begin
				comp_ram[r_if.addr] = r_if.wdata;
				`uvm_info(get_type_name(), $sformatf("==WRITE== Mem[%0d]=%0h", r_if.addr, r_if.wdata), UVM_LOW)
			end else begin
				if(comp_ram.exists(r_if.addr)) begin //**************************
					if(r_if.rdata == comp_ram[r_if.addr]) begin
						`uvm_info(get_type_name(), $sformatf("==PASS==  Mem[%0d]=%0h, expect_data=%0h", r_if.addr, r_if.rdata, comp_ram[r_if.addr]), UVM_LOW)
					end else begin
						`uvm_error(get_type_name(), $sformatf("==FAIL==  Mem[%0d]!=%0h, expect_data=%0h", r_if.addr, r_if.rdata, comp_ram[r_if.addr]))
					end
				end
			end
		end
	endtask
	virtual function void report_phase(uvm_phase phase);
		super.report_phase(phase);
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

	function new(string name, uvm_component parent);
		super.new(name, parent);
		agt = ram_agent::type_id::create("agt", this);
		`uvm_info(get_type_name(), "CREATE agt", UVM_DEBUG);
	endfunction
endclass


class ram_test extends uvm_test;
	`uvm_component_utils(ram_test)

	ram_environment env;

	function new(string name, uvm_component parent);
		super.new(name, parent);
		`uvm_info(get_type_name(), "CREATE new", UVM_DEBUG);
	endfunction

	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		env = ram_environment::type_id::create("env", this);
		`uvm_info(get_type_name(), "CREATE env", UVM_DEBUG);
	endfunction
	virtual task run_phase(uvm_phase phase);
		ram_write_seq write_seq;
		ram_read_seq read_seq;

		phase.raise_objection(this);
			write_seq = ram_write_seq::type_id::create("write_seq");
			write_seq.start(env.agt.sqr);

			read_seq = ram_read_seq::type_id::create("read_seq");
			read_seq.start(env.agt.sqr);
		phase.drop_objection(this);
	endtask
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