`timescale 1ns/1ps

module spi_master_tb;
    localparam logic [7:0] REG_CTRL       = 8'h00;
    localparam logic [7:0] REG_STATUS     = 8'h04;
    localparam logic [7:0] REG_TXDATA     = 8'h08;
    localparam logic [7:0] REG_RXDATA     = 8'h0c;
    localparam logic [7:0] REG_DIVIDER    = 8'h10;
    localparam logic [7:0] REG_CONFIG     = 8'h14;
    localparam logic [7:0] REG_IRQ_ENABLE = 8'h18;
    localparam logic [7:0] REG_IRQ_STATUS = 8'h1c;

    apb_if apb();
    spi_if spi();
    irq_if intr();

    integer rising_edges = 0;
    logic [7:0] slave_rx;
    logic [31:0] value;
    // Clock generation = 100 MHz APB clock, 10 ns period.
    initial apb.clk = 1'b0;
    always #5 apb.clk = ~apb.clk;

    // Loopback slave for master-mode tests. Update MISO away from the DUT's
    // active clock edge to avoid a testbench/DUT scheduling race.
    always @(negedge apb.clk)
        spi.ext_miso = spi.spi_mosi;

    dut_spi_top dut (
        .clk(apb.clk), .rst_n(apb.rst_n),
        .psel(apb.psel), .penable(apb.penable), .pwrite(apb.pwrite),
        .paddr(apb.paddr), .pwdata(apb.pwdata), .prdata(apb.prdata),
        .pready(apb.pready), .pslverr(apb.pslverr),
        .spi_sclk(spi.spi_sclk), .spi_cs_n(spi.spi_cs_n),
        .spi_mosi(spi.spi_mosi), .spi_miso(spi.spi_miso),
        .irq(intr.irq)
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

    task automatic wait_for_done;
        integer timeout;
        logic [31:0] status;
        begin
            timeout = 0;
            status = 0;
            $display("[%0t] TB: Waiting for transfer completion", $time);
            while ((status[1:0] !== 2'b10) && timeout < 2000) begin
                apb_read(REG_STATUS, status);
                timeout = timeout + 1;
            end
            if (timeout >= 2000)
                $fatal(1, "Timed out waiting for SPI transfer completion");
            $display("[%0t] TB: Transfer complete after %0d status polls", $time, timeout);
        end
    endtask

    task automatic master_transfer_and_check(input logic [7:0] tx);
        begin
            $display("[%0t] TB: Master mode: writing TXDATA=0x%02h and starting transfer", $time, tx);
            // Write the TXDATA register and start the transfer.
            apb_write(REG_TXDATA, {24'h0, tx});
            rising_edges = 0;
            // Start the transfer by writing 1 to the CTRL register.
            apb_write(REG_CTRL, 32'h1);
            // Wait for the transfer to complete and check the results.
            wait_for_done();
            // Read the RXDATA register and check that it matches the sent value.
            apb_read(REG_RXDATA, value);
            if (value[7:0] !== tx)
                $fatal(1, "Master RX mismatch: sent %02h, got %02h", tx, value[7:0]);
            if (rising_edges != 8)
                $fatal(1, "Expected 8 master SCLK rising edges, got %0d", rising_edges);
            if (spi.spi_cs_n !== 1'b1 || spi.spi_sclk !== 1'b0)
                $fatal(1, "Master SPI bus did not return to idle");
            $display("[%0t] TB: Master transfer passed: TX=0x%02h RX=0x%02h, rising edges=%0d",
                     $time, tx, value[7:0], rising_edges);
        end
    endtask

    task automatic slave_transfer(input logic [7:0] master_tx,
                                  input logic [7:0] dut_tx);
        integer bit_index;
        begin
            $display("[%0t] TB: Configuring SPI slave mode; DUT TXDATA=0x%02h", $time, dut_tx);
            apb_write(REG_TXDATA, {24'h0, dut_tx});
            apb_write(REG_CONFIG, 32'h0); // Select slave role.
            apb_read(REG_CONFIG, value);
            if (value[0] !== 1'b0)
                $fatal(1, "Failed to configure SPI slave mode");
            // Allow the synchronized chip-select to reach the slave engine.
            spi.ext_slave_enable = 1'b0;
            spi.ext_master_enable = 1'b1;
            @(negedge apb.clk);
            spi.ext_cs_n = 1'b0;
            $display("[%0t] TB: External master asserted CS; sending 0x%02h", $time, master_tx);
            repeat (6) @(posedge apb.clk);

            slave_rx = 8'h00;
            for (bit_index = 7; bit_index >= 0; bit_index = bit_index - 1) begin
                spi.ext_mosi = master_tx[bit_index];
                #80;
                if (spi.spi_miso !== dut_tx[bit_index])
                    $fatal(1, "Slave MISO bit %0d mismatch: expected %b got %b",
                           bit_index, dut_tx[bit_index], spi.spi_miso);
                slave_rx[bit_index] = spi.spi_miso;
                spi.ext_sclk = 1'b1;
                #80;
                spi.ext_sclk = 1'b0;
                #80;
            end

            if (slave_rx !== dut_tx)
                $fatal(1, "Slave TX mismatch: expected %02h, observed %02h",
                       dut_tx, slave_rx);

            spi.ext_cs_n = 1'b1;
            repeat (6) @(posedge apb.clk);
            spi.ext_master_enable = 1'b0;
            apb_read(REG_RXDATA, value);
            if (value[7:0] !== master_tx)
                $fatal(1, "Slave RX mismatch: external master sent %02h, got %02h",
                       master_tx, value[7:0]);
            $display("[%0t] TB: Slave transfer passed: external TX=0x%02h, DUT RX=0x%02h, DUT TX=0x%02h",
                     $time, master_tx, value[7:0], slave_rx);
        end
    endtask

    initial begin
        $display("[%0t] TB: Starting SPI APB testbench", $time);
        $display("[%0t] TB: Applying active-low reset", $time);
        apb.rst_n = 1'b0;
        apb.psel = 1'b0;
        apb.penable = 1'b0;
        apb.pwrite = 1'b0;
        apb.paddr = 8'h00;
        apb.pwdata = 32'h0;
        spi.ext_master_enable = 1'b0;
        spi.ext_sclk = 1'b0;
        spi.ext_cs_n = 1'b1;
        spi.ext_mosi = 1'b0;
        spi.ext_slave_enable = 1'b1;
        spi.ext_miso = 1'b0;

        repeat (4) @(negedge apb.clk);
        apb.rst_n = 1'b1;
        $display("[%0t] TB: Reset released", $time);
        repeat (2) @(negedge apb.clk);

        if (apb.pready !== 1'b1 || apb.pslverr !== 1'b0)
            $fatal(1, "Unexpected APB ready/error response");
        // Configure the SPI master for a 2-cycle divider 2 apb clock = 1 cycle SPI clock.
        apb_write(REG_DIVIDER, 32'd2);
        // Enable the transfer-complete interrupt.
        apb_write(REG_IRQ_ENABLE, 32'd1);
        $display("[%0t] TB: APB setup complete: divider=2, transfer-complete IRQ enabled", $time);
        // Perform a master-mode transfer and check the result.
        master_transfer_and_check(8'hA5);
        if (intr.irq !== 1'b1)
            $fatal(1, "Master transfer did not assert IRQ");
        $display("[%0t] TB: Master completion IRQ asserted", $time);
        // Clear the IRQ by writing 1 to the IRQ_STATUS register (W1C).
        apb_write(REG_IRQ_STATUS, 32'd1);
        if (intr.irq !== 1'b0)
            $fatal(1, "IRQ did not clear after W1C write");
        $display("[%0t] TB: IRQ cleared by W1C write", $time);
        // Perform a slave-mode transfer and check the result.
        slave_transfer(8'h5A, 8'h96);
        if (intr.irq !== 1'b1)
            $fatal(1, "Slave transfer did not assert IRQ");
        $display("[%0t] TB: Slave completion IRQ asserted", $time);
        
        apb_read(REG_STATUS, value);
        if (value[1:0] !== 2'b10)
            $fatal(1, "Slave STATUS expected DONE=1 and BUSY=0");
        //Clear the IRQ by writing 1 to the IRQ_STATUS register (W1C).
        apb_write(REG_IRQ_STATUS, 32'd1);
        if (intr.irq !== 1'b0)
            $fatal(1, "IRQ did not clear after W1C write");
        $display("[%0t] PASS: APB, master/slave SPI transfers, and completion IRQ/W1C", $time);
        $finish;
    end

    initial begin
        #100000;
        $fatal(1, "Global testbench timeout");
    end
endmodule
