// Dedicated interrupt sideband interface for UVM monitoring.
interface irq_if;
    logic irq;

    modport dut (output irq);
    modport monitor (input irq);
endinterface
