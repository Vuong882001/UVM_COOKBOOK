// Single resolved SPI bus used in both controller roles. External BFMs drive
// the shared pads through explicit enables so the bus can resolve to Z.
interface spi_if;
    tri spi_sclk;
    tri spi_cs_n;
    tri spi_mosi;
    tri spi_miso;

    logic ext_master_enable;
    logic ext_sclk;
    logic ext_cs_n;
    logic ext_mosi;

    logic ext_slave_enable;
    logic ext_miso;

    assign spi_sclk = ext_master_enable ? ext_sclk : 1'bz;
    assign spi_cs_n = ext_master_enable ? ext_cs_n : 1'bz;
    assign spi_mosi = ext_master_enable ? ext_mosi : 1'bz;
    assign spi_miso = ext_slave_enable ? ext_miso : 1'bz;

    // External slave BFM for a DUT acting as master; MISO changes on SCLK fall.
    clocking slave_bfm_cb @(negedge spi_sclk);
        default input #1step output #1step;
        input  spi_cs_n, spi_mosi;
        output ext_miso;
    endclocking

    modport dut (
        inout spi_sclk, spi_cs_n, spi_mosi, spi_miso
    );

    // External master BFM drives these sources when the DUT is in slave mode.
    modport external_master (
        output ext_master_enable, ext_sclk, ext_cs_n, ext_mosi,
        input spi_miso
    );

    modport external_slave (
        input spi_sclk, spi_cs_n, spi_mosi,
        output ext_slave_enable, ext_miso,
        clocking slave_bfm_cb
    );

    modport monitor (
        input spi_sclk, spi_cs_n, spi_mosi, spi_miso
    );
endinterface
