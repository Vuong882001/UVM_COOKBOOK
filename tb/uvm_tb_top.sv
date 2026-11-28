// Placeholder top for a future UVM testbench.
`timescale 1ns/1ps
module tb_top;
import uvm_pkg::*;
import tb_top_pkg::*;

apb_if apb();
spi_if spi();
irq_if intr();

//Initial block to generate reset and clock signals.
initial begin
    apb.rst_n = 1'b0;
    apb.clk = 1'b0;
    #100;
    apb.rst_n = 1'b1;
end

//Clock generation: 100 MHz APB clock, 10 ns period.
always #5 apb.clk = ~apb.clk;

// Keep both sides of the resolved SPI bus released until agents take over.
initial begin
    spi.ext_master_enable = 1'b0;
    spi.ext_sclk = 1'b0;
    spi.ext_cs_n = 1'b1;
    spi.ext_mosi = 1'b0;
    spi.ext_slave_enable = 1'b0;
    spi.ext_miso = 1'b0;
end

//DUT instance.
dut_spi_top dut (
    .clk(apb.clk), .rst_n(apb.rst_n),
    .psel(apb.psel), .penable(apb.penable), .pwrite(apb.pwrite),
    .paddr(apb.paddr), .pwdata(apb.pwdata), .prdata(apb.prdata),
    .pready(apb.pready), .pslverr(apb.pslverr),
    .spi_sclk(spi.spi_sclk), .spi_cs_n(spi.spi_cs_n),
    .spi_mosi(spi.spi_mosi), .spi_miso(spi.spi_miso),
    .irq(intr.irq)
);

//Virtual interface assignments for UVM components & run_test.
initial begin
    uvm_config_db#(virtual apb_if)::set(null, "uvm_test_top", "apb_vif", apb);
    uvm_config_db#(virtual spi_if)::set(null, "uvm_test_top", "spi_vif", spi);
    uvm_config_db#(virtual irq_if)::set(null, "uvm_test_top", "irq_vif", intr);
    // Let +UVM_TESTNAME from the simulator command select the test class.
    run_test();
end

endmodule
