`include "mycpu.h"

module id_stage(
    input                          clk           ,
    input                          reset         ,
    //allowin
    input                          es_allowin    ,
    output                         ds_allowin    ,
    //from fs
    input                          fs_to_ds_valid,
    input  [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus  ,
    //to es
    output                         ds_to_es_valid,
    output [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus  ,
    //to fs
    output [`BR_BUS_WD       -1:0] br_bus        ,
    //to rf: for write back
    input  [`WS_TO_RF_BUS_WD -1:0] ws_to_rf_bus  ,
    //relevant bus
    input  [`ES_TO_DS_BUS_WD -1:0] es_to_ds_bus  ,
    input  [`MS_TO_DS_BUS_WD -1:0] ms_to_ds_bus  ,
    input  [`WS_TO_DS_BUS_WD -1:0] ws_to_ds_bus  ,
    //exception bus
    input  [`WS_TO_DS_EXBUS_WD -1:0] ws_to_ds_exbus
);

reg         ds_valid   ;
wire        ds_ready_go;

reg  [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus_r;

wire        fs_refill;
wire [31:0] ds_nextpc;
wire        ds_bd;
wire        fs_except;
wire [ 4:0] fs_exccode;
wire [31:0] ds_inst;
wire [31:0] ds_pc  ;
wire [31:0] bd_pc  ;
assign {fs_refill,  //103:103
        ds_nextpc,  //102:71
        ds_bd,      // 70:70
        fs_except,  // 69:69
        fs_exccode, // 68:64
        ds_inst,    // 63:32
        ds_pc       // 31:0
        } = fs_to_ds_bus_r;
assign bd_pc = ds_pc + 32'd4;

wire        rf_we   ;
wire [ 4:0] rf_waddr;
wire [31:0] rf_wdata;
assign {rf_we   ,  //37:37
        rf_waddr,  //36:32
        rf_wdata   //31:0
       } = ws_to_rf_bus;

wire        br;
wire        br_stall;
wire        br_taken;
wire        br_leave;
wire [31:0] br_target;
assign br_bus = {br, br_leave, br_stall, br_taken, br_target};

wire        detect_overflow;
wire [15:0] alu_op;
wire [6:0]  load_op;
wire [4:0]  store_op;
wire        dst_is_hi;
wire        dst_is_lo;
wire        dst_is_r31;
wire        dst_is_rt;
wire        dst_is_cp0;
wire        src_is_cp0;
wire        src_is_hi;
wire        src_is_lo;
wire        src1_is_sa;
wire        src1_is_pc;
wire        src2_is_imm_sign;
wire        src2_is_imm_zero;
wire        src2_is_8;
wire        res_from_mem;
wire        gr_we;
wire        mem_we;
wire [ 4:0] dest;
wire [15:0] imm;
wire [31:0] rs_value;
wire [31:0] rt_value;
wire        eret_flush;
wire [ 7:0] cp0_addr;

wire        es_mfc0;
wire        es_load;
wire        es_valid;
wire        es_gr_we;
wire [4:0]  es_dest;
wire [31:0] es_result;
wire        ms_res_valid;
wire        ms_mfc0;
wire        ms_load;
wire        ms_valid;
wire        ms_gr_we;
wire [4:0]  ms_dest;
wire [31:0] ms_result;
wire        ws_valid;
wire        ws_gr_we;
wire [4:0]  ws_dest;
wire [31:0] ws_result;

wire es_r1_relevant;
wire ms_r1_relevant;
wire ws_r1_relevant;
wire es_r2_relevant;
wire ms_r2_relevant;
wire ws_r2_relevant;
wire es_r1_block;
wire es_r2_block;
wire ms_r1_block;
wire ms_r2_block;
wire r1_need;
wire r2_need;

wire [ 5:0] op;
wire [ 4:0] rs;
wire [ 4:0] rt;
wire [ 4:0] rd;
wire [ 4:0] sa;
wire [ 5:0] func;
wire [25:0] jidx;
wire [63:0] op_d;
wire [31:0] rs_d;
wire [31:0] rt_d;
wire [31:0] rd_d;
wire [31:0] sa_d;
wire [63:0] func_d;

wire        inst_add;
wire        inst_addi;
wire        inst_addu;
wire        inst_addiu;
wire        inst_sub;
wire        inst_subu;
wire        inst_slti;
wire        inst_sltiu;
wire        inst_slt;
wire        inst_sltu;
wire        inst_and;
wire        inst_andi;
wire        inst_or;
wire        inst_ori;
wire        inst_xor;
wire        inst_xori;
wire        inst_nor;
wire        inst_sll;
wire        inst_sllv;
wire        inst_srl;
wire        inst_srlv;
wire        inst_sra;
wire        inst_srav;
wire        inst_mult;
wire        inst_multu;
wire        inst_div;
wire        inst_divu;
wire        inst_mfhi;
wire        inst_mflo;
wire        inst_mthi;
wire        inst_mtlo;
wire        inst_lui;
wire        inst_lw;
wire        inst_lwl;
wire        inst_lwr;
wire        inst_lb;
wire        inst_lbu;
wire        inst_lh;
wire        inst_lhu;
wire        inst_sw;
wire        inst_sb;
wire        inst_sh;
wire        inst_swl;
wire        inst_swr;
wire        inst_beq;
wire        inst_bne;
wire        inst_bgez;
wire        inst_bgtz;
wire        inst_blez;
wire        inst_bltz;
wire        inst_j;
wire        inst_bltzal;
wire        inst_bgezal; 
wire        inst_jalr;
wire        inst_jal;
wire        inst_jr;
wire        inst_mfc0;
wire        inst_mtc0;
wire        inst_eret;
wire        inst_syscall;
wire        inst_break;
wire        inst_tlbp;
wire        inst_tlbr;
wire        inst_tlbwi;

wire        ds_except;
wire [ 4:0] ds_exccode;
wire        except;
wire [ 4:0] exccode;
wire        ds_clear_all;
wire        ds_has_int;

wire [ 4:0] rf_raddr1;
wire [31:0] rf_rdata1;
wire [ 4:0] rf_raddr2;
wire [31:0] rf_rdata2;

wire        rs_eq_rt;
wire        rs_ge_z;
wire        rs_gt_z;

assign ds_to_es_bus = {fs_refill        ,  //210:210
                       ds_nextpc        ,  //209:178
                       inst_tlbp        ,  //177:177
                       inst_tlbr        ,  //176:176
                       inst_tlbwi       ,  //175:175
                       detect_overflow  ,  //174:174
                       ds_bd            ,  //173:173
                       eret_flush       ,  //172:172
                       cp0_addr         ,  //171:164
                       dst_is_cp0       ,  //163:163
                       src_is_cp0       ,  //162:162
                       ds_except        ,  //161:161
                       ds_exccode       ,  //160:156
                       alu_op           ,  //155:140
                       store_op         ,  //139:135
                       load_op          ,  //134:128
                       dst_is_hi        ,  //127:127
                       dst_is_lo        ,  //126:126
                       src_is_hi        ,  //125:125
                       src_is_lo        ,  //124:124
                       src1_is_sa       ,  //123:123
                       src1_is_pc       ,  //122:122
                       src2_is_imm_sign ,  //121:121
                       src2_is_imm_zero ,  //120:120
                       src2_is_8        ,  //119:119
                       gr_we            ,  //118:118
                       mem_we           ,  //117:117
                       dest             ,  //116:112
                       imm              ,  //111:96
                       rs_value         ,  //95 :64
                       rt_value         ,  //63 :32
                       ds_pc               //31 :0
                      };

assign ds_ready_go    = (!es_r1_block && !es_r2_block && !ms_r1_block && !ms_r2_block) || ds_clear_all;
assign ds_allowin     = !ds_valid || ds_ready_go && es_allowin;
assign ds_to_es_valid = ds_valid && ds_ready_go;
always @(posedge clk) begin
    if (reset) begin
        ds_valid <= 1'b0;
    end
    else if (ds_clear_all) begin
        ds_valid <= 1'b0;
    end
    else if (ds_allowin) begin
        ds_valid <= fs_to_ds_valid;
    end

    if (fs_to_ds_valid && ds_allowin) begin
        fs_to_ds_bus_r <= fs_to_ds_bus;
    end
end

assign op   = ds_inst[31:26];
assign rs   = ds_inst[25:21];
assign rt   = ds_inst[20:16];
assign rd   = ds_inst[15:11];
assign sa   = ds_inst[10: 6];
assign func = ds_inst[ 5: 0];
assign imm  = ds_inst[15: 0];
assign jidx = ds_inst[25: 0];

decoder_6_64 u_dec0(.in(op  ), .out(op_d  ));
decoder_6_64 u_dec1(.in(func), .out(func_d));
decoder_5_32 u_dec2(.in(rs  ), .out(rs_d  ));
decoder_5_32 u_dec3(.in(rt  ), .out(rt_d  ));
decoder_5_32 u_dec4(.in(rd  ), .out(rd_d  ));
decoder_5_32 u_dec5(.in(sa  ), .out(sa_d  ));

assign inst_add    = op_d[6'h00] & func_d[6'h20] & sa_d[5'h00];
assign inst_addu   = op_d[6'h00] & func_d[6'h21] & sa_d[5'h00];
assign inst_addi   = op_d[6'h08];
assign inst_addiu  = op_d[6'h09];
assign inst_sub    = op_d[6'h00] & func_d[6'h22] & sa_d[5'h00];
assign inst_subu   = op_d[6'h00] & func_d[6'h23] & sa_d[5'h00];
assign inst_slt    = op_d[6'h00] & func_d[6'h2a] & sa_d[5'h00];
assign inst_sltu   = op_d[6'h00] & func_d[6'h2b] & sa_d[5'h00];
assign inst_slti   = op_d[6'h0a];
assign inst_sltiu  = op_d[6'h0b];

assign inst_and    = op_d[6'h00] & func_d[6'h24] & sa_d[5'h00];
assign inst_andi   = op_d[6'h0c];
assign inst_or     = op_d[6'h00] & func_d[6'h25] & sa_d[5'h00];
assign inst_ori    = op_d[6'h0d];
assign inst_xor    = op_d[6'h00] & func_d[6'h26] & sa_d[5'h00];
assign inst_xori   = op_d[6'h0e];
assign inst_nor    = op_d[6'h00] & func_d[6'h27] & sa_d[5'h00];

assign inst_sll    = op_d[6'h00] & func_d[6'h00] & rs_d[5'h00];
assign inst_sllv   = op_d[6'h00] & func_d[6'h04] & sa_d[5'h00];
assign inst_srl    = op_d[6'h00] & func_d[6'h02] & rs_d[5'h00];
assign inst_srlv   = op_d[6'h00] & func_d[6'h06] & sa_d[5'h00];
assign inst_sra    = op_d[6'h00] & func_d[6'h03] & rs_d[5'h00];
assign inst_srav   = op_d[6'h00] & func_d[6'h07] & sa_d[5'h00];

assign inst_mult   = op_d[6'h00] & func_d[6'h18] & rd_d[5'h00] & sa_d[5'h00];
assign inst_multu  = op_d[6'h00] & func_d[6'h19] & rd_d[5'h00] & sa_d[5'h00];
assign inst_div    = op_d[6'h00] & func_d[6'h1a] & rd_d[5'h00] & sa_d[5'h00];
assign inst_divu   = op_d[6'h00] & func_d[6'h1b] & rd_d[5'h00] & sa_d[5'h00];
assign inst_mfhi   = op_d[6'h00] & func_d[6'h10] & rs_d[5'h00] & rt_d[5'h00] & sa_d[5'h00];
assign inst_mthi   = op_d[6'h00] & func_d[6'h11] & rt_d[5'h00] & rd_d[5'h00] & sa_d[5'h00];
assign inst_mflo   = op_d[6'h00] & func_d[6'h12] & rs_d[5'h00] & rt_d[5'h00] & sa_d[5'h00];
assign inst_mtlo   = op_d[6'h00] & func_d[6'h13] & rt_d[5'h00] & rd_d[5'h00] & sa_d[5'h00];

assign inst_lui    = op_d[6'h0f] & rs_d[5'h00];

assign inst_lb     = op_d[6'h20];
assign inst_lh     = op_d[6'h21];
assign inst_lw     = op_d[6'h23];
assign inst_lbu    = op_d[6'h24];
assign inst_lhu    = op_d[6'h25];
assign inst_lwl    = op_d[6'h22];
assign inst_lwr    = op_d[6'h26];
assign inst_sb     = op_d[6'h28];
assign inst_sh     = op_d[6'h29];
assign inst_sw     = op_d[6'h2b];
assign inst_swl    = op_d[6'h2a];
assign inst_swr    = op_d[6'h2e];

assign inst_beq    = op_d[6'h04];
assign inst_bne    = op_d[6'h05];
assign inst_bgez   = op_d[6'h01] & rt_d[5'h01];
assign inst_bgtz   = op_d[6'h07] & rt_d[5'h00];
assign inst_blez   = op_d[6'h06] & rt_d[5'h00];
assign inst_bltz   = op_d[6'h01] & rt_d[5'h00];
assign inst_j      = op_d[6'h02];
assign inst_bltzal = op_d[6'h01] & rt_d[5'h10];
assign inst_bgezal = op_d[6'h01] & rt_d[5'h11];
assign inst_jalr   = op_d[6'h00] & rt_d[5'h00] & func_d[6'h09] & sa_d[5'h00];
assign inst_jal    = op_d[6'h03];
assign inst_jr     = op_d[6'h00] & func_d[6'h08] & rt_d[5'h00] & rd_d[5'h00] & sa_d[5'h00];

assign inst_mfc0   = op_d[6'h10] & rs_d[5'h00] & sa_d[5'h00] & (ds_inst[5: 3]==3'b0);
assign inst_mtc0   = op_d[6'h10] & rs_d[5'h04] & sa_d[5'h00] & (ds_inst[5: 3]==3'b0);
assign inst_eret   = op_d[6'h10] & rs_d[5'h10] & rt_d[5'h00] & rd_d[5'h00] & sa_d[5'h00] & func_d[6'h18];
assign inst_syscall= op_d[6'h00] & func_d[6'h0c];
assign inst_break  = op_d[6'h00] & func_d[6'h0d];

assign inst_tlbp   = op_d[6'h10] & func_d[6'h08] & rs_d[5'h10] & rt_d[5'h00] & rd_d[5'h00] & sa_d[5'h00];
assign inst_tlbr   = op_d[6'h10] & func_d[6'h01] & rs_d[5'h10] & rt_d[5'h00] & rd_d[5'h00] & sa_d[5'h00];
assign inst_tlbwi  = op_d[6'h10] & func_d[6'h02] & rs_d[5'h10] & rt_d[5'h00] & rd_d[5'h00] & sa_d[5'h00];

assign alu_op[ 0] = inst_add | inst_addi   | inst_addu   | inst_addiu |
                    inst_lw  | inst_lb     | inst_lbu    | inst_lh    | inst_lhu | inst_lwl | inst_lwr | 
                    inst_sw  | inst_sb     | inst_sh     | inst_swl   | inst_swr |
                    inst_jal | inst_bltzal | inst_bgezal | inst_jalr;
assign alu_op[ 1] = inst_sub | inst_subu;
assign alu_op[ 2] = inst_slt | inst_slti;
assign alu_op[ 3] = inst_sltu | inst_sltiu;
assign alu_op[ 4] = inst_and | inst_andi;
assign alu_op[ 5] = inst_nor;
assign alu_op[ 6] = inst_or | inst_ori;
assign alu_op[ 7] = inst_xor | inst_xori;
assign alu_op[ 8] = inst_sll | inst_sllv;
assign alu_op[ 9] = inst_srl | inst_srlv;
assign alu_op[10] = inst_sra | inst_srav;
assign alu_op[11] = inst_lui;
assign alu_op[12] = inst_mult;
assign alu_op[13] = inst_multu;
assign alu_op[14] = inst_div;
assign alu_op[15] = inst_divu;

assign store_op         = {inst_sb, inst_sh, inst_sw, inst_swl, inst_swr};
assign load_op          = {inst_lb, inst_lbu, inst_lh, inst_lhu, inst_lw, inst_lwl, inst_lwr};
assign src1_is_sa       = inst_sll | inst_srl | inst_sra;
assign src1_is_pc       = inst_jal | inst_bltzal | inst_bgezal | inst_jalr;
assign src2_is_imm_sign = inst_addi | inst_addiu | inst_slti | inst_sltiu| inst_lui | 
                          inst_lw   | inst_lb    | inst_lbu  | inst_lh   | inst_lhu | inst_lwl | inst_lwr | 
                          inst_sw   | inst_sb    | inst_sh   | inst_swl  | inst_swr;
assign src2_is_imm_zero = inst_andi | inst_ori | inst_xori;
assign src2_is_8        = inst_jal | inst_bltzal | inst_bgezal | inst_jalr;
assign res_from_mem     = inst_lw | inst_lb | inst_lbu | inst_lh | inst_lhu | inst_lwl | inst_lwr;
assign dst_is_r31       = inst_jal | inst_bltzal | inst_bgezal;
assign dst_is_rt        = inst_addi | inst_addiu | inst_slti | inst_sltiu | inst_andi | inst_ori | inst_xori | inst_lui  |
                          inst_lw   | inst_lb    | inst_lbu  | inst_lh    | inst_lhu  | inst_lwl | inst_lwr  | inst_mfc0;
assign gr_we            = ~inst_sw   & ~inst_sb    & ~inst_sh   & ~inst_swl  & ~inst_swr  & 
                          ~inst_beq  & ~inst_bne   & ~inst_bgez & ~inst_bgtz & ~inst_blez & ~inst_bltz & 
                          ~inst_j    & ~inst_jr    & 
                          ~inst_mult & ~inst_multu & ~inst_div  & ~inst_divu & ~inst_mthi & ~inst_mtlo &
                          ~inst_eret & ~inst_mtc0  & ~inst_syscall &
                          ~inst_tlbp & ~inst_tlbr  & ~inst_tlbwi;
assign mem_we           = inst_sw | inst_sb | inst_sh | inst_swl |inst_swr;
assign dst_is_hi        = inst_mthi;
assign dst_is_lo        = inst_mtlo;
assign src_is_hi        = inst_mfhi;
assign src_is_lo        = inst_mflo;
assign dst_is_cp0       = inst_mtc0;
assign src_is_cp0       = inst_mfc0;
assign eret_flush       = inst_eret;
assign cp0_addr         = {ds_inst[15:11], ds_inst[2:0]};
assign detect_overflow  = inst_add || inst_addi || inst_sub;

assign dest = dst_is_r31 ? 5'd31 :
              dst_is_rt  ? rt    :
                           rd;

assign {ds_clear_all, ds_has_int} = ws_to_ds_exbus;
assign ds_except  = ds_has_int || fs_except || except;
assign ds_exccode = (ds_has_int) ? 5'h0: 
                    (fs_except ) ? fs_exccode: 
                                   exccode;

wire ds_Sys;
wire ds_Bp;
wire ds_RI;
assign ds_Sys = inst_syscall;
assign ds_Bp = inst_break;
assign ds_RI = !inst_add && !inst_addu && !inst_addi && !inst_addiu && !inst_sub && !inst_subu &&
               !inst_slt && !inst_sltu && !inst_slti && !inst_sltiu &&
               !inst_and && !inst_andi && !inst_or && !inst_ori && !inst_xor && !inst_xori && !inst_nor &&
               !inst_sll && !inst_sllv && !inst_srl && !inst_srlv && !inst_sra && !inst_srav &&
               !inst_mult && !inst_multu && !inst_div && !inst_divu && !inst_mfhi && !inst_mthi && !inst_mflo && !inst_mtlo &&
               !inst_lui && !inst_lb && !inst_lh && !inst_lw && !inst_lbu && !inst_lhu && !inst_lwl && !inst_lwr &&
               !inst_sb && !inst_sh && !inst_sw && !inst_swl && !inst_swr &&
               !inst_beq && !inst_bne && !inst_bgez && !inst_bgtz && !inst_blez && !inst_bltz &&
               !inst_j && !inst_bltzal && !inst_bgezal && !inst_jalr && !inst_jal && !inst_jr &&
               !inst_mfc0 && !inst_mtc0 && !inst_eret && !inst_syscall && !inst_break &&
               !inst_tlbp && !inst_tlbr && !inst_tlbwi;

assign except  = ds_Sys || ds_Bp || ds_RI;
assign exccode = (ds_RI) ? 5'ha: 
                 (ds_Sys)? 5'h8: 
                 (ds_Bp) ? 5'h9: 
                           5'h0;

assign rf_raddr1 = rs;
assign rf_raddr2 = rt;
regfile u_regfile(
    .clk    (clk      ),
    .raddr1 (rf_raddr1),
    .rdata1 (rf_rdata1),
    .raddr2 (rf_raddr2),
    .rdata2 (rf_rdata2),
    .we     (rf_we    ),
    .waddr  (rf_waddr ),
    .wdata  (rf_wdata )
    );

assign rs_value = (es_r1_relevant && ~es_r1_block) ? es_result:
                  (ms_r1_relevant && ~ms_r1_block) ? ms_result:
                                  (ws_r1_relevant) ? ws_result:
                                                     rf_rdata1;
assign rt_value = (es_r2_relevant && ~es_r2_block) ? es_result:
                  (ms_r2_relevant && ~ms_r2_block) ? ms_result:
                                  (ws_r2_relevant) ? ws_result:
                                                     rf_rdata2;

assign rs_eq_rt = (rs_value == rt_value);
assign rs_ge_z  = (rs_value[31] == 1'b0);
assign rs_gt_z  = ((rs_value[31] == 1'b0) && (rs_value != 32'b0));
assign br       = ds_valid && (inst_beq || inst_bne || inst_bgez || inst_bgtz || inst_blez || inst_bltz || 
                               inst_bltzal || inst_bgezal || inst_j || inst_jal || inst_jr || inst_jalr);
assign br_taken = (   inst_beq    &&  rs_eq_rt
                   || inst_bne    && !rs_eq_rt
                   || inst_bgez   &&  rs_ge_z
                   || inst_bgtz   &&  rs_gt_z
                   || inst_blez   && !rs_gt_z
                   || inst_bltz   && !rs_ge_z
                   || inst_bltzal && !rs_ge_z
                   || inst_bgezal &&  rs_ge_z
                   || inst_j
                   || inst_jal
                   || inst_jr
                   || inst_jalr
                  ) && ds_valid;
assign br_target = (inst_beq || inst_bne || inst_bgez || inst_bgtz || 
                    inst_blez || inst_bltz || inst_bltzal || inst_bgezal) ? (bd_pc + {{14{imm[15]}}, imm[15:0], 2'b0}) :
                   (inst_jr || inst_jalr)                                 ? rs_value :
                  /*inst_jal || inst_j*/                                    {bd_pc[31:28], jidx[25:0], 2'b0};
assign br_stall = (inst_beq    && (es_r1_block || es_r2_block || ms_r1_block || ms_r2_block) ||
                   inst_bne    && (es_r1_block || es_r2_block || ms_r1_block || ms_r2_block) ||
                   inst_bgez   && (es_r1_block || ms_r1_block) ||
                   inst_bgtz   && (es_r1_block || ms_r1_block) ||
                   inst_blez   && (es_r1_block || ms_r1_block) ||
                   inst_bltz   && (es_r1_block || ms_r1_block) ||
                   inst_bltzal && (es_r1_block || ms_r1_block) ||
                   inst_bgezal && (es_r1_block || ms_r1_block) ||
                   inst_jr     && (es_r1_block || ms_r1_block) ||
                   inst_jalr   && (es_r1_block || ms_r1_block)) && ~ds_clear_all;

assign br_leave = ds_to_es_valid && es_allowin && br;

//relevant & block
assign {es_mfc0, es_load, es_valid, es_gr_we, es_dest, es_result} = es_to_ds_bus;
assign {ms_res_valid, ms_mfc0, ms_load, ms_valid, ms_gr_we, ms_dest, ms_result} = ms_to_ds_bus;
assign {ws_valid, ws_gr_we, ws_dest, ws_result} = ws_to_ds_bus;

assign r1_need = inst_addiu  || inst_addi  || inst_addu || inst_add   || inst_subu || inst_sub  || 
                 inst_and    || inst_andi  || inst_nor  || inst_or    || inst_ori  || inst_xor  || inst_xori || 
                 inst_slt    || inst_sltu  || inst_slti || inst_sltiu || inst_sllv || inst_srav || inst_srlv || 
                 inst_mult   || inst_multu || inst_div  || inst_divu  || inst_mthi || inst_mtlo || 
                 inst_beq    || inst_bne   || inst_bgez || inst_bgtz  || inst_blez || inst_bltz || 
                 inst_bltzal || inst_bgezal|| inst_jr   || inst_jalr || 
                 inst_lw     || inst_lb    || inst_lbu  || inst_lh    || inst_lhu  || inst_lwl  || inst_lwr || 
                 inst_sw     || inst_sb    || inst_sh   || inst_swl   || inst_swr;
assign r2_need = inst_add  || inst_addu  || inst_sub || inst_subu || 
                 inst_and  || inst_nor   || inst_or  || inst_xor  || 
                 inst_slt  || inst_sltu  || inst_sll || inst_sra  || inst_srl || inst_sllv || inst_srav || inst_srlv || 
                 inst_mult || inst_multu || inst_div || inst_divu || 
                 inst_beq  || inst_bne   || inst_lwl || inst_lwr  ||
                 inst_sw   || inst_sb    || inst_sh  || inst_swl  || inst_swr || inst_mtc0;

assign es_r1_relevant = (ds_valid & r1_need) & (es_valid & es_gr_we) & ~rs_d[5'h00] & (rs == es_dest);
assign ms_r1_relevant = (ds_valid & r1_need) & (ms_valid & ms_gr_we) & ~rs_d[5'h00] & (rs == ms_dest);
assign ws_r1_relevant = (ds_valid & r1_need) & (ws_valid & ws_gr_we) & ~rs_d[5'h00] & (rs == ws_dest);

assign es_r2_relevant = (ds_valid & r2_need) & (es_valid & es_gr_we) & ~rt_d[5'h00] & (rt == es_dest);
assign ms_r2_relevant = (ds_valid & r2_need) & (ms_valid & ms_gr_we) & ~rt_d[5'h00] & (rt == ms_dest);
assign ws_r2_relevant = (ds_valid & r2_need) & (ws_valid & ws_gr_we) & ~rt_d[5'h00] & (rt == ws_dest);

assign es_r1_block = es_r1_relevant & (es_load | es_mfc0);
assign es_r2_block = es_r2_relevant & (es_load | es_mfc0);

assign ms_r1_block = ms_r1_relevant & (ms_load & ~ms_res_valid | ms_mfc0);
assign ms_r2_block = ms_r2_relevant & (ms_load & ~ms_res_valid | ms_mfc0);

endmodule