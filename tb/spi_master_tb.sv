`timescale 1ns/1ps

module spi_master_tb;
    dut_spi_top_if intf();

    assign intf.spi_miso = intf.spi_mosi; // Loopback: RX should equal TX.

    integer rising_edges = 0;

    initial intf.clk = 1'b0;
    always #5 intf.clk = ~intf.clk;

    dut_spi_top dut (
        .clk(intf.clk), .rst_n(intf.rst_n),
        .psel(intf.psel), .penable(intf.penable), .pwrite(intf.pwrite),
        .paddr(intf.paddr), .pwdata(intf.pwdata), .prdata(intf.prdata),
        .pready(intf.pready), .pslverr(intf.pslverr),
        .spi_sclk(intf.spi_sclk), .spi_cs_n(intf.spi_cs_n),
        .spi_mosi(intf.spi_mosi), .spi_miso(intf.spi_miso)
    );

    always @(posedge intf.spi_sclk) begin
        if (!intf.spi_cs_n)
            rising_edges = rising_edges + 1;
    end

    task automatic apb_write(input logic [7:0] addr, input logic [31:0] data);
        begin
            @(negedge intf.clk);
            intf.psel = 1'b1;
            intf.penable = 1'b0;
            intf.pwrite = 1'b1;
            intf.paddr = addr;
            intf.pwdata = data;
            @(negedge intf.clk);
            intf.penable = 1'b1;
            @(negedge intf.clk);
            intf.psel = 1'b0;
            intf.penable = 1'b0;
            intf.pwrite = 1'b0;
        end
    endtask

    task automatic apb_read(input logic [7:0] addr, output logic [31:0] data);
        begin
            @(negedge intf.clk);
            intf.psel = 1'b1;
            intf.penable = 1'b0;
            intf.pwrite = 1'b0;
            intf.paddr = addr;
            @(negedge intf.clk);
            intf.penable = 1'b1;
            #1 data = intf.prdata;
            @(negedge intf.clk);
            intf.psel = 1'b0;
            intf.penable = 1'b0;
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

            $display("[%0t] INFO: Waiting for SPI transfer to complete", $time);
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
            if (intf.spi_cs_n !== 1'b1 || intf.spi_sclk !== 1'b0)
                $fatal(1, "SPI bus did not return to idle after transfer");
            $display("[%0t] INFO: Transfer complete, TX=0x%02h RX=0x%02h, SCLK rising edges=%0d",
                     $time, value, read_value[7:0], rising_edges);
        end
    endtask

    logic [31:0] value;
    initial begin
        intf.rst_n = 1'b0;
        intf.psel = 1'b0;
        intf.penable = 1'b0;
        intf.pwrite = 1'b0;
        intf.paddr = 8'h00;
        intf.pwdata = 32'h0;
        $display("[%0t] INFO: SPI master testbench started; holding reset", $time);
        repeat (4) @(negedge intf.clk);
        intf.rst_n = 1'b1;
        $display("[%0t] INFO: Reset released", $time);
        repeat (2) @(negedge intf.clk);

        if (intf.pready !== 1'b1 || intf.pslverr !== 1'b0)
            $fatal(1, "Unexpected APB ready/error response");

        apb_write(8'h10, 32'd2);
        apb_read(8'h10, value);
        if (value[15:0] !== 16'd2)
            $fatal(1, "DIVIDER readback failed");
        $display("[%0t] INFO: SPI divider configured and read back as %0d", $time, value[15:0]);

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
