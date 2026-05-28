`timescale 1ns / 1ps

module tag_array_tb;

    // ---------------------------------------------------------
    // 1. Testbench Signals (Matching Module Ports)
    // ---------------------------------------------------------
    logic        clk;
    logic [5:0]  w_index;
    logic [5:0]  r_index;
    logic        we;
    logic        re;
    logic [1:0]  way_sel;
    logic [19:0] din_tag;
    logic        din_valid;
    logic        din_dirty;
    
    // Output array ports
    logic [19:0] dout_tag[0:3];
    logic        dout_valid[0:3];
    logic        dout_dirty[0:3];

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
    tag_array uut (
        .clk(clk),
        .w_index(w_index),
        .r_index(r_index),
        .we(we),
        .re(re),
        .way_sel(way_sel),
        .din_tag(din_tag),
        .din_valid(din_valid),
        .din_dirty(din_dirty),
        .dout_tag(dout_tag),
        .dout_valid(dout_valid),
        .dout_dirty(dout_dirty)
    );

    // ---------------------------------------------------------
    // 4. Testbench Stimulus Tasks
    // ---------------------------------------------------------
    
    // Task to initialize all driving signals to zero/inactive states
    task automatic initialize_signals();
        w_index   = 6'b0;
        r_index   = 6'b0;
        we        = 1'b0;
        re        = 1'b0;
        way_sel   = 2'b0;
        din_tag   = 20'b0;
        din_valid = 1'b0;
        din_dirty = 1'b0;
    endtask

    // Task to perform a sequential write operation to a specified set and way
    task automatic write_tag_entry(
        input logic [5:0]  set_index,
        input logic [1:0]  target_way,
        input logic [19:0] tag_value,
        input logic        valid_bit,
        input logic        dirty_bit
    );
        @(posedge clk);
        we        = 1'b1;
        w_index   = set_index;
        way_sel   = target_way;
        din_tag   = tag_value;
        din_valid = valid_bit;
        din_dirty = dirty_bit;
        
        @(posedge clk); // Await the active clock edge for sequential update
        we        = 1'b0;
        $display("[WRITE TAG] Set: %0d | Way: %0d | Tag: 0x%5h | Valid: %b | Dirty: %b", 
                 set_index, target_way, tag_value, valid_bit, dirty_bit);
    endtask

    // Task to execute a combinational read and display the meta status of a set
    task automatic read_tag_set(input logic [5:0] set_index);
        @(posedge clk);
        re      = 1'b1;
        r_index = set_index;
        
        #1; // Short delay to allow combinational paths to evaluate
        $display("----------------------------------------------------------------------");
        $display("[READ SET] Querying Set Index: %0d", set_index);
        for (int i = 0; i < 4; i = i + 1) begin
            $display("  -> Way %0d: Tag = 0x%5h | Valid = %b | Dirty = %b", 
                     i, dout_tag[i], dout_valid[i], dout_dirty[i]);
        end
        $display("----------------------------------------------------------------------");
        
        re      = 1'b0;
    endtask

    // ---------------------------------------------------------
    // 5. Main Test Execution Sequence
    // ---------------------------------------------------------
    initial begin
        $display("=========================================================");
        $display("          STARTING TAG ARRAY METADATA TESTBENCH          ");
        $display("=========================================================\n");
        
        initialize_signals();
        #(CLK_PERIOD * 2);

        // --- Test Scenario 1: Allocate entries into Set 12 ---
        $display("### SCENARIO 1: Writing unique tag addresses to Set 12 ###");
        // Allocating clean lines into Way 0 and Way 1
        write_tag_entry(.set_index(6'd12), .target_way(2'b00), .tag_value(20'hA0A0A), .valid_bit(1'b1), .dirty_bit(1'b0));
        write_tag_entry(.set_index(6'd12), .target_way(2'b01), .tag_value(20'hB1B1B), .valid_bit(1'b1), .dirty_bit(1'b0));
        
        // Read back Set 12 to verify parallel tag allocation
        read_tag_set(.set_index(6'd12));

        // --- Test Scenario 2: Handle a CPU Write Hit (Marking a Line as Dirty) ---
        $display("\n### SCENARIO 2: Updating Way 0 of Set 12 to Dirty status (CPU Write Hit) ###");
        // Simulating an update to an existing line to assert the dirty status bit
        write_tag_entry(.set_index(6'd12), .target_way(2'b00), .tag_value(20'hA0A0A), .valid_bit(1'b1), .dirty_bit(1'b1));
        
        // Read back to confirm data status field transitioned correctly
        read_tag_set(.set_index(6'd12));

        // --- Test Scenario 3: Verify Empty Array Boundary ---
        $display("\n### SCENARIO 3: Reading an uninitialized/empty set (Set 45) ###");
        read_tag_set(.set_index(6'd45));

        #(CLK_PERIOD * 5);
        $display("=========================================================");
        $display("             TAG ARRAY TESTING COMPLETED                ");
        $display("=========================================================");
        $finish;
    end

endmodule