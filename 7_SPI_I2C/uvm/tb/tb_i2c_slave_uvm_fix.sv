`include "uvm_macros.svh"
import uvm_pkg::*;

interface i2cS_if(input logic clk, input logic reset);
    logic scl;
    wire  sda;
    logic sda_out, sda_en;
    assign sda = sda_en ? sda_out : 1'bz;

    logic [7:0] i_data;
    logic       i_done;
endinterface

/***** object *****/
class i2cS_seq_item extends uvm_sequence_item;
         logic [6:0] addr    = 7'b100_0000;
         logic       is_read = 0;
    rand logic [7:0] input_data;
         logic [7:0] collected_data;

    `uvm_object_utils_begin(i2cS_seq_item)
        `uvm_field_int(addr,          UVM_ALL_ON)
        `uvm_field_int(is_read,       UVM_ALL_ON)
        `uvm_field_int(input_data,    UVM_ALL_ON)
    `uvm_object_utils_end

	function new(string name = "i2cS_seq_item");
		super.new(name);
	endfunction

	function string convert2string ();
		return $sformatf("input_data=%0h", input_data);
	endfunction
endclass


class i2cS_rand_seq extends uvm_sequence #(i2cS_seq_item);
    `uvm_object_utils(i2cS_rand_seq)
    int num_loop = 0;

    function new(string name = "i2cS_rand_seq");
        super.new(name);
    endfunction

    virtual task body();
		for(int i = 0; i < num_loop; i++) begin
            i2cS_seq_item item;
            item = i2cS_seq_item::type_id::create("item");

            start_item(item);
                if(!item.randomize())
     	                   `uvm_fatal(get_type_name(), "randomization fail.");
    		finish_item(item);
    		`uvm_info(get_type_name(), item.convert2string(), UVM_MEDIUM)
        end
    endtask
endclass


/***** structure *****/
class i2cS_driver extends uvm_driver #(i2cS_seq_item);
    `uvm_component_utils(i2cS_driver)
    uvm_analysis_port #(i2cS_seq_item) ap;
    virtual i2cS_if iif;

	function new(string name, uvm_component parent);
		super.new(name, parent);
		ap = new("ap", this);
	endfunction

	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);
        if(!uvm_config_db#(virtual i2cS_if)::get(this, "", "iif", iif))
			`uvm_fatal(get_type_name(), "FAIL: CAN NOT FIND <iif>")
		`uvm_info(get_type_name(), "build_phase COMPLETE.", UVM_HIGH);
	endfunction
    task drive_byte(logic [7:0] input_data);
        // data send
        iif.sda_en <= 1;
        for (int i = 7; i >= 0; i--) begin
            iif.sda_out <= input_data[i]; #10ns;
            iif.scl <= 1; #20ns;
            iif.scl <= 0; #10ns;
        end
        // ACK
        iif.sda_en <= 0;
        iif.scl    <= 1; #20ns;
        iif.scl    <= 0; #10ns;
    endtask
    virtual task run_phase(uvm_phase phase);
        i2cS_seq_item item;
        forever begin
            seq_item_port.get_next_item(item);
            iif.sda_en  <= 1;
            iif.sda_out <= 1;
            iif.scl     <= 1; #20ns;
            drive_byte({item.addr, item.is_read});
            drive_byte(item.input_data);
            iif.sda_en  <= 1;
            iif.sda_out <= 0; #10ns;
            iif.scl     <= 1; #20ns;
            iif.sda_out <= 1; #20ns;
            iif.sda_en  <= 0;
            ap.write(item);
            seq_item_port.item_done();
        end
    endtask
endclass

class i2cS_monitor extends uvm_monitor;
    `uvm_component_utils(i2cS_monitor)
    uvm_analysis_port #(i2cS_seq_item) ap;
    virtual i2cS_if iif;

    function new(string name, uvm_component parent);
		super.new(name, parent);
		ap = new("ap", this);
	endfunction

	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);
        if(!uvm_config_db#(virtual i2cS_if)::get(this, "", "iif", iif))
			`uvm_fatal(get_type_name(), "FAIL: CAN NOT FIND <iif>")
		`uvm_info(get_type_name(), "build_phase COMPLETE.", UVM_HIGH);
	endfunction
    task collect_data();
        i2cS_seq_item item;

        wait(iif.scl === 1'b1 && iif.sda === 1'b1);
        wait(iif.sda === 1'b0);
        item = i2cS_seq_item::type_id::create("item");

        repeat(8) @(posedge iif.scl); // address bit collect skip
        @(negedge iif.scl);
        
        for(int i = 7; i >= 0; i--) begin
            @(posedge iif.scl)
            #1ns;
            item.collected_data[i] = iif.sda;
        if (item.collected_data[i] === 1'bx || item.collected_data[i] === 1'bz) begin
             `uvm_warning("MON_DEBUG", $sformatf("Bit %0d is floating (Z/X)!", i))
        end
        end

        @(negedge iif.scl);

        wait(iif.scl === 1'b1);
        wait(iif.sda === 1'b1);

        item.input_data = item.collected_data;
        `uvm_info(get_type_name(), "Data Collected!", UVM_MEDIUM)
        ap.write(item);
    endtask
    virtual task run_phase(uvm_phase phase);
		`uvm_info(get_type_name(), "Start SPI Master monitoring...", UVM_DEBUG);

		forever begin
			collect_data();	
		end
	endtask
endclass


class i2cS_agent extends uvm_agent;
    `uvm_component_utils(i2cS_agent)

    uvm_sequencer #(i2cS_seq_item) sqr;
    i2cS_driver drv;
    i2cS_monitor mon;

    function new(string name, uvm_component parent);
		super.new(name, parent);
	endfunction

	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		sqr = uvm_sequencer#(i2cS_seq_item)::type_id::create("sqr", this);
		drv = i2cS_driver::type_id::create("drv", this);
		mon = i2cS_monitor::type_id::create("mon", this);
	endfunction
	virtual function void connect_phase(uvm_phase phase);
		super.connect_phase(phase);
		drv.seq_item_port.connect(sqr.seq_item_export);
	endfunction
endclass


class i2cS_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(i2cS_scoreboard)

    uvm_tlm_analysis_fifo #(i2cS_seq_item) exp_fifo;
    uvm_tlm_analysis_fifo #(i2cS_seq_item) act_fifo;

    int num_pass;
    int num_error;

    function new(string name, uvm_component parent);
		super.new(name, parent);
		exp_fifo = new("exp_fifo", this);
		act_fifo = new("act_fifo", this);
	endfunction

	virtual task run_phase(uvm_phase phase);
        i2cS_seq_item exp_item;
        i2cS_seq_item act_item;

        forever begin
            exp_fifo.get(exp_item);
            act_fifo.get(act_item);

            if(exp_item.input_data !== act_item.collected_data) begin
                num_error++;
                `uvm_error(get_type_name(), $sformatf("collected_data Error! Input:%h, collected:%h", exp_item.input_data, act_item.collected_data))
            end else begin
                num_pass++;
                `uvm_info(get_type_name(), $sformatf("==PASS== Input:%h, collected:%h", exp_item.input_data, act_item.collected_data), UVM_MEDIUM)
            end
        end
    endtask
    virtual function void report_phase(uvm_phase phase);
        string result = (!num_error) ? "** PASS **" : "** FAIL **";
        `uvm_info(get_type_name(), "========== I2C SLAVE Summary ==========", UVM_MEDIUM)
        `uvm_info(get_type_name(), $sformatf(" Result      : %s", result), UVM_MEDIUM)
        `uvm_info(get_type_name(), $sformatf(" PASSED      : %d", num_pass), UVM_MEDIUM)
        `uvm_info(get_type_name(), $sformatf(" ERROR       : %d", num_error), UVM_MEDIUM)
        `uvm_info(get_type_name(), "=======================================", UVM_MEDIUM)
    endfunction
endclass


class i2cS_coverage extends uvm_subscriber #(i2cS_seq_item);
    `uvm_component_utils(i2cS_coverage)
    i2cS_seq_item tx;

    covergroup i2cS_cg;
    cp_input_data: coverpoint tx.input_data { bins low    = {[8'h00:8'h3F]};
        								      bins mid    = {[8'h40:8'hBF]};
        								      bins high   = {[8'hc0:8'hFF]}; }
    endgroup

    function new(string name, uvm_component parent);
		super.new(name, parent);
		i2cS_cg = new();
	endfunction

	function void write(i2cS_seq_item t);
		tx = t;
		i2cS_cg.sample();
	endfunction
	virtual function void report_phase(uvm_phase phase);
        `uvm_info(get_type_name(), "  ===== Coverage Summary =====  ", UVM_LOW);
        `uvm_info(get_type_name(), $sformatf(" input_data : %.1f%%", i2cS_cg.cp_input_data.get_coverage()), UVM_LOW);
        `uvm_info(get_type_name(), "  ===== Coverage Summary =====  \n\n", UVM_LOW);
    endfunction
endclass


class i2cS_environment extends uvm_env;
	`uvm_component_utils(i2cS_environment)

	i2cS_agent agt;
	i2cS_scoreboard scb;
	i2cS_coverage cov;

	function new(string name, uvm_component parent);
		super.new(name, parent);
	endfunction

	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		agt = i2cS_agent::type_id::create("agt", this);
		scb = i2cS_scoreboard::type_id::create("scb", this);
		cov = i2cS_coverage::type_id::create("cov", this);
	endfunction
	virtual function void connect_phase(uvm_phase phase);
		super.connect_phase(phase);
		agt.drv.ap.connect(scb.exp_fifo.analysis_export);
		agt.mon.ap.connect(scb.act_fifo.analysis_export);
        agt.mon.ap.connect(cov.analysis_export);
	endfunction
endclass


class i2cS_test extends uvm_test;
    `uvm_component_utils(i2cS_test)

    i2cS_environment env;

	function new(string name, uvm_component parent);
		super.new(name, parent);
	endfunction

	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		env = i2cS_environment::type_id::create("env", this);
	endfunction
	virtual task run_phase(uvm_phase phase);
		i2cS_rand_seq seq;

		phase.raise_objection(this);
			seq = i2cS_rand_seq::type_id::create("seq");
			seq.num_loop = 40;
			seq.start(env.agt.sqr);
		phase.drop_objection(this);
	endtask
endclass


/***** dut *****/
module tb_i2c_slave_uvm();
    logic clk;
    logic reset;

    initial begin
        clk = 0;
        reset = 1;
        #50 reset = 0;
    end

    always #5 clk = ~clk;

    i2cS_if iif(clk, reset);
    i2c_slave dut (
        .clk(iif.clk), .reset(iif.reset),
        .scl(iif.scl), .sda(iif.sda),
        .i_data(iif.i_data), .i_done(iif.i_done)
    );

    initial begin
        uvm_config_db#(virtual i2cS_if)::set(null, "*", "iif", iif);
        run_test("i2cS_test");
    end

    initial begin
        $fsdbDumpfile("novas.fsdb");
        $fsdbDumpvars(0, tb_i2c_slave_uvm, "+all");
    end
endmodule