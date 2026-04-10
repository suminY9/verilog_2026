interface apb_if (input logic pclk, input logic presetn);
    logic [7:0]  paddr;
    logic        pwrite;
    logic        penable;
    logic [31:0] pwdata;
    logic        psel;
    logic [31:0] prdata;
    logic        pready;

    clocking drv_cb @(posedge pclk);
        default input #1step output #0;
        output paddr;
        output pwrite;
        output penable;
        output pwdata;
        output psel;
        input prdata;
        input pready;
    endclocking
    
    clocking mon_cb @(posedge pclk);
        default input #1step;
        input paddr;
        input pwrite;
        input penable;
        input pwdata;
        input psel;
        input prdata;
        input pready;
    endclocking

    modport mp_drv(clocking drv_cb, input pclk, input presetn);
    modport mp_mon(clocking mon_cb, input pclk, input presetn);

endinterface