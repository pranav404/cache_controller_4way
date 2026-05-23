module data_array(
input logic clk,
input logic [5:0] w_index,
input logic [5:0] r_index,
input logic we,
input logic re,
input logic [1:0] way_sel,
input logic [511:0] din_data,
input logic [63:0] byte_sel, //onehot encoded if write hit, else all ones on a miss
//output ports
output logic [511:0] dout_data[0:3]
);


logic [511:0] data_mem_banks [0:63] [0:3];
integer i;

//Sequential Write to data_bank
always_ff @(posedge clk) begin
	if(we) begin
		//Byte masking
		for(i = 0; i< 64; i = i+1) begin
			if(byte_sel[i] == 1'b1) begin
				data_mem_banks[way_sel][w_index][i*8 +: 8] = din_data[i*8 +: 8];
			end
		end
	end
end

//combinational_read to tag_bank
always_comb begin
	for(i = 0; i < 4; i = i+1) begin
		if(re) begin
			dout_data[i] = data_mem_banks[i][r_index];
		end
		else begin
			dout_data[i] = 'b0;
		end
	end
end
endmodule
