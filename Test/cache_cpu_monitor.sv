// ============================================================
// cache_cpu_monitor.sv
// Passively observes CPU-side transactions and broadcasts them
// ============================================================
class cache_cpu_monitor extends uvm_monitor;
  `uvm_component_utils(cache_cpu_monitor)

  // Analysis port — scoreboard and coverage subscribe to this
  uvm_analysis_port #(cache_seq_item) ap;

  virtual cache_if.cpu_mon_mp vif;

  function new(string name = "cache_cpu_monitor", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap = new("ap", this);
    if (!uvm_config_db #(virtual cache_if.cpu_mon_mp)::get(this, "", "vif", vif))
      `uvm_fatal("NO_VIF", "cache_cpu_monitor: virtual interface not found in config_db")
  endfunction

  task run_phase(uvm_phase phase);
    cache_seq_item txn;

    // Wait for reset to deassert
    @(posedge vif.clk iff vif.cpu_mon_cb.rst_n === 1'b1);

    forever begin
      @(vif.cpu_mon_cb);

      // Only capture when re or we is active and no stall
      if ((vif.cpu_mon_cb.re || vif.cpu_mon_cb.we) &&
          !vif.cpu_mon_cb.cache_stall_cpu) begin

        txn = cache_seq_item::type_id::create("txn");
        txn.re              = vif.cpu_mon_cb.re;
        txn.we              = vif.cpu_mon_cb.we;
        txn.cpu_addr_read   = vif.cpu_mon_cb.cpu_addr_read;
        txn.cpu_addr_write  = vif.cpu_mon_cb.cpu_addr_write;
        txn.cpu_data_write  = vif.cpu_mon_cb.cpu_data_write;
        txn.write_byte_sel  = vif.cpu_mon_cb.write_byte_sel;
        txn.cpu_data_read   = vif.cpu_mon_cb.cpu_data_read;
        txn.cache_stall_cpu = vif.cpu_mon_cb.cache_stall_cpu;

        // Broadcast to scoreboard/coverage
        ap.write(txn);
      end
    end
  endtask

endclass
