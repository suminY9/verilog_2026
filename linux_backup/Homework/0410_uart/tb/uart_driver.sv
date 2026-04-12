`ifndef DRIVER_SV
`define DRIVER_SV

class uart_driver extends uvm_driver#(uart_seq_item);
    `uvm_component_utils(uart_driver)
    uvm_analysis_port #(uart_seq_item) ap;
    virtual uart_if uif;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        ap = new("ap", this);
        if(!uvm_config_db#(virtual uart_if)::get(this, "", "uif", uif))
            `uvm_fatal(get_type_name(), "driver에서 uvm_config_db 에러 발생.");

    endfunction
    virtual task run_phase(uvm_phase phase);
        //initialize bus
        uart_init();
        wait(uif.rst == 0);
        @(uif.drv_cb);
        `uvm_info(get_type_name(), "finish reset. waiting for transaction...", UVM_MEDIUM)

        forever begin
            uart_seq_item tx;
            seq_item_port.get_next_item(tx);
            ap.write(tx);
            drive_uart(tx);
            seq_item_port.item_done();
        end
    endtask

    task uart_init();
        uif.drv_cb.uart_rx <= 1;
    endtask
    task drive_uart(uart_seq_item tx);
        int baud_period = 10416;

        // baud_period = 100_000_000 / tx.baudrate;

        `uvm_info("DEBUG", "Entering drive_uart", UVM_LOW)

        // start bit
        uif.drv_cb.uart_rx <= 0;
        repeat(baud_period) @(uif.drv_cb);
        `uvm_info("DEBUG", "Start bit finished", UVM_LOW)

        // data bit
        for(int i = 0; i < 8; i++) begin
            uif.drv_cb.uart_rx <= tx.data[i];
            repeat(baud_period) @(uif.drv_cb);
            `uvm_info("DEBUG", $sformatf("Bit [%0d] finished", i), UVM_LOW)
        end

        // stop bit
        uif.drv_cb.uart_rx <= 1;
        repeat(baud_period) @(uif.drv_cb);

        `uvm_info("DEBUG", "Finished drive_uart", UVM_LOW)
    endtask
endclass

`endif 