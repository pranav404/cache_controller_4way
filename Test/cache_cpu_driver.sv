// ============================================================
// cache_cpu_driver.sv
// Drives CPU-side signals onto the DUT via the virtual interface
// ============================================================
class cache_cpu_driver extends uvm_driver #(cache_seq_item);
  `uvm_component_utils(cache_cpu_driver)

  // Handle to the virtual interface (set via uvm_config_db in tb_top)
  virtual cache_if.cpu_drv_mp vif;

  function new(string name = "cache_cpu_driver", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual cache_if.cpu_drv_mp)::get(this, "", "vif", vif))
      `uvm_fatal("NO_VIF", "cache_cpu_driver: virtual interface not found in config_db")
  endfunction

  task run_phase(uvm_phase phase);
    cache_seq_item req;

    // De-assert all outputs after reset
    @(posedge vif.clk iff vif.cpu_drv_cb.rst_n === 1'b1);  // wait for reset release
    drive_idle();

    forever begin
      // 1. Pull next transaction from sequencer
      seq_item_port.get_next_item(req);

      // 2. Wait until cache is not stalling before driving
      wait_no_stall();

      // 3. Drive the transaction for one cycle
      drive_txn(req);

      // 4. If cache asserts stall, hold signals until it deasserts
      while (vif.cpu_drv_cb.cache_stall_cpu === 1'b1)
        @(vif.cpu_drv_cb);

      // 5. Capture response back into the item
      req.cpu_data_read   = vif.cpu_drv_cb.cpu_data_read;
      req.cache_stall_cpu = vif.cpu_drv_cb.cache_stall_cpu;

      // 6. Release transaction back to sequencer
      seq_item_port.item_done();

      // 7. Return to idle for one cycle between transactions
      drive_idle();
    end
  endtask

  // Drive a single transaction onto the interface
  task drive_txn(cache_seq_item req);
    @(vif.cpu_drv_cb);
    vif.cpu_drv_cb.re             <= req.re;
    vif.cpu_drv_cb.we             <= req.we;
    vif.cpu_drv_cb.cpu_addr_read  <= req.cpu_addr_read;
    vif.cpu_drv_cb.cpu_addr_write <= req.cpu_addr_write;
    vif.cpu_drv_cb.cpu_data_write <= req.cpu_data_write;
    vif.cpu_drv_cb.write_byte_sel <= req.write_byte_sel;
    vif.cpu_drv_cb.cpu_stall_cache <= 1'b0;
  endtask

  // Drive idle (no request)
  task drive_idle();
    @(vif.cpu_drv_cb);
    vif.cpu_drv_cb.re              <= 1'b0;
    vif.cpu_drv_cb.we              <= 1'b0;
    vif.cpu_drv_cb.cpu_addr_read   <= 32'b0;
    vif.cpu_drv_cb.cpu_addr_write  <= 32'b0;
    vif.cpu_drv_cb.cpu_data_write  <= 512'b0;
    vif.cpu_drv_cb.write_byte_sel  <= 64'b0;
    vif.cpu_drv_cb.cpu_stall_cache <= 1'b0;
  endtask

  // Block until cache_stall_cpu is low
  task wait_no_stall();
    while (vif.cpu_drv_cb.cache_stall_cpu === 1'b1)
      @(vif.cpu_drv_cb);
  endtask

endclass
