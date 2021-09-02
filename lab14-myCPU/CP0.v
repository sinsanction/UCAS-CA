`include "mycpu.h"

module CP0(
    input         clk,
    input         reset,
    input         wb_bd,
    input  [31:0] wb_pc,
    input  [31:0] wb_badvaddr,
    input         wb_except,
    input  [ 4:0] wb_exccode,
    input         eret_flush,
    input  [ 5:0] ext_int_in,
    input         cp0_wen,
    input  [ 7:0] cp0_addr,
    input  [31:0] cp0_wdata,
    output [31:0] cp0_rdata,
    output [31:0] cp0_epc,
    output        has_int,
    //TLB inst
    input         tlbp_en,
    input         tlbp_found,
    input  [ 3:0] tlbp_index,
    input         tlbr_en,
    //to TLB
    output [`CP0_TO_TLB_BUS_WD -1:0] cp0_to_tlb_bus,
    //from TLB
    input  [`TLB_TO_CP0_BUS_WD -1:0] tlb_to_cp0_bus
);

//TLB
wire [18:0] tlb_r_vpn2;
wire [ 7:0] tlb_r_asid;
wire        tlb_r_g;
wire [19:0] tlb_r_pfn0;
wire [ 2:0] tlb_r_c0;
wire        tlb_r_d0;
wire        tlb_r_v0;
wire [19:0] tlb_r_pfn1;
wire [ 2:0] tlb_r_c1;
wire        tlb_r_d1;
wire        tlb_r_v1;

assign {tlb_r_vpn2, //77:59
        tlb_r_asid, //58:51
        tlb_r_g,    //50:50
        tlb_r_pfn0, //49:30
        tlb_r_c0,   //29:27
        tlb_r_d0,   //26:26
        tlb_r_v0,   //25:25
        tlb_r_pfn1, //24:5
        tlb_r_c1,   // 4:2
        tlb_r_d1,   // 1:1
        tlb_r_v1    // 0:0
       } = tlb_to_cp0_bus;

assign cp0_to_tlb_bus = {index_INDEX,               //81:78
                         entryhi_VPN2,              //77:59
                         entryhi_ASID,              //58:51
                         (entrylo0_G & entrylo1_G), //50:50
                         entrylo0_FPN,              //49:30
                         entrylo0_C,                //29:27
                         entrylo0_D,                //26:26
                         entrylo0_V,                //25:25
                         entrylo1_FPN,              //24:5
                         entrylo1_C,                // 4:2
                         entrylo1_D,                // 1:1
                         entrylo1_V                 // 0:0
                       };

//INDEX
reg         index_P;
reg  [ 3:0] index_INDEX;
wire [31:0] index_rdata;

always @(posedge clk) begin
    if (reset) begin
        index_P <= 1'b0;
    end
    else if (tlbp_en) begin
        index_P <= ~tlbp_found;
    end
end

always @(posedge clk) begin
    if (cp0_wen && cp0_addr==`CP0_INDEX) begin
        index_INDEX <= cp0_wdata[3: 0];
    end
    else if (tlbp_en && tlbp_found) begin
        index_INDEX <= tlbp_index;
    end
end

