module cache_controller(
    //clk and reset signals
    input logic clk,
    input logic rst_n,
    //cpu I/O signals
    input logic re,
    input logic we,
    input logic [31:0] cpu_addr_write,
    input logic [63:0] write_byte_sel,
    input logic [31:0] cpu_addr_read,
    input logic [511:0] cpu_data_write,
    input logic cpu_stall_cache,
    output logic [511:0] cpu_data_read,
    output logic cache_stall_cpu,
    //memory I/O signals
    output logic [31:0] mem_addr_read,
    output logic [31:0] mem_addr_write,
    output logic mem_re,
    output logic mem_we,
    input logic mem_ack,
    input logic [511:0] mem_data_read,
    output logic [511:0] mem_data_write,
    output logic cache_stall_mem,
    input logic mem_stall_cache
);


//signals for tag array
logic [5:0] tag_w_index, tag_r_index;
logic tag_we, tag_re;
logic [1:0] tag_way_sel;
logic [19:0] tag_din;
logic tag_valid;
logic tag_dirty;
logic [19:0] tag_out[0:3];
logic tag_valid_out[0:3];
logic tag_dirty_out[0:3];

//module instantiation tag_array
tag_array u_tag_array (
    .clk        (clk),         
    .w_index    (tag_w_index),
    .r_index    (tag_r_index),
    .we         (tag_we),
    .re         (tag_re),
    .way_sel    (tag_way_sel),
    .din_tag    (tag_din),
    .din_valid  (tag_valid),
    .din_dirty  (tag_dirty),
    .dout_tag   (tag_out),
    .dout_valid (tag_valid_out),
    .dout_dirty (tag_dirty_out)  
);


//signals for data_array
logic [5:0] data_w_index, data_r_index;
logic data_we, data_re;
logic [1:0] data_way_sel;
logic [511:0] din_data;
logic [63:0] byte_sel;

logic [511:0] dout_data[0:3];

//data_array_module_instantiation
// Module instantiation for the 4-way data array
data_array u_data_array (
    .clk       (clk),          
    .w_index   (data_w_index),
    .r_index   (data_r_index),
    .we        (data_we),
    .re        (data_re),
    .way_sel   (data_way_sel),
    .din_data  (din_data),
    .byte_sel  (byte_sel),
    .dout_data (dout_data)
);


//signals for comparator
logic [19:0] comp_in_tag[0:3];
logic [19:0] comp_cmp_tag;
logic [511:0] comp_data_in[0:3];
logic comp_valid_in[0:3];
logic comp_dirty_in[0:3];
logic cache_hit;
logic [511:0] comp_hit_data;
logic [1:0] comp_matched_way;


// Module instantiation for the comparator selector
comparator_selector u_comparator_selector (
    .in_tags    (comp_in_tag),
    .in_cmp_tag (comp_cmp_tag),
    .in_data    (comp_data_in),
    .valid_in   (comp_valid_in),
    .dirty_in   (comp_dirty_in),
    .cache_hit  (cache_hit),
    .matched_way (comp_matched_way),
    .hit_data   (comp_hit_data)
);


//signals for plru_way_selector
logic [5:0] plru_v_index;
logic [5:0] plru_u_index;
logic [1:0] plru_u_way;
logic [1:0] plru_v_way;
logic plru_we;


// Module instantiation for the PLRU way selector
plru_way_selector u_plru_way_selector (
    .clk     (clk),
    .plru_we (plru_we),
    .v_index (plru_v_index),
    .u_index (plru_u_index),
    .u_way   (plru_u_way),
    .v_way   (plru_v_way)
);



logic [2:0] read_fsm, write_fsm;


localparam IDLE_COMPARE = 3'b000;
localparam MISS1 = 3'b001;
localparam MISS2 = 3'b010;
localparam WRITE_BACK = 3'b011;
localparam MEM_ACC = 3'b100;
localparam TAG_MATCH = 3'b101;
localparam WRITE_CACHE = 3'b110;
localparam ERROR = 3'b111; //dummy state

logic internal_stall;
logic external_stall;





//signals for read fsm
logic [31:0] read_miss_address;
logic [19:0] read_miss_tags[0:3];
logic read_miss_valids [0:3];
logic read_miss_dirty [0:3];
logic [1:0] read_miss_victim;
logic [511:0] read_miss_data[0:3];
logic [511:0] read_miss_mem_data;
logic read_miss_stall;

