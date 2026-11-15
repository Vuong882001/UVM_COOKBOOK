// SPI master with a small APB3 register interface.
//
// Register map (byte addresses):
//   0x00 CTRL   [0] START (write 1 to launch one 8-bit transfer)
//   0x04 STATUS[0] BUSY, [1] DONE (cleared when a new transfer starts)
//   0x08 TXDATA [7:0] transmit byte, MSB first
//   0x0c RXDATA [7:0] most recently received byte
//   0x10 DIVIDER[15:0] number of clk cycles per SPI half-period; 0 means 1
//
// SPI operates in mode 0 (CPOL=0, CPHA=0), with chip select active low.
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

    // SPI interface
    output logic        spi_sclk,
    output logic        spi_cs_n,
    output logic        spi_mosi,
    input  logic        spi_miso
);

    localparam logic [7:0] ADDR_CTRL    = 8'h00;
    localparam logic [7:0] ADDR_STATUS  = 8'h04;
    localparam logic [7:0] ADDR_TXDATA  = 8'h08;
    localparam logic [7:0] ADDR_RXDATA  = 8'h0c;
    localparam logic [7:0] ADDR_DIVIDER = 8'h10;

    typedef enum logic {IDLE, TRANSFER} state_t;
    state_t state;

    logic [7:0]  tx_data;
    logic [7:0]  rx_data;
    logic [7:0]  tx_shift;
    logic [7:0]  rx_shift;
    logic [15:0] divider;
    logic [15:0] divider_count;
    logic [2:0]  bit_count;
    logic        busy;
    logic        done;

    wire apb_write = psel && penable && pwrite;
    wire start_write = apb_write && (paddr == ADDR_CTRL) && pwdata[0];

    assign pready  = 1'b1;
    assign pslverr = 1'b0;

    always_comb begin
        prdata = 32'h0000_0000;
        if (psel) begin
            case (paddr)
                ADDR_STATUS:  prdata = {30'b0, done, busy};
                ADDR_TXDATA:  prdata = {24'b0, tx_data};
                ADDR_RXDATA:  prdata = {24'b0, rx_data};
                ADDR_DIVIDER: prdata = {16'b0, divider};
                default:      prdata = 32'h0000_0000;
            endcase
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state         <= IDLE;
            tx_data       <= 8'h00;
            rx_data       <= 8'h00;
            tx_shift      <= 8'h00;
            rx_shift      <= 8'h00;
            divider       <= 16'd1;
            divider_count <= 16'd0;
            bit_count     <= 3'd0;
            busy          <= 1'b0;
            done          <= 1'b0;
            spi_sclk      <= 1'b0;
            spi_cs_n      <= 1'b1;
            spi_mosi      <= 1'b0;
        end else begin
            if (apb_write) begin
                case (paddr)
                    ADDR_TXDATA:  tx_data <= pwdata[7:0];
                    ADDR_DIVIDER: divider <= pwdata[15:0];
                    default: ;
                endcase
            end

            case (state)
                IDLE: begin
                    spi_sclk      <= 1'b0;
                    spi_cs_n      <= 1'b1;
                    divider_count <= 16'd0;
                    if (start_write && !busy) begin
                        state     <= TRANSFER;
                        tx_shift  <= tx_data;
                        rx_shift  <= 8'h00;
                        bit_count <= 3'd0;
                        busy      <= 1'b1;
                        done      <= 1'b0;
                        spi_cs_n  <= 1'b0;
                        spi_mosi  <= tx_data[7];
                    end
                end

                TRANSFER: begin
                    if (divider_count >= ((divider == 16'd0) ? 16'd0 : divider - 16'd1)) begin
                        divider_count <= 16'd0;
                        if (!spi_sclk) begin
                            // Mode 0 samples MISO on each rising edge.
                            spi_sclk <= 1'b1;
                            rx_shift <= {rx_shift[6:0], spi_miso};
                        end else begin
                            // Advance MOSI on falling edges so it is stable
                            // before the next mode-0 sampling edge.
                            spi_sclk <= 1'b0;
                            if (bit_count == 3'd7) begin
                                state    <= IDLE;
                                busy     <= 1'b0;
                                done     <= 1'b1;
                                rx_data  <= rx_shift;
                                spi_cs_n <= 1'b1;
                                spi_mosi <= 1'b0;
                            end else begin
                                bit_count <= bit_count + 3'd1;
                                tx_shift  <= {tx_shift[6:0], 1'b0};
                                spi_mosi  <= tx_shift[6];
                            end
                        end
                    end else begin
                        divider_count <= divider_count + 16'd1;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
