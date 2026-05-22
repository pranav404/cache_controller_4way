`timescale 1ns/1ps

module tb_tag_array;

    // 1. Interface Signals
    bit clk;
    logic [5:0] w_index;
    logic [5:0] r_index;
    logic we;
    logic re;
    logic [1:0] way_sel;
    logic [19:0] din_tag;
    logic din_valid;
    logic din_dirty;

    // Outputs from the DUT
    logic [19:0] dout_tag[3:0];
    logic dout_valid[3:0];
    logic dout_dirty[3:0];

    // 2. Instantiate the Device Under Test (DUT)
    tag_array dut (
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

    // 3. Clock Generation (50MHz / 20ns period)
    always@(*) begin
        #10 clk <= ~clk;
    end

    // 4. Environment Waveform Dumping
    initial begin
        $dumpfile("dump.vcd"); // Creates the waveform trace file
        $dumpvars(0, tag_array_tb); // Dumps all signals in this testbench and below
    end

    // 5. Basic Stimulus: Straight Writes and Reads on Overlapping Locations
    initial begin
        // Initialize all inputs to 0
        we        = 0;
        re        = 0;
        w_index   = 0;
        r_index   = 0;
        way_sel   = 0;
        din_tag   = 0;
        din_valid = 0;
        din_dirty = 0;
        
        // Hold reset/idle state for 2 clock cycles
        repeat(2) @(posedge clk);

        // --- STEP 1: WRITE TO A SET OF LOCATIONS ---
        $display("[%0t] Starting Write Sequence...", $time);
        
        // Write to Index 4, Way 0
        we        = 1;
        w_index   = 6'd4;
        way_sel   = 2'd0;
        din_tag   = 20'hAAAAA;
        din_valid = 1'b1;
        din_dirty = 1'b0;
        @(posedge clk);

        // Write to Index 4, Way 1
        w_index   = 6'd4;
        way_sel   = 2'd1;
        din_tag   = 20'hBBBBB;
        din_valid = 1'b1;
        din_dirty = 1'b1;
        @(posedge clk);

        // Write to Index 32, Way 3
        w_index   = 6'd32;
        way_sel   = 2'd3;
        din_tag   = 20'hCCCCC;
        din_valid = 1'b1;
        din_dirty = 1'b0;
        @(posedge clk);

        // Turn off write enable
        we = 0;
        repeat(2) @(posedge clk);

        // --- STEP 2: READ BACK FROM THE EXACT SAME LOCATIONS ---
        $display("[%0t] Starting Read Sequence...", $time);

        // Read from Index 4 (Should see hAAAAA on way 0, hBBBBB on way 1)
        re      = 1;
        r_index = 6'd4;
        @(posedge clk);
        

        // Read from Index 32 (Should see hCCCCC on way 3)
        r_index = 6'd32;
        @(posedge clk);

        // Read from an empty location (Index 15) to check default/empty output behavior
        r_index = 6'd15;
        @(posedge clk);

        // Turn off read enable
        re = 0;
        repeat(2) @(posedge clk);

        $display("[%0t] Simulation finished successfully. Check dump.vcd for waveforms.", $time);
        $finish;
    end

endmodule
