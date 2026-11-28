class spi_test_base extends uvm_test;
// UVM factory registration macro for the test class.
`uvm_component_utils(spi_test_base);

//Component nembers for the test class.
spi_env_cfg env_cfg;

//Method to build the test class.
function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    env_cfg = spi_env_cfg::type_id::create("env_cfg");

    if (!uvm_config_db#(virtual apb_if)::get(this, "", "apb_vif", env_cfg.apb_vif))
        `uvm_fatal("SPI_CFG", "tb_top did not provide apb_vif")
    if (!uvm_config_db#(virtual spi_if)::get(this, "", "spi_vif", env_cfg.spi_vif))
        `uvm_fatal("SPI_CFG", "tb_top did not provide spi_vif")
    if (!uvm_config_db#(virtual irq_if)::get(this, "", "irq_vif", env_cfg.irq_vif))
        `uvm_fatal("SPI_CFG", "tb_top did not provide irq_vif")

    if (!env_cfg.validate())
        `uvm_fatal("SPI_CFG", "SPI environment configuration is invalid")

    // The environment can retrieve this as "cfg" from its build_phase.
    uvm_config_db#(spi_env_cfg)::set(this, "env", "cfg", env_cfg);
endfunction : build_phase   

extern virtual function void configure_apb_agent();
extern function new(string name = "spi_test_base", uvm_component parent = null);

endclass : spi_test_base

function spi_test_base::new(string name = "spi_test_base", uvm_component parent = null);
 super.new(name, parent);
endfunction

// This can be overloaded by extensions to this base class
function void spi_test_base::configure_apb_agent();
 //cfg.active = UVM_ACTIVE;
 //cfg.has_functional_coverage = 0;
 //cfg.has_scoreboard = 0;
 //// SPI is on select line 0 for address range 0-18h
 //cfg.no_select_lines = 1;
 //cfg.start_address[0] = 32'h0;
 //cfg.range[0] = 32'h18;
endfunction: 



