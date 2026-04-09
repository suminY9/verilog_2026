`ifndef RAM_SEQ_ITEM_SV
`define RAM_SEQ_ITEM_SV

`timescale 1ns/1ps
`include "uvm_macros.svh"
import uvm_pkg::*;

class ram_seq_item extends uvm_sequence_item;
    rand logic wr;
    rand logic [7:0] addr;
    rand logic [15:0] wdata;
    logic [15:0] rdata;
    
    //constraint c_addr {addr inside {[8'h00 : 8'h0f]};}

    `uvm_object_utils_begin(ram_seq_item)
        `uvm_field_int(wr, UVM_ALL_ON)
        `uvm_field_int(addr, UVM_ALL_ON)
        `uvm_field_int(wdata, UVM_ALL_ON)
        `uvm_field_int(rdata, UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "ram_seq_time");
        super.new(name);
    endfunction

    function string convert2string();
        return $sformatf("wr=%0b addr=0x%02h wdata=0x%04h rdata=0x%04h", wr, addr, wdata, rdata);
    endfunction
endclass




`endif 