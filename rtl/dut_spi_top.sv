// APB-programmable SPI controller supporting master and slave roles.
//
// Byte register map:
//   0x00 CTRL       [0] START (write 1; accepted only in master mode)
//   0x04 STATUS     [0] BUSY, [1] DONE (sticky until next transfer)
//   0x08 TXDATA     [7:0] transmit data, MSB first
//   0x0c RXDATA     [7:0] last received byte
//   0x10 DIVIDER    [15:0] system-clock cycles per SCLK half-period (master)
//   0x14 CONFIG     [0] MASTER_MODE (1=master, 0=slave; writable while idle)
//   0x18 IRQ_ENABLE [0] transfer-complete interrupt enable
//   0x1c IRQ_STATUS[0] transfer-complete pending, write 1 to clear
//
// The master generates SPI mode 0. In slave mode, SCLK/CS/MOSI are sampled
// in the APB clock domain; slave SCLK must be sufficiently slower than clk
// (at least four clk cycles per SCLK half-period). Each SPI signal is one
// resolved pad: CONFIG.MASTER_MODE controls which side drives each pad.
module dut_spi_top (
    input  logic        clk,
    input  logic        rst_n,

    // APB3 slave interface
    input  logic        psel,
    input  logic        penable,
    input  logic        pwrite,
    input  logic [7:0]  paddr,
    input  logic [31:0] pwdata,
    output logic [31:0] prdata,
    output logic        pready,
    output logic        pslverr,

    // One physical SPI bus shared by master and slave roles.
    inout  wire         spi_sclk,
    inout  wire         spi_cs_n,
    inout  wire         spi_mosi,
    inout  wire         spi_miso,

    output logic        irq
);

    localparam logic [7:0] ADDR_CTRL       = 8'h00;
    localparam logic [7:0] ADDR_STATUS     = 8'h04;
    localparam logic [7:0] ADDR_TXDATA     = 8'h08;
    localparam logic [7:0] ADDR_RXDATA     = 8'h0c;
    localparam logic [7:0] ADDR_DIVIDER    = 8'h10;
    localparam logic [7:0] ADDR_CONFIG     = 8'h14;
    localparam logic [7:0] ADDR_IRQ_ENABLE = 8'h18;
    localparam logic [7:0] ADDR_IRQ_STATUS = 8'h1c;

    typedef enum logic [1:0] {IDLE, MASTER_TRANSFER, SLAVE_TRANSFER, SLAVE_WAIT} state_t;
    state_t state;

    logic [7:0]  tx_data;
    logic [7:0]  rx_data;
    logic [7:0]  master_tx_shift;
    logic [7:0]  master_rx_shift;
    logic [7:0]  slave_tx_shift;
    logic [7:0]  slave_rx_shift;
    logic [15:0] divider;
    logic [15:0] divider_count;
    logic [2:0]  bit_count;
    logic        master_mode;
    logic        irq_enable;
    logic        irq_pending;
    logic        busy;
    logic        done;

    logic spi_sclk_o, spi_cs_n_o, spi_mosi_o, spi_miso_o;
    wire  spi_sclk_i = spi_sclk;
    wire  spi_cs_n_i = spi_cs_n;
    wire  spi_mosi_i = spi_mosi;
    wire  spi_miso_i = spi_miso;

    // Synchronizers for the externally clocked slave interface.
    logic spi_sclk_meta, spi_sclk_sync, spi_sclk_prev;
    logic spi_cs_n_meta, spi_cs_n_sync;
    logic spi_mosi_meta, spi_mosi_sync;
    wire slave_sclk_rise = spi_sclk_sync && !spi_sclk_prev;
    wire slave_sclk_fall = !spi_sclk_sync && spi_sclk_prev;

    wire apb_write = psel && penable && pwrite;
    wire start_write = apb_write && (paddr == ADDR_CTRL) && pwdata[0];
    wire irq_clear = apb_write && (paddr == ADDR_IRQ_STATUS) && pwdata[0];

    assign pready     = 1'b1;
    assign pslverr    = 1'b0;
    assign irq        = irq_enable && irq_pending;
    assign spi_mosi_o = master_tx_shift[7];
    assign spi_miso_o = slave_tx_shift[7];

    // Master drives SCLK/CS/MOSI and samples MISO. Slave does the reverse
    // for SCLK/CS/MOSI and drives MISO. High impedance leaves input pads
    // available to the external peer in each role.
    assign spi_sclk = master_mode ? spi_sclk_o : 1'bz;
    assign spi_cs_n = master_mode ? spi_cs_n_o : 1'bz;
    assign spi_mosi = master_mode ? spi_mosi_o : 1'bz;
    assign spi_miso = master_mode ? 1'bz : spi_miso_o;

    always_comb begin
        prdata = 32'h0000_0000;
        if (psel) begin
            case (paddr)
                ADDR_STATUS:     prdata = {29'b0, irq_pending, done, busy};
                ADDR_TXDATA:     prdata = {24'b0, tx_data};
                ADDR_RXDATA:     prdata = {24'b0, rx_data};
                ADDR_DIVIDER:    prdata = {16'b0, divider};
                ADDR_CONFIG:     prdata = {31'b0, master_mode};
                ADDR_IRQ_ENABLE: prdata = {31'b0, irq_enable};
                ADDR_IRQ_STATUS: prdata = {31'b0, irq_pending};
                default:         prdata = 32'h0000_0000;
            endcase
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            spi_sclk_meta <= 1'b0;
            spi_sclk_sync <= 1'b0;
            spi_sclk_prev <= 1'b0;
            spi_cs_n_meta <= 1'b1;
            spi_cs_n_sync <= 1'b1;
            spi_mosi_meta <= 1'b0;
            spi_mosi_sync <= 1'b0;
        end else begin
            spi_sclk_meta <= spi_sclk_i;
            spi_sclk_sync <= spi_sclk_meta;
            spi_sclk_prev <= spi_sclk_sync;
            spi_cs_n_meta <= spi_cs_n_i;
            spi_cs_n_sync <= spi_cs_n_meta;
            spi_mosi_meta <= spi_mosi_i;
            spi_mosi_sync <= spi_mosi_meta;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state          <= IDLE;
            tx_data        <= 8'h00;
            rx_data        <= 8'h00;
            master_tx_shift <= 8'h00;
            master_rx_shift <= 8'h00;
            slave_tx_shift <= 8'h00;
            slave_rx_shift <= 8'h00;
            divider        <= 16'd1;
            divider_count  <= 16'd0;
            bit_count      <= 3'd0;
            master_mode    <= 1'b1;
            irq_enable     <= 1'b0;
            irq_pending    <= 1'b0;
            busy           <= 1'b0;
            done           <= 1'b0;
            spi_sclk_o     <= 1'b0;
            spi_cs_n_o     <= 1'b1;
        end else begin
            // APB programmable registers. Role changes are accepted only
            // when the engine is fully idle, avoiding a mid-frame direction swap.
            if (apb_write) begin
                case (paddr)
                    ADDR_TXDATA:     tx_data <= pwdata[7:0];
                    ADDR_DIVIDER:    divider <= pwdata[15:0];
                    ADDR_CONFIG: if (state == IDLE && !busy && spi_cs_n_sync)
                                         master_mode <= pwdata[0];
                    ADDR_IRQ_ENABLE: irq_enable <= pwdata[0];
                    default: ;
                endcase
            end

            if (irq_clear)
                irq_pending <= 1'b0;

            case (state)
                IDLE: begin
                    spi_sclk_o    <= 1'b0;
                    spi_cs_n_o    <= 1'b1;
                    divider_count <= 16'd0;
                    if (master_mode && start_write && !busy) begin
                        state           <= MASTER_TRANSFER;
                        master_tx_shift <= tx_data;
                        master_rx_shift <= 8'h00;
                        bit_count       <= 3'd0;
                        busy            <= 1'b1;
                        done            <= 1'b0;
                        spi_cs_n_o      <= 1'b0;
                    end else if (!master_mode && !spi_cs_n_sync) begin
                        state         <= SLAVE_TRANSFER;
                        slave_tx_shift <= tx_data;
                        slave_rx_shift <= 8'h00;
                        bit_count     <= 3'd0;
                        busy          <= 1'b1;
                        done          <= 1'b0;
                    end
                end

                MASTER_TRANSFER: begin
                    if (divider_count >= ((divider == 16'd0) ? 16'd0 : divider - 16'd1)) begin
                        divider_count <= 16'd0;
                        if (!spi_sclk_o) begin
                            // Mode 0 samples MISO on rising SCLK edges.
                            spi_sclk_o     <= 1'b1;
                            master_rx_shift <= {master_rx_shift[6:0], spi_miso_i};
                        end else begin
                            spi_sclk_o <= 1'b0;
                            if (bit_count == 3'd7) begin
                                state      <= IDLE;
                                busy       <= 1'b0;
                                done       <= 1'b1;
                                rx_data    <= master_rx_shift;
                                spi_cs_n_o <= 1'b1;
                                irq_pending <= 1'b1;
                            end else begin
                                bit_count       <= bit_count + 3'd1;
                                master_tx_shift <= {master_tx_shift[6:0], 1'b0};
                            end
                        end
                    end else begin
                        divider_count <= divider_count + 16'd1;
                    end
                end

                SLAVE_TRANSFER: begin
                    if (spi_cs_n_sync) begin
                        // A short frame is aborted; do not report completion.
                        state <= IDLE;
                        busy  <= 1'b0;
                    end else if (slave_sclk_rise) begin
                        slave_rx_shift <= {slave_rx_shift[6:0], spi_mosi_sync};
                        if (bit_count == 3'd7) begin
                            rx_data     <= {slave_rx_shift[6:0], spi_mosi_sync};
                            state       <= SLAVE_WAIT;
                            busy        <= 1'b0;
                            done        <= 1'b1;
                            irq_pending <= 1'b1;
                        end else begin
                            bit_count <= bit_count + 3'd1;
                        end
                    end else if (slave_sclk_fall) begin
                        slave_tx_shift <= {slave_tx_shift[6:0], 1'b0};
                    end
                end

                SLAVE_WAIT: begin
                    if (spi_cs_n_sync)
                        state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                    busy  <= 1'b0;
                end
            endcase
        end
    end

endmodule
