`include "mycpu.h"

module exe_stage(
    input                          clk           ,
    input                          reset         ,
    //allowin
    input                          ms_allowin    ,
    output                         es_allowin    ,
    //from ds
    input                          ds_to_es_valid,
    input  [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus  ,
    //to ms
    output                         es_to_ms_valid,
    output [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus  ,
    //to id
    output [`ES_TO_DS_BUS_WD -1:0] es_to_ds_bus  ,

    //exception bus
    input  [`MS_TO_ES_EXBUS_WD -1:0] ms_to_es_exbus,
    input  [`WS_TO_ES_EXBUS_WD -1:0] ws_to_es_exbus,
    // data sram interface
    output                        data_sram_req,
    output                        data_sram_wr,
    output [ 1:0]                 data_sram_size,
    output [ 3:0]                 data_sram_wstrb,
    output [31:0]                 data_sram_addr,
    output [31:0]                 data_sram_wdata,
    input                         data_sram_addr_ok
);

reg [31:0]  HI;
reg [31:0]  LO;

reg         es_valid      ;
wire        es_ready_go   ;

reg  [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus_r;
wire        dram_req_succ        ;
wire        es_detect_overflow  ;
wire        es_bd               ;
wire        es_eret_flush       ;
wire [ 7:0] es_cp0_addr         ;
wire        es_dst_is_cp0       ;
wire        es_src_is_cp0       ;
wire        ds_except           ;
wire [ 4:0] ds_exccode          ;
wire [15:0] es_alu_op           ;
wire [6:0]  es_load_op          ;
wire [4:0]  es_store_op         ;
wire        es_dst_is_hi        ;
wire        es_dst_is_lo        ;
wire        es_src_is_hi        ;
wire        es_src_is_lo        ;
wire        es_src1_is_sa       ;
wire        es_src1_is_pc       ;
wire        es_src2_is_imm_sign ;
wire        es_src2_is_imm_zero ;
wire        es_src2_is_8        ;
wire        es_gr_we            ;
wire        es_mem_we           ;
wire [ 4:0] es_dest             ;
wire [15:0] es_imm              ;
wire [31:0] es_rs_value         ;
wire [31:0] es_rt_value         ;
wire [31:0] es_pc               ;

assign {es_detect_overflow  ,  //174:174
        es_bd               ,  //173:173
        es_eret_flush       ,  //172:172
        es_cp0_addr         ,  //171:164
        es_dst_is_cp0       ,  //163:163
        es_src_is_cp0       ,  //162:162
        ds_except           ,  //161:161
        ds_exccode          ,  //160:156
        es_alu_op           ,  //155:140
        es_store_op         ,  //139:135
        es_load_op          ,  //134:128
        es_dst_is_hi        ,  //127:127
        es_dst_is_lo        ,  //126:126
        es_src_is_hi        ,  //125:125
        es_src_is_lo        ,  //124:124
        es_src1_is_sa       ,  //123:123
        es_src1_is_pc       ,  //122:122
        es_src2_is_imm_sign ,  //121:121
        es_src2_is_imm_zero ,  //120:120
        es_src2_is_8        ,  //119:119
        es_gr_we            ,  //118:118
        es_mem_we           ,  //117:117
        es_dest             ,  //116:112
        es_imm              ,  //111:96
        es_rs_value         ,  //95 :64
        es_rt_value         ,  //63 :32
        es_pc                  //31 :0
       } = ds_to_es_bus_r;

wire        es_inst_lb;
wire        es_inst_lbu;
wire        es_inst_lh;
wire        es_inst_lhu;
wire        es_inst_lw;
wire        es_inst_lwl;
wire        es_inst_lwr;
wire        es_inst_sb;
wire        es_inst_sh;
wire        es_inst_sw;
wire        es_inst_swl;
wire        es_inst_swr;
wire [31:0] store_data;
wire [31:0] store_swl;
wire [31:0] store_swr;
wire [ 3:0] store_strb;
wire [ 1:0] to_dram_size;
wire [ 1:0] to_dram_addr_low;

assign {es_inst_sb, es_inst_sh, es_inst_sw, es_inst_swl, es_inst_swr} = es_store_op;
assign {es_inst_lb, es_inst_lbu, es_inst_lh, es_inst_lhu, es_inst_lw, es_inst_lwl, es_inst_lwr} = es_load_op;

wire        es_except;
wire [ 4:0] es_exccode;
wire        except;
wire [ 4:0] exccode;

wire        ms_except;
wire        ms_eret_flush;
wire        es_clear_all;
wire        ws_except;
wire        ws_eret_flush;
wire [31:0] es_BadVAddr;

wire        write_en;

assign {ms_except, ms_eret_flush} = ms_to_es_exbus;
assign {es_clear_all, ws_except, ws_eret_flush} = ws_to_es_exbus;

assign es_except  = ds_except || except;
assign es_exccode = (ds_except) ? ds_exccode : exccode;

wire es_AdES;
wire es_AdEL;
wire es_Ov;
assign es_AdES = (es_inst_sw && es_mem_addr_low != 2'b0) ||
                 (es_inst_sh && es_mem_addr_low[0] != 1'b0);
assign es_AdEL = (es_inst_lw  && es_mem_addr_low != 2'b0)    ||
                 (es_inst_lh  && es_mem_addr_low[0] != 1'b0) ||
                 (es_inst_lhu && es_mem_addr_low[0] != 1'b0);
assign es_Ov = es_detect_overflow && es_alu_overflow;

assign except  = es_AdES || es_AdEL || es_Ov;
assign exccode = (es_Ov  ) ? 5'hc: 
                 (es_AdES) ? 5'h5: 
                 (es_AdEL) ? 5'h4: 
                             5'h0;

assign es_BadVAddr = ds_except ? es_pc : es_alu_result;

assign write_en = ~(ms_except | ms_eret_flush | ws_except | ws_eret_flush | (es_except & es_valid));

wire [31:0] es_alu_src1    ;
wire [31:0] es_alu_src2    ;
wire [31:0] es_alu_result  ;
wire        es_alu_overflow;
wire [31:0] es_final_result;

wire        es_res_from_mem;
wire [1:0]  es_mem_addr_low;

assign es_mem_addr_low = es_alu_result[1:0];

assign es_res_from_mem = ~(es_load_op == 7'b0);
assign es_to_ms_bus = {dram_req_succ   ,  //162:162
                       es_BadVAddr    ,  //161:130
                       es_bd          ,  //129:129
                       es_eret_flush  ,  //128:128
                       es_cp0_addr    ,  //127:120
                       es_dst_is_cp0  ,  //119:119
                       es_src_is_cp0  ,  //118:118
                       es_except      ,  //117:117
                       es_exccode     ,  //116:112
                       es_rt_value    ,  //111:80
                       es_mem_addr_low,  //79 :78
                       es_load_op     ,  //77 :71
                       es_res_from_mem,  //70 :70
                       es_gr_we       ,  //69 :69
                       es_dest        ,  //68 :64
                       es_final_result,  //63 :32
                       es_pc             //31 :0
                      };

//relavant
assign es_to_ds_bus = {es_src_is_cp0, es_res_from_mem, es_valid, es_gr_we, es_dest, es_final_result};

assign es_ready_go    = (divider_readygo && dram_ready_go) || es_clear_all;
assign es_allowin     = !es_valid || es_ready_go && ms_allowin;
assign es_to_ms_valid = es_valid && es_ready_go;
always @(posedge clk) begin
    if (reset) begin
        es_valid <= 1'b0;
    end
    else if (es_clear_all) begin
        es_valid <= 1'b0;
    end
    else if (es_allowin) begin
        es_valid <= ds_to_es_valid;
    end

    if (ds_to_es_valid && es_allowin) begin
        ds_to_es_bus_r <= ds_to_es_bus;
    end
end

assign es_alu_src1 = es_src1_is_sa  ? {27'b0, es_imm[10:6]} : 
                     es_src1_is_pc  ? es_pc[31:0] :
                                      es_rs_value;
assign es_alu_src2 = es_src2_is_imm_sign ? {{16{es_imm[15]}}, es_imm[15:0]} :
                     es_src2_is_imm_zero ? {16'b0, es_imm[15:0]} :
                     es_src2_is_8        ? 32'd8 :
                                           es_rt_value;

assign es_final_result = es_src_is_hi  ? HI :
                         es_src_is_lo  ? LO :
                         es_dst_is_cp0 ? es_rt_value :
                                         es_alu_result;

alu u_alu(
    .alu_op      (es_alu_op[11:0] ),
    .alu_src1    (es_alu_src1     ),
    .alu_src2    (es_alu_src2     ),
    .alu_result  (es_alu_result   ),
    .alu_overflow(es_alu_overflow )
);

//multiplier
wire  [63:0] mult_result;
multiplier u_multiplier(
    .mul_op      (es_alu_op[13:12] ),
    .mul_src1    (es_alu_src1      ),
    .mul_src2    (es_alu_src2      ),
    .mul_result  (mult_result      )
);

//divider
reg          already_input;
wire         divider_readygo;

wire         dividend_tvalid1;
wire         dividend_tready1;
wire         divisor_tvalid1;
wire         divisor_tready1;
wire         dout_tvalid1;
wire [63:0]  dout_tdata1;

wire         dividend_tvalid2;
wire         dividend_tready2;
wire         divisor_tvalid2;
wire         divisor_tready2;
wire         dout_tvalid2;
wire [63:0]  dout_tdata2;

assign divider_readygo = !(es_valid && es_alu_op[14] && ~dout_tvalid1) && !(es_valid && es_alu_op[15] && ~dout_tvalid2);

always @(posedge clk) begin
    if(es_valid && es_alu_op[14]) begin
        if(dividend_tvalid1 && dividend_tready1 && divisor_tvalid1 && divisor_tready1) begin
            already_input <= 1'b1;
        end
        else if(dout_tvalid1) begin
            already_input <= 1'b0;
        end
    end
    else if(es_valid && es_alu_op[15]) begin
        if(dividend_tvalid2 && dividend_tready2 && divisor_tvalid2 && divisor_tready2) begin
            already_input <= 1'b1;
        end
        else if(dout_tvalid2) begin
            already_input <= 1'b0;
        end  
    end
    else begin
        already_input <= 1'b0;
    end
end

assign dividend_tvalid1 = es_valid && es_alu_op[14] && ~already_input;
assign divisor_tvalid1  = es_valid && es_alu_op[14] && ~already_input;
assign dividend_tvalid2 = es_valid && es_alu_op[15] && ~already_input;
assign divisor_tvalid2  = es_valid && es_alu_op[15] && ~already_input;

divider_signed u_divider_signed(
    .aclk                   (clk              ),
    .s_axis_dividend_tdata  (es_alu_src1      ),
    .s_axis_dividend_tvalid (dividend_tvalid1 ),
    .s_axis_dividend_tready (dividend_tready1 ),
    .s_axis_divisor_tdata   (es_alu_src2      ),
    .s_axis_divisor_tvalid  (divisor_tvalid1  ),
    .s_axis_divisor_tready  (divisor_tready1  ),
    .m_axis_dout_tdata      (dout_tdata1      ),
    .m_axis_dout_tvalid     (dout_tvalid1     )
);

divider_unsigned u_divider_unsigned(
    .aclk                   (clk              ),
    .s_axis_dividend_tdata  (es_alu_src1      ),
    .s_axis_dividend_tvalid (dividend_tvalid2 ),
    .s_axis_dividend_tready (dividend_tready2 ),
    .s_axis_divisor_tdata   (es_alu_src2      ),
    .s_axis_divisor_tvalid  (divisor_tvalid2  ),
    .s_axis_divisor_tready  (divisor_tready2  ),
    .m_axis_dout_tdata      (dout_tdata2      ),
    .m_axis_dout_tvalid     (dout_tvalid2     )
);

//HI LO reg
always @(posedge clk) begin
    if(es_valid && (es_alu_op[12] || es_alu_op[13]) && write_en) begin
        HI <= mult_result[63:32];
    end
    else if(es_valid && es_alu_op[14] && dout_tvalid1 && write_en) begin
        HI <= dout_tdata1[31: 0];
    end
    else if(es_valid && es_alu_op[15] && dout_tvalid2 && write_en) begin
        HI <= dout_tdata2[31: 0];
    end
    else if(es_valid && es_dst_is_hi && write_en) begin
        HI <= es_rs_value;
    end
end

always @(posedge clk) begin
    if(es_valid && (es_alu_op[12] || es_alu_op[13]) && write_en) begin
        LO <= mult_result[31: 0];
    end
    else if(es_valid && es_alu_op[14] && dout_tvalid1 && write_en) begin
        LO <= dout_tdata1[63:32];
    end
    else if(es_valid && es_alu_op[15] && dout_tvalid2 && write_en) begin
        LO <= dout_tdata2[63:32];
    end
    else if(es_valid && es_dst_is_lo && write_en) begin
        LO <= es_rs_value;
    end
end

//DRAM
reg   dram_req;
wire  dram_ready_go;

always @(posedge clk) begin
    if (reset) begin
        dram_req <= 1'b0;
    end
    else if(dram_req_succ) begin
        dram_req <= 1'b0;
    end
    else if (ms_allowin && es_valid && (es_res_from_mem || es_mem_we) && write_en) begin
        dram_req <= 1'b1;
    end
end

assign dram_req_succ = dram_req && data_sram_addr_ok;
assign data_sram_req = dram_req;
assign dram_ready_go = ~(es_valid && (es_res_from_mem || es_mem_we) && write_en && !dram_req_succ);

assign store_data = {32{es_inst_sb }} & {4{es_rt_value[7:0]}}  | 
                    {32{es_inst_sh }} & {2{es_rt_value[15:0]}} | 
                    {32{es_inst_sw }} & es_rt_value | 
                    {32{es_inst_swl}} & store_swl | 
                    {32{es_inst_swr}} & store_swr;

assign store_swl = {32{es_mem_addr_low==2'b11}} & es_rt_value | 
		           {32{es_mem_addr_low==2'b10}} & { 8'b0,es_rt_value[31: 8]} | 
				   {32{es_mem_addr_low==2'b01}} & {16'b0,es_rt_value[31:16]} | 
				   {32{es_mem_addr_low==2'b00}} & {24'b0,es_rt_value[31:24]};
   
assign store_swr = {32{es_mem_addr_low==2'b11}} & {es_rt_value[ 7:0],24'b0} | 
		           {32{es_mem_addr_low==2'b10}} & {es_rt_value[15:0],16'b0} | 
				   {32{es_mem_addr_low==2'b01}} & {es_rt_value[23:0], 8'b0} | 
				   {32{es_mem_addr_low==2'b00}} & es_rt_value;

assign store_strb = {4{es_inst_sb  && es_mem_addr_low==2'b00}} & 4'b0001 | 
		            {4{es_inst_sb  && es_mem_addr_low==2'b01}} & 4'b0010 | 
					{4{es_inst_sb  && es_mem_addr_low==2'b10}} & 4'b0100 | 
					{4{es_inst_sb  && es_mem_addr_low==2'b11}} & 4'b1000 | 
	                {4{es_inst_sh  && es_mem_addr_low==2'b00}} & 4'b0011 | 
					{4{es_inst_sh  && es_mem_addr_low==2'b10}} & 4'b1100 | 
					{4{es_inst_sw}} & 4'b1111 | 
					{4{es_inst_swl && es_mem_addr_low==2'b11}} & 4'b1111 | 
                    {4{es_inst_swl && es_mem_addr_low==2'b10}} & 4'b0111 | 
					{4{es_inst_swl && es_mem_addr_low==2'b01}} & 4'b0011 | 
					{4{es_inst_swl && es_mem_addr_low==2'b00}} & 4'b0001 | 
					{4{es_inst_swr && es_mem_addr_low==2'b11}} & 4'b1000 | 
					{4{es_inst_swr && es_mem_addr_low==2'b10}} & 4'b1100 | 
					{4{es_inst_swr && es_mem_addr_low==2'b01}} & 4'b1110 | 
					{4{es_inst_swr && es_mem_addr_low==2'b00}} & 4'b1111;

assign to_dram_size =   {2{es_inst_sw || es_inst_lw}} & 2'd2 | 
                        {2{es_inst_lh || es_inst_lhu || es_inst_sh}} & 2'd1 | 
                        {2{es_inst_lb || es_inst_lbu || es_inst_sb}} & 2'd0 | 
                        {2{(es_inst_swl || es_inst_lwl) && es_mem_addr_low==2'b11}} & 2'd2 | 
                        {2{(es_inst_swl || es_inst_lwl) && es_mem_addr_low==2'b10}} & 2'd2 | 
				        {2{(es_inst_swl || es_inst_lwl) && es_mem_addr_low==2'b01}} & 2'd1 | 
				        {2{(es_inst_swl || es_inst_lwl) && es_mem_addr_low==2'b00}} & 2'd0 | 
				        {2{(es_inst_swr || es_inst_lwr) && es_mem_addr_low==2'b11}} & 2'd0 | 
				        {2{(es_inst_swr || es_inst_lwr) && es_mem_addr_low==2'b10}} & 2'd1 | 
				        {2{(es_inst_swr || es_inst_lwr) && es_mem_addr_low==2'b01}} & 2'd2 | 
				        {2{(es_inst_swr || es_inst_lwr) && es_mem_addr_low==2'b00}} & 2'd2;

assign to_dram_addr_low =   {2{es_inst_sw || es_inst_lw}} & 2'b00 | 
                            {2{es_inst_lh || es_inst_lhu || es_inst_sh}} & es_mem_addr_low | 
                            {2{es_inst_lb || es_inst_lbu || es_inst_sb}} & es_mem_addr_low | 
                            {2{es_inst_swl || es_inst_lwl}} & 2'b00 | 
				            {2{es_inst_swr || es_inst_lwr}} & es_mem_addr_low;

assign data_sram_wr = es_mem_we && es_valid;
assign data_sram_size = to_dram_size;
assign data_sram_wstrb = (es_mem_we && es_valid) ? store_strb : 4'b0;
assign data_sram_addr = {es_alu_result[31:2], to_dram_addr_low};
assign data_sram_wdata = store_data;

endmodule