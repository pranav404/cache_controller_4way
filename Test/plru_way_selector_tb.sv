`timescale 1ns / 1ps

module plru_way_selector_tb;

    // ---------------------------------------------------------
    // 1. Testbench Signals (Matching Module Ports)
    // ---------------------------------------------------------
    logic       clk;
    logic       plru_we;
    logic [5:0] v_index;
    logic [5:0] u_index;
    logic [1:0] u_way;
    logic [1:0] v_way;

    // ---------------------------------------------------------
    // 2. Clock Generation (100 MHz / 10ns period)
    // ---------------------------------------------------------
    localparam CLK_PERIOD = 10;
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // ---------------------------------------------------------
    // 3. Unit Under Test (UUT) Instantiation
    // ---------------------------------------------------------
    plru_way_selector uut (
        .clk(clk),
        .plru_we(plru_we),
        .v_index(v_index),
        .u_index(u_index),
        .u_way(u_way),
        .v_way(v_way)
    );

    // ---------------------------------------------------------
    // 4. Testbench Stimulus Tasks
    // ---------------------------------------------------------
    
    // Task to initialize all driving signals to zero/inactive states
    task automatic initialize_signals();
        plru_we = 1'b0;
        v_index = 6'b0;
        u_index = 6'b0;
        u_way   = 2'b0;
    endtask

    // Task to simulate a CPU cache hit or refill update (MRU update)
    task automatic update_mru_way(input logic [5:0] set_index, input logic [1:0] target_way);
        @(posedge clk);
        plru_we = 1'b1;
        u_index = set_index;
        u_way   = target_way;
        
        @(posedge clk); // Allow tree state registers to commit changes sequentially
        plru_we = 1'b0;
        $display("[UPDATE MRU] Set: %0d | Way Accessed: %b (Way %0d) marked as Most Recently Used", 
                 set_index, target_way, target_way);
    endtask

    // Task to check the current victim/eviction way proposed by the PLRU tree
    task automatic check_victim_way(input logic [5:0] set_index);
        // Victim evaluation is combinational based on v_index
        v_index = set_index;
        #1; // Brief delay for combinational signals to settle
        $display("----------------------------------------------------------------------");
        $display("[PROBE VICTIM] Querying Set Index: %0d", set_index);
        $display("  -> Current Recommended Eviction Target: Way %0d (Binary: %b)", v_way, v_way);
        $display("----------------------------------------------------------------------");
    endtask

    // ---------------------------------------------------------
    // 5. Main Test Execution Sequence
    // ---------------------------------------------------------
    initial begin
        $display("=========================================================");
        $display("          STARTING PSEUDO-LRU SELECTOR TESTBENCH         ");
        $display("=========================================================\n");
        
        initialize_signals();
        #(CLK_PERIOD * 2);

        // NOTE: At simulator startup, the uninitialized plru_tree[0:63] defaults to 'x'.
        // In the UUT combinational blocks, 'x' will follow default parsing paths. Let's see how it behaves and then initialize it.

        // --- Test Scenario 1: Initial Default Victim ---
        $display("### SCENARIO 1: Checking fallback/initial victim of uninitialized Set 4 ###");
        check_victim_way(.set_index(6'd4));

        // --- Test Scenario 2: Accessing Way 00 ---
        $display("\n### SCENARIO 2: Accessing Way 0 of Set 4. This should protect it from eviction. ###");
        update_mru_way(.set_index(6'd4), .target_way(2'b00));
        check_victim_way(.set_index(6'd4)); // Victim shouldn't be Way 0 now

        // --- Test Scenario 3: Flooding accesses to shift the Victim pointer entirely ---
        $display("\n### SCENARIO 3: Accessing other ways in Set 4 to walk the binary tree nodes ###");
        
        // Access Way 2
        update_mru_way(.set_index(6'd4), .target_way(2'b10));
        check_victim_way(.set_index(6'd4));

        // Access Way 1
        update_mru_way(.set_index(6'd4), .target_way(2'b01));
        check_victim_way(.set_index(6'd4));

        // Access Way 3
        update_mru_way(.set_index(6'd4), .target_way(2'b11));
        check_victim_way(.set_index(6'd4));

        // --- Test Scenario 4: Isolating Sets ---
        $display("\n### SCENARIO 4: Verifying updates on Set 4 do not leak into adjacent Set 5 ###");
        check_victim_way(.set_index(6'd5));

        #(CLK_PERIOD * 5);
        $display("=========================================================");
        $display("             PSEUDO-LRU TESTING COMPLETED                ");
        $display("=========================================================");
        $finish;
    end

endmodule