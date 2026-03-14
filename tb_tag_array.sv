`timescale 1ns/1ps

module tb_top();

    // --- 1. Signal Declarations ---
    logic clk;
    logic [5:0] w_index;
    logic [5:0] r_index;
    logic we;
    logic [1:0] way_sel;
    logic [19:0] din_tag;
    logic din_valid;
    logic din_dirty;

    logic [19:0] dout_tag [3:0];
    logic dout_valid [3:0];
    logic dout_dirty [3:0];

    // --- 2. Module Instantiation (UUT) ---
    tag_array uut (
        .clk(clk),
        .w_index(w_index),
        .r_index(r_index),
        .we(we),
        .way_sel(way_sel),
        .din_tag(din_tag),
        .din_valid(din_valid),
        .din_dirty(din_dirty),
        .dout_tag(dout_tag),
        .dout_valid(dout_valid),
        .dout_dirty(dout_dirty)
    );

    // --- 3. Clock Generation ---
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100MHz clock
    end

    // --- 4. Test Stimulus ---
    initial begin
        // Initialize Inputs
        we = 0;
        w_index = 0;
        r_index = 0;
        way_sel = 0;
        din_tag = 0;
        din_valid = 0;
        din_dirty = 0;

        $display("[%0t ns] Starting Tag Array Verification...", $time);
        #20; 

        // Case 1: Write to Way 0, Set 10
        @(posedge clk);
        we = 1;
        w_index = 6'd10;
        way_sel = 2'd0;
        din_tag = 20'hABCDE;
        din_valid = 1;
        din_dirty = 0;
        $display("[%0t ns] WRITE REQUEST: Set %0d, Way %0d, Tag %h", $time, w_index, way_sel, din_tag);
        
        // Case 2: Verify Bypass Logic (Read during Write at Set 10)
        r_index = 6'd10; 
        #1; // Wait for combinational logic to settle
        if (dout_tag[0] == 20'hABCDE) 
            $display("[%0t ns] [PASS] Bypass Logic successful at Set %0d.", $time, r_index);
        else 
            $display("[%0t ns] [FAIL] Bypass Logic failed. Expected ABCDE, got %h", $time, dout_tag[0]);

        @(posedge clk);
        we = 0; 

        // Case 3: Verify Storage in next cycle
        @(posedge clk);
        r_index = 6'd10;
        #1;
        if (dout_tag[0] == 20'hABCDE && dout_valid[0] == 1)
            $display("[%0t ns] [PASS] Storage verified for Set 10, Way 0.", $time);
        else
            $display("[%0t ns] [FAIL] Storage failed for Set 10.", $time);

        // Case 4: Write to Set 20, Way 3
        @(posedge clk);
        we = 1;
        w_index = 6'd20;
        way_sel = 2'd3;
        din_tag = 20'h54321;
        din_valid = 1;
        din_dirty = 1;
        $display("[%0t ns] WRITE REQUEST: Set %0d, Way %0d, Tag %h", $time, w_index, way_sel, din_tag);
        
        @(posedge clk);
        we = 0;
        r_index = 6'd20;
        #1;
        if (dout_tag[3] == 20'h54321 && dout_dirty[3] == 1)
            $display("[%0t ns] [PASS] Storage verified for Set 20, Way 3.", $time);

        #50;
        $display("[%0t ns] Verification Complete.", $time);
        $finish;
    end

    // --- 5. Waveform Dumping ---
    initial begin
        $dumpfile("wave.vcd");
        $dumpvars(0, tb_top);
    end

endmodule
