// ============================================================
// cache_mem_agent.sv
// Active agent for the memory side of the cache controller
// ============================================================
class cache_mem_agent extends uvm_agent;
  `uvm_component_utils(cache_mem_agent)

  cache_mem_driver    drv;
  cache_mem_monitor   mon;

  uvm_analysis_port #(cache_mem_seq_item) ap;

  function new(string name = "cache_mem_agent", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap  = new("ap", this);
    mon = cache_mem_monitor::type_id::create("mon", this);
    if (get_is_active() == UVM_ACTIVE)
      drv = cache_mem_driver::type_id::create("drv", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    mon.ap.connect(ap);
    // Note: mem_agent driver is reactive (no sequencer needed —
    // it responds autonomously to DUT requests)
  endfunction

endclass
