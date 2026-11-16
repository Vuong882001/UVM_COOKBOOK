`timescale 1ns/1ps

module spi_master_tb;
    apb_if apb();
    spi_if spi();

    // Direct-testbench loopback slave: the DUT receives its transmitted bit.
    assign spi.spi_miso = spi.spi_mosi;

    integer rising_edges = 0;

    initial apb.clk = 1'b0;
    always #5 apb.clk = ~apb.clk;

    dut_spi_top dut (
        .clk(apb.clk), .rst_n(apb.rst_n),
        .psel(apb.psel), .penable(apb.penable), .pwrite(apb.pwrite),
        .paddr(apb.paddr), .pwdata(apb.pwdata), .prdata(apb.prdata),
        .pready(apb.pready), .pslverr(apb.pslverr),
        .spi_sclk(spi.spi_sclk), .spi_cs_n(spi.spi_cs_n),
        .spi_mosi(spi.spi_mosi), .spi_miso(spi.spi_miso)
    );

    always @(posedge spi.spi_sclk) begin
        if (!spi.spi_cs_n)
            rising_edges = rising_edges + 1;
    end

    task automatic apb_write(input logic [7:0] addr, input logic [31:0] data);
        begin
            @(negedge apb.clk);
            apb.psel = 1'b1;
            apb.penable = 1'b0;
            apb.pwrite = 1'b1;
            apb.paddr = addr;
            apb.pwdata = data;
            @(negedge apb.clk);
            apb.penable = 1'b1;
            @(negedge apb.clk);
            apb.psel = 1'b0;
            apb.penable = 1'b0;
            apb.pwrite = 1'b0;
        end
    endtask

    task automatic apb_read(input logic [7:0] addr, output logic [31:0] data);
        begin
            @(negedge apb.clk);
            apb.psel = 1'b1;
            apb.penable = 1'b0;
            apb.pwrite = 1'b0;
            apb.paddr = addr;
            @(negedge apb.clk);
            apb.penable = 1'b1;
            #1 data = apb.prdata;
            @(negedge apb.clk);
            apb.psel = 1'b0;
            apb.penable = 1'b0;
        end
    endtask

    task automatic transfer_and_check(input logic [7:0] value);
        logic [31:0] read_value;
        integer timeout;
        begin
            $display("[%0t] INFO: Starting SPI loopback transfer, TX=0x%02h", $time, value);
            apb_write(8'h08, {24'h0, value});
            rising_edges = 0;
            apb_write(8'h00, 32'h1);

            timeout = 0;
            read_value = 32'h0;
            while ((read_value[0] !== 1'b0 || read_value[1] !== 1'b1) && timeout < 2000) begin
                apb_read(8'h04, read_value);
                timeout = timeout + 1;
            end
            if (timeout >= 2000)
                $fatal(1, "Timed out waiting for SPI transfer completion");

            apb_read(8'h0c, read_value);
            if (read_value[7:0] !== value)
                $fatal(1, "RX mismatch: sent %02h, received %02h", value, read_value[7:0]);
            if (rising_edges != 8)
                $fatal(1, "Expected 8 SPI rising edges, observed %0d", rising_edges);
            if (spi.spi_cs_n !== 1'b1 || spi.spi_sclk !== 1'b0)
                $fatal(1, "SPI bus did not return to idle after transfer");
            $display("[%0t] INFO: Transfer complete, TX=0x%02h RX=0x%02h, SCLK rising edges=%0d",
                     $time, value, read_value[7:0], rising_edges);
        end
    endtask

    logic [31:0] value;
    initial begin
        apb.rst_n = 1'b0;
        apb.psel = 1'b0;
        apb.penable = 1'b0;
        apb.pwrite = 1'b0;
        apb.paddr = 8'h00;
        apb.pwdata = 32'h0;
        $display("[%0t] INFO: SPI master testbench started; holding reset", $time);
        repeat (4) @(negedge apb.clk);
        apb.rst_n = 1'b1;
        $display("[%0t] INFO: Reset released", $time);
        repeat (2) @(negedge apb.clk);

        if (apb.pready !== 1'b1 || apb.pslverr !== 1'b0)
            $fatal(1, "Unexpected APB ready/error response");

        apb_write(8'h10, 32'd2);
        apb_read(8'h10, value);
        if (value[15:0] !== 16'd2)
            $fatal(1, "DIVIDER readback failed");

        transfer_and_check(8'hA5);
        transfer_and_check(8'h3C);

        apb_read(8'h04, value);
        if (value[1:0] !== 2'b10)
            $fatal(1, "STATUS expected DONE=1 and BUSY=0, got %b", value[1:0]);

        $display("PASS: APB register access and two SPI mode-0 loopback transfers");
        $finish;
    end

    initial begin
        #100000;
        $fatal(1, "Global testbench timeout");
    end
endmodule
