// ============================================================
// cache_mem_driver.sv
// Drives memory-side responses: mem_ack, mem_data_read
// Reacts to what the cache requests (mem_re, mem_we)
// ============================================================
class cache_mem_driver extends uvm_driver #(cache_mem_seq_item);
  `uvm_component_utils(cache_mem_driver)

  virtual cache_if.mem_drv_mp vif;

  // Simple associative array acting as backing memory model
  // Key = address (cache-line aligned), Value = 512-bit data
  logic [511:0] mem_model [logic [31:0]];

  function new(string name = "cache_mem_driver", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual cache_if.mem_drv_mp)::get(this, "", "vif", vif))
      `uvm_fatal("NO_VIF", "cache_mem_driver: virtual interface not found in config_db")
  endfunction

  task run_phase(uvm_phase phase);
    // De-assert all memory response signals at start
    vif.mem_drv_cb.mem_ack         <= 1'b0;
    vif.mem_drv_cb.mem_data_read   <= 512'b0;
    vif.mem_drv_cb.mem_stall_cache <= 1'b0;

    @(posedge vif.clk iff vif.mem_drv_cb.rst_n === 1'b1);

    forever begin
      @(vif.mem_drv_cb);

      // React to memory read request from cache
      if (vif.mem_drv_cb.mem_re === 1'b1) begin
        handle_mem_read(vif.mem_drv_cb.mem_addr_read);
      end

      // React to memory write request (write-back from cache)
      else if (vif.mem_drv_cb.mem_we === 1'b1) begin
        handle_mem_write(vif.mem_drv_cb.mem_addr_write,
                         vif.mem_drv_cb.mem_data_write);
      end
    end
  endtask

  // Handle a read: wait ack_delay cycles, return data, pulse ack
  task handle_mem_read(input logic [31:0] addr);
    logic [511:0] return_data;
    int delay;
    delay = $urandom_range(2, 8); // random latency

    // Look up in memory model; return 0 if never written
    if (mem_model.exists(addr))
      return_data = mem_model[addr];
    else
      return_data = {16{addr}}; // deterministic fill: repeat addr 16x for debugging

    // Wait the latency cycles
    repeat(delay) @(vif.mem_drv_cb);

    // Assert ack with data for one cycle
    vif.mem_drv_cb.mem_ack       <= 1'b1;
    vif.mem_drv_cb.mem_data_read <= return_data;
    @(vif.mem_drv_cb);

    // Deassert
    vif.mem_drv_cb.mem_ack       <= 1'b0;
    vif.mem_drv_cb.mem_data_read <= 512'b0;
  endtask

  // Handle a write-back: store data in memory model, pulse ack
  task handle_mem_write(input logic [31:0] addr, input logic [511:0] data);
    int delay;
    delay = $urandom_range(2, 8);

    // Store into backing model
    mem_model[addr] = data;

    // Wait latency then ack
    repeat(delay) @(vif.mem_drv_cb);
    vif.mem_drv_cb.mem_ack <= 1'b1;
    @(vif.mem_drv_cb);
    vif.mem_drv_cb.mem_ack <= 1'b0;
  endtask

endclass
