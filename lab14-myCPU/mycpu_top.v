`include "mycpu.h"

module mycpu_top(
    // hardware interrupt
    input  [ 5:0] int,

    input         aclk,
    input         aresetn,

    // read request
    output [ 3:0] arid,
    output [31:0] araddr,
    output [ 7:0] arlen,
    output [ 2:0] arsize,
    output [ 1:0] arburst,
    output [ 1:0] arlock,
    output [ 3:0] arcache,
    output [ 2:0] arprot,
    output        arvalid,
    input         arready,
    // read response
    input  [ 3:0] rid,
    input  [31:0] rdata,
    input  [ 1:0] rresp,
    input         rlast,
    input         rvalid,
    output        rready,
    // write request
    output [ 3:0] awid,
    output [31:0] awaddr,
    output [ 7:0] awlen,
    output [ 2:0] awsize,
    output [ 1:0] awburst,
    output [ 1:0] awlock,
    output [ 3:0] awcache,
    output [ 2:0] awprot,
    output        awvalid,
    input         awready,
    // write data
    output [ 3:0] wid,
    output [31:0] wdata,
    output [ 3:0] wstrb,
    output        wlast,
    output        wvalid,
    input         wready,
    // write response
    input  [ 3:0] bid,
    input  [ 1:0] bresp,
    input         bvalid,
    output        bready,

    // trace debug interface
    output [31:0] debug_wb_pc,
    output [ 3:0] debug_wb_rf_wen,
    output [ 4:0] debug_wb_rf_wnum,
    output [31:0] debug_wb_rf_wdata
);

reg         reset;
always @(posedge aclk) reset <= ~aresetn;

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

wire        inst_sram_req;
wire        inst_sram_wr;
wire [ 1:0] inst_sram_size;
wire [ 3:0] inst_sram_wstrb;
wire [31:0] inst_sram_addr;
wire [31:0] inst_sram_wdata;
wire        inst_sram_addr_ok;
wire        inst_sram_data_ok;
wire [31:0] inst_sram_rdata;

wire        data_sram_req;
wire        data_sram_wr;
wire [ 1:0] data_sram_size;
wire [ 3:0] data_sram_wstrb;
wire [31:0] data_sram_addr;
wire [31:0] data_sram_wdata;
wire        data_sram_addr_ok;
wire        data_sram_data_ok;
wire [31:0] data_sram_rdata;

// TLB
wire [`FS_TO_TLB_BUS_WD -1:0] fs_to_tlb_bus;
wire [`TLB_TO_FS_BUS_WD -1:0] tlb_to_fs_bus;
wire [18:0] s0_vpn2;
wire        s0_odd_page;
wire [ 7:0] s0_asid;
wire        s0_found;
wire [ 3:0] s0_index;
wire [19:0] s0_pfn;
wire [ 2:0] s0_c;
wire        s0_d;
wire        s0_v;

wire [`ES_TO_TLB_BUS_WD -1:0] es_to_tlb_bus;
wire [`TLB_TO_ES_BUS_WD -1:0] tlb_to_es_bus;
wire [18:0] s1_vpn2;
wire        s1_odd_page;
wire [ 7:0] s1_asid;
wire        s1_found;
wire [ 3:0] s1_index;
wire [19:0] s1_pfn;
wire [ 2:0] s1_c;
wire        s1_d;
wire        s1_v;

wire [`WS_TO_TLB_BUS_WD -1:0] ws_to_tlb_bus;
wire [`TLB_TO_WS_BUS_WD -1:0] tlb_to_ws_bus;
wire        we;
wire [ 3:0] w_index;
wire [18:0] w_vpn2;
wire [ 7:0] w_asid;
wire        w_g;
wire [19:0] w_pfn0;
wire [ 2:0] w_c0;
wire        w_d0;
wire        w_v0;
wire [19:0] w_pfn1;
wire [ 2:0] w_c1;
wire        w_d1;
wire        w_v1;

wire [ 3:0] r_index;
wire [18:0] r_vpn2;
wire [ 7:0] r_asid;
wire        r_g;
wire [19:0] r_pfn0;
wire [ 2:0] r_c0;
wire        r_d0;
wire        r_v0;
wire [19:0] r_pfn1;
wire [ 2:0] r_c1;
wire        r_d1;
wire        r_v1;

wire [18:0] es_vpn2;
wire        es_switch;

assign tlb_to_fs_bus = {s0_found, //29:29
                        s0_index, //28:25
                        s0_pfn  , //24:5
                        s0_c    , // 4:2
                        s0_d    , // 1:1
                        s0_v      // 0:0
                       };
assign {s0_vpn2     , //19:1
        s0_odd_page   // 0:0
       } = fs_to_tlb_bus;

assign tlb_to_es_bus = {s1_found, //29:29
                        s1_index, //28:25
                        s1_pfn  , //24:5
                        s1_c    , // 4:2
                        s1_d    , // 1:1
                        s1_v      // 0:0
                       };
assign {es_vpn2     , //20:2
        s1_odd_page , // 1:1
        es_switch     // 0:0
       } = es_to_tlb_bus;

assign tlb_to_ws_bus = {r_vpn2, //77:59
                        r_asid, //58:51
                        r_g,    //50:50
                        r_pfn0, //49:30
                        r_c0,   //29:27
                        r_d0,   //26:26
                        r_v0,   //25:25
                        r_pfn1, //24:5
                        r_c1,   // 4:2
                        r_d1,   // 1:1
                        r_v1    // 0:0
                       };
assign {we,     //82:82
        w_index,//81:78
        w_vpn2, //77:59
        w_asid, //58:51
        w_g,    //50:50
        w_pfn0, //49:30
        w_c0,   //29:27
        w_d0,   //26:26
        w_v0,   //25:25
        w_pfn1, //24:5
        w_c1,   // 4:2
        w_d1,   // 1:1
        w_v1    // 0:0
       } = ws_to_tlb_bus;
assign r_index = w_index;
assign s0_asid = w_asid;
assign s1_asid = w_asid;
assign s1_vpn2 = (es_switch) ? w_vpn2 : es_vpn2;

tlb #(.TLBNUM(16)) tlb(
    .clk          (aclk        ),
    .s0_vpn2      (s0_vpn2     ),
    .s0_odd_page  (s0_odd_page ),
    .s0_asid      (s0_asid     ),
    .s0_found     (s0_found    ),
    .s0_index     (s0_index    ),
    .s0_pfn       (s0_pfn      ),
    .s0_c         (s0_c        ),
    .s0_d         (s0_d        ),
    .s0_v         (s0_v        ),
    .s1_vpn2      (s1_vpn2     ),
    .s1_odd_page  (s1_odd_page ),
    .s1_asid      (s1_asid     ),
    .s1_found     (s1_found    ),
    .s1_index     (s1_index    ),
    .s1_pfn       (s1_pfn      ),
    .s1_c         (s1_c        ),
    .s1_d         (s1_d        ),
    .s1_v         (s1_v        ),
    .we           (we          ),
    .w_index      (w_index     ),
    .w_vpn2       (w_vpn2      ),
    .w_asid       (w_asid      ),
    .w_g          (w_g         ),
    .w_pfn0       (w_pfn0      ),
    .w_c0         (w_c0        ),
    .w_d0         (w_d0        ),
    .w_v0         (w_v0        ),
    .w_pfn1       (w_pfn1      ),
    .w_c1         (w_c1        ),
    .w_d1         (w_d1        ),
    .w_v1         (w_v1        ),
    .r_index      (r_index     ),
    .r_vpn2       (r_vpn2      ),
    .r_asid       (r_asid      ),
    .r_g          (r_g         ),
    .r_pfn0       (r_pfn0      ),
    .r_c0         (r_c0        ),
    .r_d0         (r_d0        ),
    .r_v0         (r_v0        ),
    .r_pfn1       (r_pfn1      ),
    .r_c1         (r_c1        ),
    .r_d1         (r_d1        ),
    .r_v1         (r_v1        )
);

// IF stage
if_stage if_stage(
    .clk               (aclk           ),
    .reset             (reset          ),
    //allowin
    .ds_allowin        (ds_allowin     ),
    //brbus
    .br_bus            (br_bus         ),
    //outputs
    .fs_to_ds_valid    (fs_to_ds_valid ),
    .fs_to_ds_bus      (fs_to_ds_bus   ),
    //to TLB
    .fs_to_tlb_bus     (fs_to_tlb_bus  ),
    //from TLB
    .tlb_to_fs_bus     (tlb_to_fs_bus  ),
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
    .clk            (aclk           ),
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
    .clk             (aclk           ),
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
    //to TLB
    .es_to_tlb_bus   (es_to_tlb_bus  ),
    //from TLB
    .tlb_to_es_bus   (tlb_to_es_bus  ),
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
    .clk            (aclk           ),
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
    .clk            (aclk           ),
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
    //to TLB
    .ws_to_tlb_bus  (ws_to_tlb_bus  ),
    //from TLB
    .tlb_to_ws_bus  (tlb_to_ws_bus  ),
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
    .ext_int_in       (int              )
);

sram2axi u_sram2axi(
    .clk                (aclk               ),
    .reset              (reset              ),
    .arid               (arid               ),
    .araddr             (araddr             ),
    .arlen              (arlen              ),
    .arsize             (arsize             ),
    .arburst            (arburst            ),
    .arlock             (arlock             ),
    .arcache            (arcache            ),
    .arprot             (arprot             ),
    .arvalid            (arvalid            ),
    .arready            (arready            ),
    .rid                (rid                ),
    .rdata              (rdata              ),
    .rresp              (rresp              ),
    .rlast              (rlast              ),
    .rvalid             (rvalid             ),
    .rready             (rready             ),
    .awid               (awid               ),
    .awaddr             (awaddr             ),
    .awlen              (awlen              ),
    .awsize             (awsize             ),
    .awburst            (awburst            ),
    .awlock             (awlock             ),
    .awcache            (awcache            ),
    .awprot             (awprot             ),
    .awvalid            (awvalid            ),
    .awready            (awready            ),
    .wid                (wid                ),
    .wdata              (wdata              ),
    .wstrb              (wstrb              ),
    .wlast              (wlast              ),
    .wvalid             (wvalid             ),
    .wready             (wready             ),
    .bid                (bid                ),
    .bresp              (bresp              ),
    .bvalid             (bvalid             ),
    .bready             (bready             ),
    .inst_sram_req      (inst_sram_req      ),
    .inst_sram_wr       (inst_sram_wr       ),
    .inst_sram_size     (inst_sram_size     ),
    .inst_sram_wstrb    (inst_sram_wstrb    ),
    .inst_sram_addr     (inst_sram_addr     ),
    .inst_sram_wdata    (inst_sram_wdata    ),
    .inst_sram_addr_ok  (inst_sram_addr_ok  ),
    .inst_sram_data_ok  (inst_sram_data_ok  ),
    .inst_sram_rdata    (inst_sram_rdata    ),
    .data_sram_req      (data_sram_req      ),
    .data_sram_wr       (data_sram_wr       ),
    .data_sram_size     (data_sram_size     ),
    .data_sram_wstrb    (data_sram_wstrb    ),
    .data_sram_addr     (data_sram_addr     ),
    .data_sram_wdata    (data_sram_wdata    ),
    .data_sram_addr_ok  (data_sram_addr_ok  ),
    .data_sram_data_ok  (data_sram_data_ok  ),
    .data_sram_rdata    (data_sram_rdata    )
);
endmodule