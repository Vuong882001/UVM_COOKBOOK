// Shared APB and SPI signals for the SPI DUT and its testbench.
interface dut_spi_top_if;
    // APB clock and reset
    logic        clk;
    logic        rst_n;

    // APB3 slave interface
    logic        psel;
    logic        penable;
    logic        pwrite;
    logic [7:0]  paddr;
    logic [31:0] pwdata;
    logic [31:0] prdata;
    logic        pready;
    logic        pslverr;

    // SPI interface
    logic        spi_sclk;
    logic        spi_cs_n;
    logic        spi_mosi;
    logic        spi_miso;

    // Connect this modport to dut_spi_top.
    modport dut (
        input  clk, rst_n,
        input  psel, penable, pwrite, paddr, pwdata,
        output prdata, pready, pslverr,
        output spi_sclk, spi_cs_n, spi_mosi,
        input  spi_miso
    );

    // Drive APB and loopback input from a testbench; observe DUT outputs.
    modport tb (
        input  clk,
        output rst_n,
        output psel, penable, pwrite, paddr, pwdata,
        input  prdata, pready, pslverr,
        input  spi_sclk, spi_cs_n, spi_mosi,
        output spi_miso
    );

    // Race-free APB driver and monitor clocking blocks for testbench use.
    clocking driver_cb @(negedge clk);
        default input #1step output #1step;
        output rst_n;
        output psel, penable, pwrite, paddr, pwdata, spi_miso;
        input  prdata, pready, pslverr;
    endclocking

    clocking monitor_cb @(posedge clk);
        default input #1step;
        input rst_n;
        input psel, penable, pwrite, paddr, pwdata;
        input prdata, pready, pslverr;
        input spi_sclk, spi_cs_n, spi_mosi, spi_miso;
    endclocking
endinterface
