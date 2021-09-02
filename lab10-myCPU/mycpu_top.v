`include "mycpu.h"

module mycpu_top(
    input         clk,
    input         resetn,
    // inst sram interface
    output        inst_sram_req,
    output        inst_sram_wr,
    output [ 1:0] inst_sram_size,
    output [ 3:0] inst_sram_wstrb,
    output [31:0] inst_sram_addr,
    output [31:0] inst_sram_wdata,
    input         inst_sram_addr_ok,
    input         inst_sram_data_ok,
    input  [31:0] inst_sram_rdata,

    // data sram interface
    output        data_sram_req,
    output        data_sram_wr,
    output [ 1:0] data_sram_size,
    output [ 3:0] data_sram_wstrb,
    output [31:0] data_sram_addr,
    output [31:0] data_sram_wdata,
    input         data_sram_addr_ok,
    input         data_sram_data_ok,
    input  [31:0] data_sram_rdata,
    // trace debug interface
    output [31:0] debug_wb_pc,
    output [ 3:0] debug_wb_rf_wen,
    output [ 4:0] debug_wb_rf_wnum,
    output [31:0] debug_wb_rf_wdata
    // hardware interrupt
    //input  [ 5:0] ext_int_in
);

reg         reset;
always @(posedge clk) reset <= ~resetn;

wire         ds_allowin;
wire         es_allowin;
wire         ms_allowin;
wire         ws_allowin;
wire         fs_to_ds_valid;
wire         ds_to_es_valid;
wire         es_to_ms_valid;
wire         ms_to_ws_valid;
wire [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus;
wire [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus;
wire [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus;
wire [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus;
wire [`WS_TO_RF_BUS_WD -1:0] ws_to_rf_bus;
wire [`BR_BUS_WD       -1:0] br_bus;

wire [`ES_TO_DS_BUS_WD -1:0] es_to_ds_bus;
wire [`MS_TO_DS_BUS_WD -1:0] ms_to_ds_bus;
wire [`WS_TO_DS_BUS_WD -1:0] ws_to_ds_bus;

