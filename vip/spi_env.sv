class spi_env extends uvm_env;
  `uvm_component_utils(spi_env)

  // Component members for the environment class.
  //spi_agent spi_agent_h;

  // Method to build the environment class.
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    //spi_agent_h = spi_agent::type_id::create("spi_agent_h", this);
  endfunction : build_phase
