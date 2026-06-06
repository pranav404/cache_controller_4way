// ============================================================
// cache_cpu_sequencer.sv
// Standard UVM sequencer — no custom logic needed
// ============================================================
class cache_cpu_sequencer extends uvm_sequencer #(cache_seq_item);
  `uvm_component_utils(cache_cpu_sequencer)

  function new(string name = "cache_cpu_sequencer", uvm_component parent = null);
    super.new(name, parent);
  endfunction

endclass
