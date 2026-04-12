`ifndef MONITOR_SV
`define MONITOR_SV

class uart_monitor extends uvm_monitor;
    `uvm_component_utils(uart_monitor)

    uvm_analysis_port #(uart_seq_item) ap;
    virtual uart_if uif;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        ap = new("ap", this);
        if(!uvm_config_db#(virtual uart_if)::get(this, "", "uif", uif))
            `uvm_fatal(get_type_name(), "monitor에서 uvm_config_db 에러 발생.");
    endfunction
    virtual task run_phase(uvm_phase phase);
        `uvm_info(get_type_name(), "Start UART monitoring...", UVM_MEDIUM)

        forever begin
            collect_transaction();
        end
    endtask

    task collect_transaction();
        uart_seq_item tx;
        int baud_period;

        wait(uif.mon_cb.uart_rx == 0);

        tx = uart_seq_item::type_id::create("mon_tx");
        baud_period = 1_000_000_000 / tx.baudrate;

        #(baud_period / 2);

        for (int i = 0; i < 8; i++) begin
            #(baud_period);
            tx.data[i] = uif.mon_cb.uart_rx;
        end

        #(baud_period);
        if(uif.mon_cb.uart_rx == 1) begin
            ap.write(tx);
        end
    endtask
endclass

`endif 