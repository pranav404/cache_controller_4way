// ============================================================
// cache_mem_monitor.sv
// Observes memory-side transactions (what cache requests)
// ============================================================
class cache_mem_monitor extends uvm_monitor;
  `uvm_component_utils(cache_mem_monitor)

  uvm_analysis_port #(cache_mem_seq_item) ap;
  virtual cache_if.mem_mon_mp vif;

  function new(string name = "cache_mem_monitor", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap = new("ap", this);
    if (!uvm_config_db #(virtual cache_if.mem_mon_mp)::get(this, "", "vif", vif))
      `uvm_fatal("NO_VIF", "cache_mem_monitor: virtual interface not found in config_db")
  endfunction

  task run_phase(uvm_phase phase);
    cache_mem_seq_item txn;
    @(posedge vif.clk iff vif.mem_mon_cb.rst_n === 1'b1);

    forever begin
      @(vif.mem_mon_cb);

      // Capture whenever cache drives a memory request
      if (vif.mem_mon_cb.mem_re || vif.mem_mon_cb.mem_we) begin
        txn = cache_mem_seq_item::type_id::create("txn");
        txn.mem_re         = vif.mem_mon_cb.mem_re;
        txn.mem_we         = vif.mem_mon_cb.mem_we;
        txn.mem_addr_read  = vif.mem_mon_cb.mem_addr_read;
        txn.mem_addr_write = vif.mem_mon_cb.mem_addr_write;
        txn.mem_data_write = vif.mem_mon_cb.mem_data_write;
        txn.mem_ack        = vif.mem_mon_cb.mem_ack;
        txn.mem_data_read  = vif.mem_mon_cb.mem_data_read;
        ap.write(txn);
      end
    end
  endtask

endclass
