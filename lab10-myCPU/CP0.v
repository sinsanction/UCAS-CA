`define CP0_INDEX           {5'd0, 3'd0}
`define CP0_ENTRYLO0        {5'd2, 3'd0}
`define CP0_ENTRYLO1        {5'd3, 3'd0}
`define CP0_BADVADDR        {5'd8, 3'd0}
`define CP0_COUNT           {5'd9, 3'd0}
`define CP0_ENTRYHI         {5'd10, 3'd0}
`define CP0_COMPARE         {5'd11, 3'd0}
`define CP0_STATUS          {5'd12, 3'd0}
`define CP0_CAUSE           {5'd13, 3'd0}
`define CP0_EPC             {5'd14, 3'd0}
`define CP0_CONFIG          {5'd16, 3'd0}
`define CP0_CONFIG1         {5'd16, 3'd1}

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
    output        has_int
);

reg [31:0] rf[31:0];

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
    if (wb_except && (wb_exccode == 5'h4 || wb_exccode == 5'h5)) begin
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
                   {32{cp0_addr==`CP0_BADVADDR}} & BadVAddr;

assign cp0_epc = EPC;

endmodule