// ============================================================
// cache_env.sv
// Top-level UVM environment
// ============================================================
class cache_env extends uvm_env;
  `uvm_component_utils(cache_env)

  cache_cpu_agent  cpu_agent;
  cache_mem_agent  mem_agent;
  cache_scoreboard scb;
  cache_coverage   cov;

  function new(string name = "cache_env", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    cpu_agent = cache_cpu_agent::type_id::create("cpu_agent", this);
    mem_agent = cache_mem_agent::type_id::create("mem_agent", this);
    scb       = cache_scoreboard::type_id::create("scb",      this);
    cov       = cache_coverage::type_id::create("cov",        this);
  endfunction

  function void connect_phase(uvm_phase phase);
    // Scoreboard connections
    cpu_agent.ap.connect(scb.cpu_export);
    mem_agent.ap.connect(scb.mem_export);

    // Coverage connections
    cpu_agent.ap.connect(cov.analysis_export);  // base uvm_subscriber port
    mem_agent.ap.connect(cov.mem_export);
  endfunction

endclass