assign index_rdata = {index_P, 27'b0, index_INDEX};

//ENTRYHI
reg  [18:0] entryhi_VPN2;
reg  [ 7:0] entryhi_ASID;
wire [31:0] entryhi_rdata;

always @(posedge clk) begin
    if (cp0_wen && cp0_addr==`CP0_ENTRYHI) begin
        entryhi_VPN2 <= cp0_wdata[31:13];
        entryhi_ASID <= cp0_wdata[ 7: 0];
    end
    else if (tlbr_en) begin
        entryhi_VPN2 <= tlb_r_vpn2;
        entryhi_ASID <= tlb_r_asid;
    end
    else if (wb_except && (wb_exccode == 5'h1 || wb_exccode == 5'h2 || wb_exccode == 5'h3))begin
        entryhi_VPN2 <= wb_badvaddr[31:13];
    end
end

assign entryhi_rdata = {entryhi_VPN2, 5'b0, entryhi_ASID};

//ENTRYLO0
reg  [19:0] entrylo0_FPN;
reg  [ 2:0] entrylo0_C;
reg         entrylo0_D;
reg         entrylo0_V;
reg         entrylo0_G;
wire [31:0] entrylo0_rdata;

always @(posedge clk) begin
    if (cp0_wen && cp0_addr==`CP0_ENTRYLO0) begin
        entrylo0_FPN <= cp0_wdata[25: 6];
        entrylo0_C   <= cp0_wdata[ 5: 3];
        entrylo0_D   <= cp0_wdata[2];
        entrylo0_V   <= cp0_wdata[1];
        entrylo0_G   <= cp0_wdata[0];
    end
    else if(tlbr_en) begin
        entrylo0_FPN <= tlb_r_pfn0;
        entrylo0_C   <= tlb_r_c0;
        entrylo0_D   <= tlb_r_d0;
        entrylo0_V   <= tlb_r_v0;
        entrylo0_G   <= tlb_r_g;
    end
end

assign entrylo0_rdata = {6'b0, entrylo0_FPN, entrylo0_C, entrylo0_D, entrylo0_V, entrylo0_G};

//ENTRYLO1
reg  [19:0] entrylo1_FPN;
reg  [ 2:0] entrylo1_C;
reg         entrylo1_D;
reg         entrylo1_V;
reg         entrylo1_G;
wire [31:0] entrylo1_rdata;

always @(posedge clk) begin
    if (cp0_wen && cp0_addr==`CP0_ENTRYLO1) begin
        entrylo1_FPN <= cp0_wdata[25: 6];
        entrylo1_C   <= cp0_wdata[ 5: 3];
        entrylo1_D   <= cp0_wdata[2];
        entrylo1_V   <= cp0_wdata[1];
        entrylo1_G   <= cp0_wdata[0];
    end
    else if(tlbr_en) begin
        entrylo1_FPN <= tlb_r_pfn1;
        entrylo1_C   <= tlb_r_c1;
        entrylo1_D   <= tlb_r_d1;
        entrylo1_V   <= tlb_r_v1;
        entrylo1_G   <= tlb_r_g;
    end
end

assign entrylo1_rdata = {6'b0, entrylo1_FPN, entrylo1_C, entrylo1_D, entrylo1_V, entrylo1_G};

//STATUS
wire        status_bev;
reg  [7:0]  status_IM;
reg         status_EXL;
reg         status_IE;
wire [31:0] status_rdata;

assign status_bev = 1'b1;

always @(posedge clk) begin
    if (cp0_wen && cp0_addr==`CP0_STATUS) begin
        status_IM <= cp0_wdata[15: 8];
    end
end

always @(posedge clk) begin
    if (reset) begin
        status_EXL <= 1'b0;
    end
    else if (wb_except) begin
        status_EXL <= 1'b1;
    end
    else if (eret_flush) begin
        status_EXL <= 1'b0;
    end
    else if (cp0_wen && cp0_addr==`CP0_STATUS) begin
        status_EXL <= cp0_wdata[1];
    end
end

always @(posedge clk) begin
    if (reset) begin
        status_IE <= 1'b0;
    end
    else if (cp0_wen && cp0_addr==`CP0_STATUS) begin
        status_IE <= cp0_wdata[0];
    end
end

assign status_rdata = {9'b0, status_bev, 6'b0, status_IM[7:0], 6'b0, status_EXL, status_IE};

//CAUSE
reg         cause_BD;
reg         cause_TI;
reg  [7:0]  cause_IP;
reg  [4:0]  cause_ExcCode;
wire [31:0] cause_rdata;

always @(posedge clk) begin
    if (reset) begin
        cause_BD <= 1'b0;
    end
    else if (wb_except && !status_EXL) begin
        cause_BD <= wb_bd;
    end
end

always @(posedge clk) begin
    if (reset) begin
        cause_TI <= 1'b0;
    end
    else if (cp0_wen && cp0_addr==`CP0_COMPARE) begin
        cause_TI <= 1'b0;
    end
    else if (count_eq_compare) begin
        cause_TI <= 1'b1;
    end
end

always @(posedge clk) begin
    if (reset) begin
        cause_IP[7:2] <= 6'b0;
    end
    else begin
        cause_IP[7]   <= ext_int_in[5] | cause_TI;
        cause_IP[6:2] <= ext_int_in[4:0];
    end
end

always @(posedge clk) begin
    if (reset) begin
        cause_IP[1:0] <= 2'b0;
    end
    else if (cp0_wen && cp0_addr==`CP0_CAUSE) begin
        cause_IP[1:0] <= cp0_wdata[9:8];
    end
end

always @(posedge clk) begin
    if (reset) begin
        cause_ExcCode <= 5'b0;
    end
    else if (wb_except) begin
        cause_ExcCode <= wb_exccode;
    end
end

assign cause_rdata = {cause_BD, cause_TI, 14'b0, cause_IP[7:0], 1'b0, cause_ExcCode[4:0], 2'b0};

//EPC
reg [31:0] EPC;

always @(posedge clk) begin
    if (wb_except && !status_EXL) begin
        EPC <= wb_bd ? (wb_pc - 3'h4) : wb_pc;
    end
    else if (cp0_wen && cp0_addr==`CP0_EPC) begin
        EPC <= cp0_wdata;
    end
end

//BadVAddr
reg [31:0] BadVAddr;

always @(posedge clk) begin
    if (wb_except && (wb_exccode == 5'h1 || wb_exccode == 5'h2 || wb_exccode == 5'h3 || wb_exccode == 5'h4 || wb_exccode == 5'h5)) begin
        BadVAddr <= wb_badvaddr;
    end
end

//COUNT
reg        tick;
reg [31:0] count;

always @(posedge clk) begin
    if (reset)
        tick <= 1'b0;
    else if (cp0_wen && cp0_addr==`CP0_COUNT)
        tick <= 1'b0;
    else
        tick <= ~tick;
end

always @(posedge clk) begin
    if (cp0_wen && cp0_addr==`CP0_COUNT)
        count <= cp0_wdata;
    else if (tick)
        count <= count + 1'b1;
end

//COMPARE
reg [31:0] compare;
wire count_eq_compare;

always @(posedge clk) begin
    if (cp0_wen && cp0_addr==`CP0_COMPARE)
        compare <= cp0_wdata;
end

assign count_eq_compare = (count == compare);

//interrupt
assign has_int = ((cause_IP[7:0] & status_IM[7:0])!=8'h00) && status_IE==1'b1 && status_EXL==1'b0;

assign cp0_rdata = {32{cp0_addr==`CP0_STATUS  }} & status_rdata |
                   {32{cp0_addr==`CP0_CAUSE   }} & cause_rdata |
                   {32{cp0_addr==`CP0_EPC     }} & EPC |
                   {32{cp0_addr==`CP0_COUNT   }} & count |
                   {32{cp0_addr==`CP0_COMPARE }} & compare |
                   {32{cp0_addr==`CP0_BADVADDR}} & BadVAddr |
                   {32{cp0_addr==`CP0_INDEX   }} & index_rdata |
                   {32{cp0_addr==`CP0_ENTRYHI }} & entryhi_rdata |
                   {32{cp0_addr==`CP0_ENTRYLO0}} & entrylo0_rdata |
                   {32{cp0_addr==`CP0_ENTRYLO1}} & entrylo1_rdata;

assign cp0_epc = EPC;

endmodule