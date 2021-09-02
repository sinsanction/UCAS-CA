`include "mycpu.h"

module wb_stage(
    input                           clk           ,
    input                           reset         ,
    //allowin
    output                          ws_allowin    ,
    //from ms
    input                           ms_to_ws_valid,
    input  [`MS_TO_WS_BUS_WD -1:0]  ms_to_ws_bus  ,
    //to rf: for write back
    output [`WS_TO_RF_BUS_WD -1:0]  ws_to_rf_bus  ,
    //to ID
    output [`WS_TO_DS_BUS_WD -1:0]  ws_to_ds_bus  ,

    //to TLB
    output [`WS_TO_TLB_BUS_WD -1:0] ws_to_tlb_bus ,
    //from TLB
    input  [`TLB_TO_WS_BUS_WD -1:0] tlb_to_ws_bus ,

    //exception bus
    output [`WS_TO_FS_EXBUS_WD -1:0]  ws_to_fs_exbus  ,
    output [`WS_TO_DS_EXBUS_WD -1:0]  ws_to_ds_exbus  ,
    output [`WS_TO_ES_EXBUS_WD -1:0]  ws_to_es_exbus  ,
    output [`WS_TO_MS_EXBUS_WD -1:0]  ws_to_ms_exbus  ,
    //trace debug interface
    output [31:0] debug_wb_pc     ,
    output [ 3:0] debug_wb_rf_wen ,
    output [ 4:0] debug_wb_rf_wnum,
    output [31:0] debug_wb_rf_wdata,
    //hardware interrupt
    input  [ 5:0] ext_int_in
);

reg         ws_valid;
wire        ws_ready_go;

