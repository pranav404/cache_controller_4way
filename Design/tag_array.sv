module tag_array(
input logic clk,
input logic [5:0] w_index,
input logic [5:0] r_index,
input logic we,
input logic re,
input logic [1:0] way_sel,
input logic [19:0] din_tag,
input logic din_valid,
input logic din_dirty,
//output ports
output logic [19:0] dout_tag[0:3],
output logic dout_valid[0:3],
output logic dout_dirty[0:3]
);



typedef struct packed {

logic [19:0] tag;
logic valid;
logic dirty;
} tag_mem_array;

tag_mem_array tag_mem_banks [0:63][0:3];

//Sequential Write to tag_bank
always_ff @(posedge clk) begin
	if(we) begin
		tag_mem_banks[w_index][way_sel] <= {din_tag,din_valid,din_dirty};
	end
end

//combinational_read to tag_bank
always_comb begin
	for(int i = 0; i < 4; i = i+1) begin
		if(re) begin
			dout_tag[i] = tag_mem_banks[r_index][i].tag;
			dout_valid[i] = tag_mem_banks[r_index][i].valid;
			dout_dirty[i] = tag_mem_banks[r_index][i].dirty;
		end
		else begin
			dout_tag[i] = 'b0;
			dout_valid[i] = 'b0;
			dout_dirty[i] = 'b0;
		end
	end
end
endmodule
	