wire [`WS_TO_FS_EXBUS_WD -1:0] ws_to_fs_exbus;
wire [`WS_TO_DS_EXBUS_WD -1:0] ws_to_ds_exbus;
wire [`WS_TO_ES_EXBUS_WD -1:0] ws_to_es_exbus;
wire [`WS_TO_MS_EXBUS_WD -1:0] ws_to_ms_exbus;
wire [`MS_TO_ES_EXBUS_WD -1:0] ms_to_es_exbus;

wire [ 5:0] ext_int_in;
assign ext_int_in = 6'b0;

// IF stage
if_stage if_stage(
    .clk               (clk            ),
    .reset             (reset          ),
    //allowin
    .ds_allowin        (ds_allowin     ),
    //brbus
    .br_bus            (br_bus         ),
    //outputs
    .fs_to_ds_valid    (fs_to_ds_valid ),
    .fs_to_ds_bus      (fs_to_ds_bus   ),
    //exception bus
    .ws_to_fs_exbus    (ws_to_fs_exbus ),
    // inst sram interface
    .inst_sram_req     (inst_sram_req     ),
    .inst_sram_wr      (inst_sram_wr      ),
    .inst_sram_size    (inst_sram_size    ),
    .inst_sram_wstrb   (inst_sram_wstrb   ),
    .inst_sram_addr    (inst_sram_addr    ),
    .inst_sram_wdata   (inst_sram_wdata   ),
    .inst_sram_addr_ok (inst_sram_addr_ok ),
    .inst_sram_data_ok (inst_sram_data_ok ),
    .inst_sram_rdata   (inst_sram_rdata   )
);

// ID stage
id_stage id_stage(
    .clk            (clk            ),
    .reset          (reset          ),
    //allowin
    .es_allowin     (es_allowin     ),
    .ds_allowin     (ds_allowin     ),
    //from fs
    .fs_to_ds_valid (fs_to_ds_valid ),
    .fs_to_ds_bus   (fs_to_ds_bus   ),
    //to es
    .ds_to_es_valid (ds_to_es_valid ),
    .ds_to_es_bus   (ds_to_es_bus   ),
    //to fs
    .br_bus         (br_bus         ),
    //to rf: for write back
    .ws_to_rf_bus   (ws_to_rf_bus   ),
    //relavant bus
    .es_to_ds_bus   (es_to_ds_bus   ),
    .ms_to_ds_bus   (ms_to_ds_bus   ),
    .ws_to_ds_bus   (ws_to_ds_bus   ),
    //exception bus
    .ws_to_ds_exbus (ws_to_ds_exbus )
);

// EXE stage
exe_stage exe_stage(
    .clk             (clk            ),
    .reset           (reset          ),
    //allowin
    .ms_allowin      (ms_allowin     ),
    .es_allowin      (es_allowin     ),
    //from ds
    .ds_to_es_valid  (ds_to_es_valid ),
    .ds_to_es_bus    (ds_to_es_bus   ),
    //to ms
    .es_to_ms_valid  (es_to_ms_valid ),
    .es_to_ms_bus    (es_to_ms_bus   ),
    //to ID
    .es_to_ds_bus    (es_to_ds_bus   ),
    //exception bus
    .ms_to_es_exbus  (ms_to_es_exbus ),
    .ws_to_es_exbus  (ws_to_es_exbus ),
    // data sram interface
    .data_sram_req     (data_sram_req    ),
    .data_sram_wr      (data_sram_wr     ),
    .data_sram_size    (data_sram_size   ),
    .data_sram_wstrb   (data_sram_wstrb  ),
    .data_sram_addr    (data_sram_addr   ),
    .data_sram_wdata   (data_sram_wdata  ),
    .data_sram_addr_ok (data_sram_addr_ok)
);

// MEM stage
mem_stage mem_stage(
    .clk            (clk            ),
    .reset          (reset          ),
    //allowin
    .ws_allowin     (ws_allowin     ),
    .ms_allowin     (ms_allowin     ),
    //from es
    .es_to_ms_valid (es_to_ms_valid ),
    .es_to_ms_bus   (es_to_ms_bus   ),
    //to ws
    .ms_to_ws_valid (ms_to_ws_valid ),
    .ms_to_ws_bus   (ms_to_ws_bus   ),
    //to ID
    .ms_to_ds_bus   (ms_to_ds_bus   ),
    //exception bus
    .ws_to_ms_exbus (ws_to_ms_exbus ),
    .ms_to_es_exbus (ms_to_es_exbus ),
    //from data-sram
    .data_sram_data_ok (data_sram_data_ok),
    .data_sram_rdata   (data_sram_rdata  )
);

// WB stage
wb_stage wb_stage(
    .clk            (clk            ),
    .reset          (reset          ),
    //allowin
    .ws_allowin     (ws_allowin     ),
    //from ms
    .ms_to_ws_valid (ms_to_ws_valid ),
    .ms_to_ws_bus   (ms_to_ws_bus   ),
    //to rf: for write back
    .ws_to_rf_bus   (ws_to_rf_bus   ),
    //to ID
    .ws_to_ds_bus   (ws_to_ds_bus   ),
    //exception bus
    .ws_to_fs_exbus (ws_to_fs_exbus ),
    .ws_to_ds_exbus (ws_to_ds_exbus ),
    .ws_to_es_exbus (ws_to_es_exbus ),
    .ws_to_ms_exbus (ws_to_ms_exbus ),
    //trace debug interface
    .debug_wb_pc      (debug_wb_pc      ),
    .debug_wb_rf_wen  (debug_wb_rf_wen  ),
    .debug_wb_rf_wnum (debug_wb_rf_wnum ),
    .debug_wb_rf_wdata(debug_wb_rf_wdata),
    //hardware interrupt
    .ext_int_in       (ext_int_in)
);

endmodule