// ============================================================
// cache_cpu_agent.sv
// Active agent for the CPU side of the cache controller
// ============================================================
class cache_cpu_agent extends uvm_agent;
  `uvm_component_utils(cache_cpu_agent)

  cache_cpu_sequencer sqr;
  cache_cpu_driver    drv;
  cache_cpu_monitor   mon;

  // Analysis port forwarded up to the environment
  uvm_analysis_port #(cache_seq_item) ap;

  function new(string name = "cache_cpu_agent", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap  = new("ap", this);
    mon = cache_cpu_monitor::type_id::create("mon", this);

    // Only build driver+sequencer if active
    if (get_is_active() == UVM_ACTIVE) begin
      sqr = cache_cpu_sequencer::type_id::create("sqr", this);
      drv = cache_cpu_driver::type_id::create("drv", this);
    end
  endfunction

  function void connect_phase(uvm_phase phase);
    // Wire driver to sequencer (TLM pull)
    if (get_is_active() == UVM_ACTIVE)
      drv.seq_item_port.connect(sqr.seq_item_export);

    // Forward monitor's analysis port upward
    mon.ap.connect(ap);
  endfunction

endclass
