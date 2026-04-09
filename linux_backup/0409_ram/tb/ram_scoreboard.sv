`ifndef RAM_SCOREBOARD_SV
`define RAM_SCOREBOARD_SV

`timescale 1ns/1ps
`include "uvm_macros.svh"
import uvm_pkg::*;
`include "ram_seq_item.sv"

class ram_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(ram_scoreboard)

    uvm_analysis_imp #(ram_seq_item, ram_scoreboard) ap_imp;

    logic [15:0] ref_mem[0:2**8-1];
    int pass_cnt = 0;
    int fail_cnt = 0;
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        ap_imp = new("ap_imp", this);

    endfunction
    virtual function void connect_phase(uvm_phase phase);

    endfunction
    virtual function void write(ram_seq_item item);
        logic [15:0] expected;
        if(item.wr) begin
            ref_mem[item.addr] = item.wdata;
            pass_cnt++;
            `uvm_info(get_type_name(), $sformatf("쓰기 기록: addr=0x%02h, data=0x%04h", item.addr, item.wdata), UVM_MEDIUM)
        end else begin
            expected = ref_mem[item.addr];
            if(item.rdata === expected) begin
                pass_cnt++;
                `uvm_info(get_type_name(), $sformatf("PASS: addr=0x%02h, expected=0x%04h, real=0x%04h", item.addr, expected, item.rdata), UVM_MEDIUM)
            end else begin
                fail_cnt++;
                `uvm_error(get_type_name(), $sformatf("FAIL: addr=0x%02h, expected=0x%04h, real=0x%04h", item.addr, expected, item.rdata));
            end 
        end
    endfunction
    virtual function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info(get_type_name(), " ===== Scoreboard Summay =====", UVM_LOW)
        `uvm_info(get_type_name(), $sformatf("   Total transactions: %0d", pass_cnt + fail_cnt), UVM_LOW)
        `uvm_info(get_type_name(), $sformatf("   Pass: %0d", pass_cnt), UVM_LOW)
        `uvm_info(get_type_name(), $sformatf("   Fail: %0d", fail_cnt), UVM_LOW)
        if(fail_cnt > 0) begin
            `uvm_error(get_type_name(), $sformatf("TEST FAILED: %0d mismatches detected.", fail_cnt))
        end else begin
            `uvm_info(get_type_name(), $sformatf("TEST PASSED; %0d all matches detected.", pass_cnt), UVM_LOW)
        end
    endfunction
endclass




`endif 