reg [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus_r;
wire        ws_refill;
wire [31:0] ws_nextpc;
wire        ws_tlbp;
wire        ws_tlb_found;
wire [ 3:0] ws_tlb_index;
wire        ws_tlbr;
wire        ws_tlbwi;
wire [31:0] ws_BadVAddr;
wire        ws_bd;
wire        ws_eret_flush;
wire [ 7:0] ws_cp0_addr;
wire        ws_dst_is_cp0;
wire        ws_src_is_cp0;
wire        ws_except;
wire [ 4:0] ws_exccode;
wire        ws_gr_we;
wire [ 4:0] ws_dest;
wire [31:0] ws_final_result;
wire [31:0] ws_pc;
assign {ws_refill      ,  //160:160
        ws_nextpc      ,  //159:128
        ws_tlbp        ,  //127:127
        ws_tlb_found   ,  //126:126
        ws_tlb_index   ,  //125:122
        ws_tlbr        ,  //121:121
        ws_tlbwi       ,  //120:120
        ws_BadVAddr    ,  //119:88
        ws_bd          ,  //87:87
        ws_eret_flush  ,  //86:86
        ws_cp0_addr    ,  //85:78
        ws_dst_is_cp0  ,  //77:77
        ws_src_is_cp0  ,  //76:76
        ws_except      ,  //75:75
        ws_exccode     ,  //74:70
        ws_gr_we       ,  //69:69
        ws_dest        ,  //68:64
        ws_final_result,  //63:32
        ws_pc             //31:0
       } = ms_to_ws_bus_r;

wire        rf_we;
wire [4 :0] rf_waddr;
wire [31:0] rf_wdata;
assign ws_to_rf_bus = {rf_we   ,  //37:37
                       rf_waddr,  //36:32
                       rf_wdata   //31:0
                      };

wire [`CP0_TO_TLB_BUS_WD -1:0] cp0_to_tlb_bus;
wire [`TLB_TO_CP0_BUS_WD -1:0] tlb_to_cp0_bus;
wire        wb_tlbp_en;
wire        wb_tlbr_en;
wire        wb_tlbw_en;
wire        ws_tlbp_block;

assign tlb_to_cp0_bus = tlb_to_ws_bus;
assign ws_to_tlb_bus = {wb_tlbw_en,    //82:82
                        cp0_to_tlb_bus //81:0
                       };
assign ws_tlbp_block = ws_dst_is_cp0 && (ws_cp0_addr==`CP0_ENTRYHI) && ws_valid;

//relavant
assign ws_to_ds_bus = {ws_valid, ws_gr_we, ws_dest, rf_wdata};

assign ws_ready_go = 1'b1;
assign ws_allowin  = !ws_valid || ws_ready_go;
always @(posedge clk) begin
    if (reset) begin
        ws_valid <= 1'b0;
    end
    else if (clear_all) begin
        ws_valid <= 1'b0;
    end
    else if (ws_allowin) begin
        ws_valid <= ms_to_ws_valid;
    end

    if (clear_all) begin
        ms_to_ws_bus_r <= ms_to_ws_bus_r;
    end
    else if (ms_to_ws_valid && ws_allowin) begin
        ms_to_ws_bus_r <= ms_to_ws_bus;
    end
end

assign rf_we    = ws_gr_we && ws_valid && ~ws_except;
assign rf_waddr = ws_dest;
assign rf_wdata = ws_src_is_cp0 ? cp0_result :
                                  ws_final_result;

// debug info generate
assign debug_wb_pc       = ws_pc;
assign debug_wb_rf_wen   = {4{rf_we}};
assign debug_wb_rf_wnum  = ws_dest;
assign debug_wb_rf_wdata = rf_wdata;

//exception & CP0
wire        clear_all;
wire [31:0] clear_entry;

assign clear_all = (ws_eret_flush | ws_except | ws_tlbr | ws_tlbwi) & ws_valid;
assign clear_entry = (ws_eret_flush) ? cp0_epc : 
                     (ws_tlbr || ws_tlbwi) ? ws_nextpc : 
                     (ws_refill) ? 32'hbfc00200 : 32'hbfc00380;

assign ws_to_fs_exbus = {clear_all, clear_entry};
assign ws_to_ds_exbus = {clear_all, has_int};
assign ws_to_es_exbus = {clear_all, wb_except, wb_eret_flush, (wb_tlbr_en | wb_tlbw_en), ws_tlbp_block};
assign ws_to_ms_exbus = {clear_all};

wire        write_BVA;
//output from CP0
wire [31:0] cp0_result; 
wire        has_int;
//input to CP0
wire        wb_bd;
wire        wb_except;
wire        wb_eret_flush;
wire        cp0_wen;
wire [31:0] cp0_epc;
wire [31:0] cp0_wdata;

assign wb_bd         = ws_bd && ws_valid;
assign wb_except     = ws_except && ws_valid;
assign wb_eret_flush = ws_valid && ws_eret_flush && ~ws_except;
assign cp0_wen       = ws_valid && ws_dst_is_cp0 && ~ws_except;
assign cp0_wdata     = ws_final_result;
assign wb_tlbp_en    = ws_tlbp && ws_valid && ~ws_except;
assign wb_tlbr_en    = ws_tlbr && ws_valid && ~ws_except;
assign wb_tlbw_en    = ws_tlbwi && ws_valid && ~ws_except;

CP0 u_CP0(
    .clk            (clk),
    .reset          (reset),
    .wb_bd          (wb_bd),
    .wb_pc          (ws_pc),
    .wb_badvaddr    (ws_BadVAddr),
    .wb_except      (wb_except),
    .wb_exccode     (ws_exccode),
    .eret_flush     (wb_eret_flush),
    .ext_int_in     (ext_int_in),
    .cp0_wen        (cp0_wen),
    .cp0_addr       (ws_cp0_addr),
    .cp0_wdata      (cp0_wdata),
    .cp0_rdata      (cp0_result),
    .cp0_epc        (cp0_epc),
    .has_int        (has_int),
    .tlbp_en        (wb_tlbp_en),
    .tlbp_found     (ws_tlb_found),
    .tlbp_index     (ws_tlb_index),
    .tlbr_en        (wb_tlbr_en),
    .cp0_to_tlb_bus (cp0_to_tlb_bus),
    .tlb_to_cp0_bus (tlb_to_cp0_bus)
);

endmodule