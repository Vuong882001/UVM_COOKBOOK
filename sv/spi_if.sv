// SPI pin interface for the DUT and SPI UVM agent (current DUT uses mode 0).
interface spi_if;
    logic spi_sclk;
    logic spi_cs_n;
    logic spi_mosi;
    logic spi_miso;

    // For the SPI slave BFM, MISO changes on falling edges and is sampled
    // by the DUT on rising edges in mode 0.
    clocking slave_driver_cb @(negedge spi_sclk);
        default input #1step output #1step;
        input  spi_cs_n, spi_mosi;
        output spi_miso;
    endclocking

    clocking monitor_cb @(posedge spi_sclk);
        default input #1step;
        input spi_cs_n, spi_mosi, spi_miso;
    endclocking

    modport dut (
        output spi_sclk, spi_cs_n, spi_mosi,
        input  spi_miso
    );

    modport slave (clocking slave_driver_cb);

    modport monitor (clocking monitor_cb);
endinterface