//signals for write_fsm
logic [511:0] cache_write_data; //register for storing data from the write request
logic [511:0] mem_write_cache_data; //register for storing data from the memory on a write miss
logic [31:0] cache_write_address; // register for storing write request address
logic [19:0] write_miss_victim_tags[0:3]; //register for storing potential victim tags on a write miss
logic [511:0] write_miss_victim_data[0:3]; // register for storing potential victim data on a write miss
logic write_miss_victim_valids[0:3]; // potential victim valid states
logic write_miss_victim_dirty[0:3]; // potential victim dirty
logic [1:0] set_to_update; // matched way on a write hit
logic [63:0] cpu_write_byte_sel; //byte select signal from the cpu on a cache write
logic write_miss_stall; //signal for write miss stall

always@(posedge clk or negedge rst_n) begin : cache_read_control
    
    if(!rst_n) begin
        
        read_fsm <= IDLE_COMPARE;
    end
    else if(external_stall) begin
        read_fsm <= read_fsm;
    end
    else begin
        
        case(read_fsm)
        IDLE_COMPARE: begin
            
            if(re) begin
                if(!cache_hit) begin
                
                    read_miss_address <= cpu_addr_read; //MEM ACC
                    read_miss_tags <= tag_out; //WRITE BACK or MEM ACC
                    read_miss_dirty <= tag_dirty_out;
                    read_miss_valids <= tag_valid_out;
                    read_fsm <= MISS1;
                    read_miss_stall <= 1'b1;


                end
                else begin
                    read_fsm <= IDLE_COMPARE;
                    read_miss_stall <= 1'b0;
                end
            end
            else begin
                read_fsm <= IDLE_COMPARE;
                read_miss_stall <= 1'b0;
            end
        end
        MISS1: begin
            read_miss_victim <= plru_v_way;
            read_fsm <= MISS2;
        end
        MISS2: begin
            
            if(read_miss_valids[read_miss_victim] && read_miss_dirty[read_miss_victim]) begin
                read_fsm <= WRITE_BACK;

            end
            else begin
                read_fsm <= MEM_ACC;
            end
        end
        WRITE_BACK: begin
            if(!mem_we) begin
                mem_we <= 1'b1;
                mem_addr_write <= {read_miss_tags[read_miss_victim],read_miss_address[11:6],6'b0};
                mem_data_write <= read_miss_data[read_miss_victim];
                read_fsm <= WRITE_BACK;
            end
            else if(mem_ack) begin
                mem_we <= 1'b0;
                read_fsm <= MEM_ACC;
            end
        end
        MEM_ACC: begin
            if(!mem_re) begin
                mem_re <= 1'b1;
                mem_addr_read <= read_miss_address;
                read_fsm <= MEM_ACC;
            end
            else if (mem_ack) begin
                mem_re <= 1'b0;
                read_miss_mem_data <= mem_data_read;
                read_fsm <= WRITE_CACHE;
                read_miss_stall <= 1'b0; // read_miss_has been handle
            end
            else begin
                read_fsm <= MEM_ACC;
            end
        end
        WRITE_CACHE: begin
            read_fsm <= IDLE_COMPARE;
            

        end
        default: begin
            
            read_fsm <= IDLE_COMPARE;
        end
        endcase
    end
end


//always combinational blocks to control tag array
always_comb begin : tag_array_read_control
    if(external_stall) begin
        tag_re = 1'b0;
        tag_r_index = 'b0;
    end
    else if(read_fsm == IDLE_COMPARE && re) begin
        tag_re = 1'b1;
        tag_r_index = cpu_addr_read[11:6];
    end
    else if(write_fsm == TAG_MATCH && we) begin
        tag_re = 1'b1;
        tag_r_index = cpu_addr_write[11:6];
    end
    else begin
        tag_re = 1'b0;
        tag_r_index = 'b0;
    end
end

//control for tag array writes
always_comb begin : tag_array_write_control
    if(external_stall) begin
        tag_we = 1'b0;
        tag_w_index = 'b0;
        tag_way_sel = 'b0;
        tag_din = 'b0;
        tag_valid = 1'b0;
        tag_dirty = 1'b0;
    end
    else if(read_fsm == WRITE_CACHE) begin
        tag_we = 1'b1;
        tag_w_index = read_miss_address[11:6];
        tag_way_sel = read_miss_victim;
        tag_din = read_miss_address[31:12];
        tag_valid = 1'b1;
        tag_dirty = 1'b0;
    end
    else if(write_fsm == WRITE_CACHE && !write_miss_stall) begin
        tag_we = 1'b1;
        tag_w_index = cache_write_address[11:6];
        tag_way_sel = set_to_update;
        tag_din = cache_write_address[31:12];
        tag_valid = 1'b1;
        tag_dirty = 1'b1;
    end
    else begin
        tag_we = 1'b0;
        tag_w_index = 'b0;
        tag_way_sel = 'b0;
        tag_din = 'b0;
        tag_valid = 1'b0;
        tag_dirty = 1'b0;
    end
end


//control block for data_array_read
always_comb begin : data_array_read_control
    if(external_stall) begin
        data_re = 1'b0;
        data_r_index = 'b0;
    end
    else if(read_fsm == IDLE_COMPARE && re) begin
        data_re = 1'b1;
        data_r_index = cpu_addr_read[11:6];
    end
    else if(write_fsm == TAG_MATCH && re) begin
        data_re = 1'b1;
        data_r_index = cpu_addr_write[11:6];
    end
    else begin
        data_re = 1'b0;
        data_r_index = 'b0;
    end
end

//control for data array writes
always_comb begin : data_array_write_control
    if(external_stall) begin
        data_we = 1'b0;
        data_way_sel = 'b0;
        data_w_index = 'b0;
        byte_sel = 'b0;
        din_data = 'b0;
    end
    else if(read_fsm == WRITE_CACHE) begin
        data_we = 1'b1;
        data_way_sel = read_miss_victim;
        data_w_index = read_miss_address[11:6];
        byte_sel = 'b1;
        din_data = read_miss_mem_data;
    end
    else if(write_fsm == WRITE_CACHE) begin
        data_we = 1'b1;
        data_way_sel = set_to_update;
        data_w_index = cache_write_address[11:6];
        if(write_miss_stall) begin
            byte_sel = 'b1; 
            din_data = mem_write_cache_data;
        end
        else begin
            byte_sel = cpu_write_byte_sel;
            din_data = cache_write_data;
        end
    end
    else begin
        data_we = 1'b0;
        data_way_sel = 'b0;
        data_w_index = 'b0;
        byte_sel = 'b0;
        din_data = 'b0;
    end
end


//always combinational block for comparator control
always_comb begin : comparator_control
    if(external_stall) begin
        comp_cmp_tag = 'b0;
        comp_in_tag[0] = 'b0;
        comp_in_tag[1] = 'b0;
        comp_in_tag[2] = 'b0;
        comp_in_tag[3] = 'b0;
        comp_dirty_in[0] = 'b0;
        comp_dirty_in[1] = 'b0;
        comp_dirty_in[2] = 'b0;
        comp_dirty_in[3] = 'b0;
        comp_valid_in[0] = 'b0;
        comp_valid_in[1] = 'b0;
        comp_valid_in[2] = 'b0;
        comp_valid_in[3] = 'b0;
        comp_data_in[0] = 'b0;
        comp_data_in[1] = 'b0;
        comp_data_in[2] = 'b0;
        comp_data_in[3] = 'b0;
    end
    else if(read_fsm == IDLE_COMPARE && re) begin
        comp_cmp_tag = cpu_addr_read[31:12];
        comp_in_tag = tag_out;
        comp_valid_in = tag_valid_out;
        comp_dirty_in = tag_dirty_out;
        comp_data_in = dout_data;

    end
    else if(write_fsm == TAG_MATCH && we) begin
        comp_cmp_tag = cpu_addr_write[31:12];
        comp_in_tag = tag_out;
        comp_valid_in = tag_valid_out;
        comp_dirty_in = tag_dirty_out;
        comp_data_in[0] = 'b0;
        comp_data_in[1] = 'b0;
        comp_data_in[2] = 'b0;
        comp_data_in[3] = 'b0;
    end
    else begin
        comp_cmp_tag = 'b0;
        comp_in_tag[0] = 'b0;
        comp_in_tag[1] = 'b0;
        comp_in_tag[2] = 'b0;
        comp_in_tag[3] = 'b0;
        comp_dirty_in[0] = 'b0;
        comp_dirty_in[1] = 'b0;
        comp_dirty_in[2] = 'b0;
        comp_dirty_in[3] = 'b0;
        comp_valid_in[0] = 'b1;
        comp_valid_in[1] = 'b1;
        comp_valid_in[2] = 'b1;
        comp_valid_in[3] = 'b1;
        comp_data_in[0] = 'b0;
        comp_data_in[1] = 'b0;
        comp_data_in[2] = 'b0;
        comp_data_in[3] = 'b0;
    end
end



//always combinational block for plru control

always_comb begin : plru_victim_monitor
    if(external_stall) begin
        plru_v_index = 'b0;
    end
    else if(read_fsm == MISS1) begin
        plru_v_index = read_miss_address[11:6];
    end
    else if(write_fsm == MISS1) begin
        plru_v_index = cache_write_address[11:6];
    end
    else begin
        plru_v_index = 'b0;
    end
end


//combinational control for plru table updates
always_comb begin : plru_victim_update
    if(external_stall) begin
        plru_we = 1'b0;
        plru_u_index = 'b0;
        plru_u_way = 'b0;
    end
    else if(read_fsm == IDLE_COMPARE && re && cache_hit) begin
        plru_we = 1'b1;
        plru_u_index = cpu_addr_read[11:6];
        plru_u_way = comp_matched_way;
    end
    else if(write_fsm == TAG_MATCH && we && cache_hit) begin
        plru_we = 1'b1;
        plru_u_index = cpu_addr_write[11:6];
        plru_u_way = comp_matched_way;
    end
    else if(read_fsm == WRITE_CACHE) begin
        plru_we = 1'b1;
        plru_u_index = read_miss_address[11:6];
        plru_u_way = read_miss_victim;
    end
    else if(write_fsm == WRITE_CACHE) begin
        plru_we = 1'b1;
        plru_u_index = cache_write_address[11:6];
        plru_u_way = set_to_update;
    end
    else begin
        plru_we = 1'b0;
        plru_u_index = 'b0;
        plru_u_way = 'b0;
    end
end



//sequential write fsm logic control

always_ff @(posedge clk or negedge rst_n) begin : cache_write_control
    
    if(!rst_n) begin
        write_fsm <= TAG_MATCH;
    end
    else if(external_stall) begin
        write_fsm <= write_fsm;
    end
    else begin
        case(write_fsm)
        TAG_MATCH: begin
            if(we) begin
                cache_write_data <= cpu_data_write;
                cache_write_address <= cpu_addr_write;
                cpu_write_byte_sel <= write_byte_sel;
                if(cache_hit) begin
                    write_fsm <= WRITE_CACHE;
                    set_to_update <= comp_matched_way;
                    write_miss_stall <= 1'b0;
                end
                else begin
                    write_fsm <= MISS1;
                    write_miss_victim_tags <= tag_out;
                    write_miss_victim_data <= dout_data;
                    write_miss_victim_valids <= tag_valid_out;
                    write_miss_victim_dirty <= tag_dirty_out;
                    write_miss_stall <= 1'b1;
                end
            end
            else begin
                write_fsm <= TAG_MATCH;
            end
        end
        WRITE_CACHE: begin
            if(write_miss_stall) begin
                write_miss_stall <= 1'b0;
                write_fsm <= WRITE_CACHE;
            end
            else begin
                write_fsm <= TAG_MATCH;
            end
            
        end
        MISS1: begin
            set_to_update <= plru_v_way;
            write_fsm <= MISS2;
        end
        MISS2: begin
            if(write_miss_victim_dirty[set_to_update] && write_miss_victim_valids[set_to_update]) begin
                write_fsm <= WRITE_BACK;
            end
            else begin
                write_fsm <= MEM_ACC;
            end
        end
        WRITE_BACK: begin
            if(!mem_we) begin
                mem_we <= 1'b1;
                mem_addr_write <= {write_miss_victim_tags[set_to_update],cache_write_address[11:6],6'b0};
                mem_data_write <= write_miss_victim_data[set_to_update];
                write_fsm <= WRITE_BACK;
            end
            else if(mem_ack) begin
                mem_we <= 1'b0;
                write_fsm <= MEM_ACC;
            end
        end
        MEM_ACC: begin
            if(!mem_re) begin
                mem_re <= 1'b1;
                mem_addr_read <= cache_write_address;
                write_fsm <= MEM_ACC;
            end
            else if(mem_ack) begin
                mem_re <= 1'b0;
                write_fsm <= WRITE_CACHE;
                mem_write_cache_data <= mem_data_read;
            end
        end
        default: begin
            write_fsm <= TAG_MATCH;
        end
        endcase
    end

end

assign external_stall = cpu_stall_cache | mem_stall_cache;

assign cpu_data_read = (read_fsm == IDLE_COMPARE && re && cache_hit) ? comp_hit_data : 'b0;


assign cache_stall_cpu = write_miss_stall | read_miss_stall | (!cache_hit) | mem_stall_cache;

assign cache_stall_mem = cpu_stall_cache;

endmodule