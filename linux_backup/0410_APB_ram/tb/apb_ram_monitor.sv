`ifndef MONITOR_SV
`define MONITOR_SV

`include "apb_ram_seq_item.sv"

class apb_monitor extends uvm_monitor;
    `uvm_component_utils(apb_monitor)

    uvm_analysis_port #(apb_seq_item) ap;
    virtual apb_if vif;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        ap = new("ap", this);
        if(!uvm_config_db#(virtual apb_if)::get(this, "", "vif", vif))
            `uvm_fatal(get_type_name(), "monitor에서 uvm_config_db 에러 발생.");
    endfunction
    virtual task run_phase(uvm_phase phase);
        `uvm_info(get_type_name(), "APB 버스 모니터링 시작...", UVM_MEDIUM)

        forever begin
            collect_transaction();
        end
    endtask

    task collect_transaction();
        apb_seq_item tx;

        @(vif.mon_cb);

        if(vif.mon_cb.psel && vif.mon_cb.penable && vif.mon_cb.pready) begin
            tx         = apb_seq_item::type_id::create("mon_tx");
            tx.paddr   = vif.mon_cb.paddr;
            tx.pwrite  = vif.mon_cb.pwrite;
            tx.pwdata  = vif.mon_cb.pwdata;
            tx.prdata  = vif.mon_cb.prdata;
            tx.pready  = vif.mon_cb.pready;
            tx.penable = vif.mon_cb.penable;
            tx.psel    = vif.mon_cb.psel;
            `uvm_info(get_type_name(), $sformatf("mon tx: %s", tx.convert2string()), UVM_MEDIUM)
            ap.write(tx);
        end
    endtask
endclass

`endif 