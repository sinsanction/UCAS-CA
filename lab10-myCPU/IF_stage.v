`include "mycpu.h"

module if_stage(
    input                          clk            ,
    input                          reset          ,
    //allwoin
    input                          ds_allowin     ,
    //brbus
    input  [`BR_BUS_WD       -1:0] br_bus         ,
    //to ds
    output                         fs_to_ds_valid ,
    output [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus   ,
    //exception bus
    input  [`WS_TO_FS_EXBUS_WD -1:0] ws_to_fs_exbus,
    // inst sram interface
    output                        inst_sram_req,
    output                        inst_sram_wr,
    output [ 1:0]                 inst_sram_size,
    output [ 3:0]                 inst_sram_wstrb,
    output [31:0]                 inst_sram_addr,
    output [31:0]                 inst_sram_wdata,
    input                         inst_sram_addr_ok,
    input                         inst_sram_data_ok,
    input  [31:0]                 inst_sram_rdata
);

reg         fs_valid;
wire        fs_ready_go;
wire        fs_allowin;
wire        to_fs_valid;
wire        prefs_ready_go;
reg         iram_req;
reg         clear_all_r;

reg         fs_inst_clear;
reg         fs_inst_reg_valid;
reg  [31:0] fs_inst_reg;

wire [31:0] seq_pc;
wire [31:0] nextpc;

wire         br;
wire         br_stall;
wire         br_taken;
wire         br_leave;
wire [ 31:0] br_target;
reg          br_bus_r_valid;
reg  [`BR_BUS_WD-1:0] br_bus_r;
reg          bd_begin;
reg          bd_done;
wire         br_valid;
wire [ 31:0] br_target_final;

assign {br, br_leave, br_stall, br_taken, br_target} = br_bus;
always @(posedge clk) begin
    if (reset) begin
        br_bus_r_valid <= 1'b0;
    end
    else if (fs_clear_all) begin
        br_bus_r_valid <= 1'b0;
    end
    else if (prefs_ready_go && fs_allowin && bd_done) begin
        br_bus_r_valid <= 1'b0;
    end
    else if (br_leave) begin
        br_bus_r <= br_bus;
        br_bus_r_valid <= 1'b1;
    end
end
always @(posedge clk) begin
    if (reset) begin
        bd_begin <= 1'b0;
    end
    else if (fs_clear_all) begin
        bd_begin <= 1'b0;
    end
    else if (bd_begin && fs_valid) begin
        bd_begin <= 1'b0;
    end
    else if (br && !bd_done) begin
        bd_begin <= 1'b1;
    end
end
always @(posedge clk) begin
    if (fs_clear_all) begin
        bd_done <= 1'b0;
    end
    else if (bd_begin && fs_valid) begin
        bd_done <= 1'b1;
    end
    else if (prefs_ready_go && fs_allowin) begin
        bd_done <= 1'b0;
    end
end

wire        fs_bd;
wire        fs_except;
wire [ 4:0] fs_exccode;
wire [31:0] fs_inst;
wire [31:0] fs_final_inst;
reg  [31:0] fs_pc;
assign fs_to_ds_bus = {fs_bd,
                       fs_except,
                       fs_exccode,
                       fs_final_inst,
                       fs_pc   };
                    
wire        fs_clear_all;
wire [31:0] exception_entry;
assign {fs_clear_all, exception_entry} = ws_to_fs_exbus;

// pre-IF stage
always @(posedge clk) begin
    if (reset) begin
        iram_req <= 1'b0;
    end
    else if(inst_sram_req && inst_sram_addr_ok) begin
        iram_req <= 1'b0;
    end
    else if (fs_allowin) begin
        iram_req <= 1'b1;
    end
end
always @(posedge clk) begin
    if (reset) begin
        clear_all_r <= 1'b0;
    end
    else if(fs_clear_all) begin
        clear_all_r <= 1'b1;
    end
    else if (inst_sram_req && inst_sram_addr_ok) begin
        clear_all_r <= 1'b0;
    end
end

assign inst_sram_req  = iram_req && ~(br && bd_done && br_stall);
assign prefs_ready_go = iram_req && inst_sram_addr_ok;
assign to_fs_valid    = ~reset && prefs_ready_go;
assign seq_pc         = fs_pc + 3'h4;
assign nextpc         = (fs_clear_all || clear_all_r) ? exception_entry : 
                                (br_valid && bd_done) ? br_target_final : seq_pc;

assign br_valid = (br_bus_r_valid && br_bus_r[32]) || (br_taken);
assign br_target_final = {32{br_bus_r_valid && br_bus_r[32]}} & br_bus_r[31:0] | 
                         {32{br_taken}} & br_target;

// IF stage
assign fs_ready_go    = (inst_sram_data_ok || fs_inst_reg_valid) && !fs_inst_clear;
assign fs_allowin     = !fs_valid || fs_ready_go && ds_allowin;
assign fs_to_ds_valid = fs_valid && fs_ready_go;
always @(posedge clk) begin
    if (reset) begin
        fs_valid <= 1'b0;
    end
    else if (fs_allowin && ~fs_clear_all) begin
        fs_valid <= to_fs_valid;
    end
    else if (fs_clear_all) begin
        fs_valid <= 1'b0;
    end

    if (reset) begin
        fs_pc <= 32'hbfbffffc;  //trick: to make nextpc be 0xbfc00000 during reset 
    end
    else if (to_fs_valid && fs_allowin) begin
        fs_pc <= nextpc;
    end
end


always @(posedge clk) begin
    if (reset) begin
        fs_inst_clear <= 1'b0;
    end
    else if (fs_clear_all && to_fs_valid) begin
        fs_inst_clear <= 1'b1;
    end
    else if (fs_clear_all && ~fs_allowin && ~fs_ready_go) begin
        fs_inst_clear <= 1'b1;
    end
    else if (inst_sram_data_ok) begin
        fs_inst_clear <= 1'b0;
    end
end
always @(posedge clk) begin
    if (reset) begin
        fs_inst_reg_valid <= 1'b0;
    end
    else if (fs_clear_all) begin
        fs_inst_reg_valid <= 1'b0;
    end
    else if (fs_valid && inst_sram_data_ok && !ds_allowin) begin
        fs_inst_reg <= fs_inst;
        fs_inst_reg_valid <= 1'b1;
    end
    else if (fs_to_ds_valid && ds_allowin) begin
        fs_inst_reg_valid <= 1'b0;
    end
end
assign fs_final_inst = (fs_valid && fs_inst_reg_valid) ? fs_inst_reg : fs_inst;

wire fs_AdEL;
assign fs_AdEL = (fs_pc[1:0] != 2'b00);

assign fs_bd      = br || (br_bus_r_valid && br_bus_r[35]);
assign fs_except  = fs_AdEL && fs_valid;
assign fs_exccode = {5{fs_AdEL}} & 5'h4;

assign inst_sram_wr    = 1'b0;
assign inst_sram_size  = 2'd2;
assign inst_sram_wstrb = 4'h0;
assign inst_sram_addr  = nextpc;
assign inst_sram_wdata = 32'b0;

assign fs_inst         = inst_sram_rdata;

endmodule