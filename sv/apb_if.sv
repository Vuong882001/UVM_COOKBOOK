// APB3 interface shared by the DUT and APB UVM agent.
interface apb_if;
    logic        clk;
    logic        rst_n;
    logic        psel;
    logic        penable;
    logic        pwrite;
    logic [7:0]  paddr;
    logic [31:0] pwdata;
    logic [31:0] prdata;
    logic        pready;
    logic        pslverr;

    // APB driver BFM: drive bus controls on the falling edge and sample
    // response signals after the DUT's active edge.
    clocking driver_cb @(negedge clk);
        default input #1step output #1step;
        input  rst_n;
        output psel, penable, pwrite, paddr, pwdata;
        input  prdata, pready, pslverr;
    endclocking

    clocking monitor_cb @(posedge clk);
        default input #1step;
        input rst_n, psel, penable, pwrite, paddr, pwdata;
        input prdata, pready, pslverr;
    endclocking

    modport dut (
        input  clk, rst_n, psel, penable, pwrite, paddr, pwdata,
        output prdata, pready, pslverr
    );

    modport master (clocking driver_cb);
    modport monitor (clocking monitor_cb);
endinterface
