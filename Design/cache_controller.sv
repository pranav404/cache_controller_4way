module cache_controller(
    //clk and reset signals
    input logic clk,
    input logic rst_n,
    //cpu I/O signals
    input logic re,
    input logic we,
    input logic [31:0] cpu_addr_write,
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
    input logic mem_ack;
    input logic [511:0] mem_data_read,
    output logic [511:0] mem_data_write
    output logic cache_stall_mem,
    input logic mem_stall_cache,
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


// Module instantiation for the comparator selector
comparator_selector u_comparator_selector (
    .in_tags    (comp_in_tag),
    .in_cmp_tag (comp_cmp_tag),
    .in_data    (comp_data_in),
    .valid_in   (comp_valid_in),
    .dirty_in   (comp_dirty_in),
    .cache_hit  (cache_hit),
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

assign external_stall = cpu_stall_cache | mem_stall_cache;




//signals for read fsm
logic [31:0] read_miss_address;
logic [19:0] read_miss_tags[0:3];
logic read_miss_valids [0:3];
logic read_miss_dirty [0:3];
logic [1:0] read_miss_victim;
logic [511:0] read_miss_data[0:3];
always@(posedge clk or negedge rst_n) begin
    
    if(!rst_n) begin
        
        read_fsm <= IDLE_COMPARE;
    end
    else begin
        
        case(read_fsm)
        IDLE_COMPARE: begin
            
            if(!cache_hit && re) begin
                
                read_miss_address <= cpu_addr_read; //MEM ACC
                read_miss_tags <= tag_out; //WRITE BACK or MEM ACC
                read_miss_dirty <= tag_dirty_out;
                read_miss_valids <= tag_valid_out;
                read_fsm <= MISS1;

            end
            else begin
                read_fsm <= IDLE_COMPARE;
            end
        end
        MISS1: begin
            read_miss_victim_way <= plru_v_way;
            read_fsm <= MISS2;
        end
        MISS2: begin
            
            if(read_miss_valids[read_miss_victim_way] && read_miss_dirty[read_miss_victim_way]) begin
                read_fsm <= WRITE_BACK;

            end
            else begin
                read_fsm <= MEM_ACC;
            end
        end
        WRITE_BACK: begin
            if(!mem_we) begin
                mem_we <= 1'b1;
                mem_addr_write <= {read_miss_tags[read_miss_victim_way],read_miss_address[11:6],6'b0};
                mem_data_write <= read_miss_data[read_miss_victim_way];
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
                m
            end
        end
    end
end















                    

                    
                











endmodule