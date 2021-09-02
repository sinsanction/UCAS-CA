`include "mycpu.h"

module mem_stage(
    input                          clk           ,
    input                          reset         ,
    //allowin
    input                          ws_allowin    ,
    output                         ms_allowin    ,
    //from es
    input                          es_to_ms_valid,
    input  [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus  ,
    //to ws
    output                         ms_to_ws_valid,
    output [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus  ,
    //to ID
    output [`MS_TO_DS_BUS_WD -1:0] ms_to_ds_bus  ,

    //exception bus
    input  [`WS_TO_MS_EXBUS_WD -1:0] ws_to_ms_exbus,
    output [`MS_TO_ES_EXBUS_WD -1:0] ms_to_es_exbus,
    //from data-sram
    input                         data_sram_data_ok,
    input  [31:0]                 data_sram_rdata
);

reg         ms_valid;
wire        ms_ready_go;

reg [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus_r;
wire        ms_refill;
wire [31:0] ms_nextpc;
wire        ms_tlbp;
wire        ms_tlb_found;
wire [ 3:0] ms_tlb_index;
wire        ms_tlbr;
wire        ms_tlbwi;
wire        ms_wait_dram;
wire [31:0] ms_BadVAddr;
wire        ms_bd;  
wire        ms_eret_flush;
wire [ 7:0] ms_cp0_addr;
wire        ms_dst_is_cp0;
wire        ms_src_is_cp0;
wire        es_except;
wire [ 4:0] es_exccode;
wire [31:0] ms_rt_value;
wire [ 1:0] ms_mem_addr_low;
wire [ 6:0] ms_load_op;
wire        ms_res_from_mem;
wire        ms_gr_we;
wire [ 4:0] ms_dest;
wire [31:0] ms_alu_result;
wire [31:0] ms_pc;
assign {ms_refill      ,  //203:203
        ms_nextpc      ,  //202:171
        ms_tlbp        ,  //170:170
        ms_tlb_found   ,  //169:169
        ms_tlb_index   ,  //168:165
        ms_tlbr        ,  //164:164
        ms_tlbwi       ,  //163:163
        ms_wait_dram   ,  //162:162
        ms_BadVAddr    ,  //161:130
        ms_bd          ,  //129:129
        ms_eret_flush  ,  //128:128
        ms_cp0_addr    ,  //127:120
        ms_dst_is_cp0  ,  //119:119
        ms_src_is_cp0  ,  //118:118
        es_except      ,  //117:117
        es_exccode     ,  //116:112
        ms_rt_value    ,  //111:80
        ms_mem_addr_low,  //79 :78
        ms_load_op     ,  //77 :71
        ms_res_from_mem,  //70 :70
        ms_gr_we       ,  //69 :69
        ms_dest        ,  //68 :64
        ms_alu_result  ,  //63 :32
        ms_pc             //31 :0
       } = es_to_ms_bus_r;

wire ms_inst_lb;
wire ms_inst_lbu;
wire ms_inst_lh;
wire ms_inst_lhu;
wire ms_inst_lw;
wire ms_inst_lwl;
wire ms_inst_lwr;
wire [31:0] load_lwl;
wire [31:0] load_lwr;

assign {ms_inst_lb, ms_inst_lbu, ms_inst_lh, ms_inst_lhu, ms_inst_lw, ms_inst_lwl, ms_inst_lwr} = ms_load_op;

wire [31:0] mem_result;
wire [31:0] mem_final_result;
wire [31:0] ms_final_result;

wire        ms_except;
wire [ 4:0] ms_exccode;
wire        except;
wire [ 4:0] exccode;
wire        ms_clear_all;
wire        ms_tlbp_block;

assign ms_to_ws_bus = {ms_refill      ,  //160:160
                       ms_nextpc      ,  //159:128
                       ms_tlbp        ,  //127:127
                       ms_tlb_found   ,  //126:126
                       ms_tlb_index   ,  //125:122
                       ms_tlbr        ,  //121:121
                       ms_tlbwi       ,  //120:120
                       ms_BadVAddr    ,  //119:88
                       ms_bd          ,  //87:87
                       ms_eret_flush  ,  //86:86
                       ms_cp0_addr    ,  //85:78
                       ms_dst_is_cp0  ,  //77:77
                       ms_src_is_cp0  ,  //76:76
                       ms_except      ,  //75:75
                       ms_exccode     ,  //74:70
                       ms_gr_we       ,  //69:69
                       ms_dest        ,  //68:64
                       ms_final_result,  //63:32
                       ms_pc             //31:0
                      };

assign ms_except  = es_except || except;
assign ms_exccode = (es_except) ? es_exccode : exccode;

assign except  = 1'b0;
assign exccode = 5'h0;

assign ms_tlbp_block = ms_dst_is_cp0 && (ms_cp0_addr==`CP0_ENTRYHI) && ms_valid;
assign ms_to_es_exbus = {(ms_except & ms_valid), (ms_eret_flush & ms_valid), ((ms_tlbr | ms_tlbwi) & ms_valid), ms_tlbp_block};
assign {ms_clear_all} = ws_to_ms_exbus;

//relavant
assign ms_to_ds_bus = {ms_to_ws_valid, ms_src_is_cp0, ms_res_from_mem, ms_valid, ms_gr_we, ms_dest, ms_final_result};

assign ms_ready_go    = dram_ready_go;
assign ms_allowin     = !ms_valid || ms_ready_go && ws_allowin;
assign ms_to_ws_valid = ms_valid && ms_ready_go;
always @(posedge clk) begin
    if (reset) begin
        ms_valid <= 1'b0;
    end
    else if (ms_clear_all) begin
        ms_valid <= 1'b0;
    end
    else if (ms_allowin) begin
        ms_valid <= es_to_ms_valid;
    end

    if (es_to_ms_valid && ms_allowin) begin
        es_to_ms_bus_r <= es_to_ms_bus;
    end
end


//DRAM
wire dram_ready_go;

assign dram_ready_go = ~(ms_valid && ms_wait_dram && !data_sram_data_ok);

assign mem_result = data_sram_rdata;
assign mem_final_result = {32{ms_inst_lb  && ms_mem_addr_low == 2'b00}} & {{24{mem_result[ 7]}}, mem_result[ 7:0]}  | 
                          {32{ms_inst_lb  && ms_mem_addr_low == 2'b01}} & {{24{mem_result[15]}}, mem_result[15:8]}  | 
                          {32{ms_inst_lb  && ms_mem_addr_low == 2'b10}} & {{24{mem_result[23]}}, mem_result[23:16]} | 
                          {32{ms_inst_lb  && ms_mem_addr_low == 2'b11}} & {{24{mem_result[31]}}, mem_result[31:24]} | 
                          {32{ms_inst_lbu && ms_mem_addr_low == 2'b00}} & {24'b0, mem_result[ 7:0]}  | 
                          {32{ms_inst_lbu && ms_mem_addr_low == 2'b01}} & {24'b0, mem_result[15:8]}  | 
                          {32{ms_inst_lbu && ms_mem_addr_low == 2'b10}} & {24'b0, mem_result[23:16]} | 
                          {32{ms_inst_lbu && ms_mem_addr_low == 2'b11}} & {24'b0, mem_result[31:24]} | 
                          {32{ms_inst_lh  && ms_mem_addr_low == 2'b00}} & {{16{mem_result[15]}}, mem_result[15: 0]} | 
                          {32{ms_inst_lh  && ms_mem_addr_low == 2'b10}} & {{16{mem_result[31]}}, mem_result[31:16]} | 
                          {32{ms_inst_lhu && ms_mem_addr_low == 2'b00}} & {16'b0, mem_result[15: 0]} | 
                          {32{ms_inst_lhu && ms_mem_addr_low == 2'b10}} & {16'b0, mem_result[31:16]} | 
                          {32{ms_inst_lw }} & mem_result | 
                          {32{ms_inst_lwl}} & load_lwl   | 
					      {32{ms_inst_lwr}} & load_lwr;

assign load_lwl = {32{ms_mem_addr_low==2'b11}} & mem_result | 
		          {32{ms_mem_addr_low==2'b10}} & {mem_result[23:0],ms_rt_value[ 7:0]} | 
				  {32{ms_mem_addr_low==2'b01}} & {mem_result[15:0],ms_rt_value[15:0]} | 
				  {32{ms_mem_addr_low==2'b00}} & {mem_result[ 7:0],ms_rt_value[23:0]};

assign load_lwr = {32{ms_mem_addr_low==2'b11}} & {ms_rt_value[31: 8],mem_result[31:24]} | 
		          {32{ms_mem_addr_low==2'b10}} & {ms_rt_value[31:16],mem_result[31:16]} | 
				  {32{ms_mem_addr_low==2'b01}} & {ms_rt_value[31:24],mem_result[31: 8]} | 
				  {32{ms_mem_addr_low==2'b00}} & mem_result;

assign ms_final_result = ms_res_from_mem ? mem_final_result
                                         : ms_alu_result;
                                
endmodule