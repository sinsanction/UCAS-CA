`define WAIT_REQ        10'b0000000001
`define RECV_REQ        10'b0000000010
`define SEND_REQ        10'b0000000100
`define SEND_DATA       10'b0000001000
`define WAIT_RES        10'b0000010000
`define RECV_RES        10'b0000100000
`define RECV_INST_REQ   10'b0001000000
`define RECV_DATA_REQ   10'b0010000000
`define RECV_INST_RES   10'b0100000000
`define RECV_DATA_RES   10'b1000000000

module sram2axi(
    input         clk,
    input         reset,
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

    // inst sram interface
    input         inst_sram_req,
    input         inst_sram_wr,
    input  [ 1:0] inst_sram_size,
    input  [ 3:0] inst_sram_wstrb,
    input  [31:0] inst_sram_addr,
    input  [31:0] inst_sram_wdata,
    output        inst_sram_addr_ok,
    output        inst_sram_data_ok,
    output [31:0] inst_sram_rdata,
    // data sram interface
    input         data_sram_req,
    input         data_sram_wr,
    input  [ 1:0] data_sram_size,
    input  [ 3:0] data_sram_wstrb,
    input  [31:0] data_sram_addr,
    input  [31:0] data_sram_wdata,
    output        data_sram_addr_ok,
    output        data_sram_data_ok,
    output [31:0] data_sram_rdata
);

/* --------------------write--------------------*/
reg [9:0] wreq_state;
reg [9:0] wreq_next_state;
reg [9:0] wres_state;
reg [9:0] wres_next_state;

reg write_transaction;
always@(posedge clk) begin
    if(reset) begin
        write_transaction <= 1'b0;
    end
    else if(wreq_state == `RECV_REQ && wres_state == `RECV_RES) begin
        write_transaction <= write_transaction;
    end
    else if(wreq_state == `RECV_REQ) begin
        write_transaction <= write_transaction + 1'b1;
    end
    else if(wres_state == `RECV_RES) begin
        write_transaction <= write_transaction - 1'b1;
    end 
end

/* write request and write data */
assign awid  = 4'b1;
assign awlen = 8'b0;
assign awburst = 2'b1;
assign awlock = 2'b0;
assign awcache = 4'b0;
assign awprot = 3'b0;
assign wid = 4'b1;
assign wlast = 1'b1;

always@(posedge clk) begin
	if(reset) begin
		wreq_state <= `WAIT_REQ;
	end
	else begin
		wreq_state <= wreq_next_state;
	end
end

always@(*) begin
	case(wreq_state)
	`WAIT_REQ:
		if(data_sram_req && data_sram_wr && write_transaction != 1'b1) begin
			wreq_next_state = `RECV_REQ;
		end
		else begin
			wreq_next_state = `WAIT_REQ;
		end
	`RECV_REQ:
        wreq_next_state = `SEND_REQ;
    `SEND_REQ:
        if(awvalid && awready) begin
			wreq_next_state = `SEND_DATA;
		end
		else begin
			wreq_next_state = `SEND_REQ;
		end
    `SEND_DATA:
        if(wvalid && wready)begin
			wreq_next_state = `WAIT_REQ;
		end
		else begin
			wreq_next_state = `SEND_DATA;
		end
	default:
		wreq_next_state = `WAIT_REQ;
	endcase
end

// RECV_REQ: store info from sram / write_transaction++ / output addr_ok
assign data_sram_addr_ok = (wreq_state == `RECV_REQ) || (rreq_state == `RECV_DATA_REQ);

reg [ 1:0] wreq_size;
reg [ 3:0] wreq_wstrb;
reg [31:0] wreq_addr;
reg [31:0] wreq_wdata;
always@(posedge clk) begin
	if(data_sram_req && data_sram_addr_ok) begin
		wreq_size <= data_sram_size;
        wreq_wstrb <= data_sram_wstrb;
        wreq_addr <= data_sram_addr;
        wreq_wdata <= data_sram_wdata;
	end
end

// SEND_REQ: send awvalid and wait for awready
assign awaddr = wreq_addr;
assign awsize = {1'b0, wreq_size};
assign awvalid = !reset && (wreq_state == `SEND_REQ);

// SEND_DATA: send wvalid and wait for wready
assign wdata = wreq_wdata;
assign wstrb = wreq_wstrb;
assign wvalid = !reset && (wreq_state == `SEND_DATA);


/* write response */
always@(posedge clk) begin
	if(reset) begin
		wres_state <= `WAIT_RES;
	end
	else begin
		wres_state <= wres_next_state;
	end
end

always@(*) begin
	case(wres_state)
	`WAIT_RES:
		if(bvalid && bready && write_transaction != 1'b0) begin
			wres_next_state = `RECV_RES;
		end
		else begin
			wres_next_state = `WAIT_RES;
		end
	`RECV_RES:
        wres_next_state = `WAIT_RES;
	default:
		wres_next_state = `WAIT_RES;
	endcase
end

// WAIT_RES: send bready and wait for bvalid
assign bready = !reset && (wres_state == `WAIT_RES);

// RECV_RES: write_transaction-- / output data_ok
assign data_sram_data_ok = (wres_state == `RECV_RES) || (rres_state == `RECV_DATA_RES);


/* --------------------read--------------------*/
reg [9:0] rreq_state;
reg [9:0] rreq_next_state;
reg [9:0] rres_state;
reg [9:0] rres_next_state;

reg id0_read_transaction;
reg id1_read_transaction;
always@(posedge clk) begin
    if(reset) begin
        id0_read_transaction <= 1'b0;
    end
    else if(rreq_state == `RECV_INST_REQ && rres_state == `RECV_INST_RES) begin
        id0_read_transaction <= id0_read_transaction;
    end
    else if(rreq_state == `RECV_INST_REQ) begin
        id0_read_transaction <= id0_read_transaction + 1'b1;
    end
    else if(rres_state == `RECV_INST_RES) begin
        id0_read_transaction <= id0_read_transaction - 1'b1;
    end 

    if(reset) begin
        id1_read_transaction <= 1'b0;
    end
    else if(rreq_state == `RECV_DATA_REQ && rres_state == `RECV_DATA_RES) begin
        id1_read_transaction <= id1_read_transaction;
    end
    else if(rreq_state == `RECV_DATA_REQ) begin
        id1_read_transaction <= id1_read_transaction + 1'b1;
    end
    else if(rres_state == `RECV_DATA_RES) begin
        id1_read_transaction <= id1_read_transaction - 1'b1;
    end 
end

/* read request */
assign arlen = 8'b0;
assign arburst = 2'b1;
assign arlock = 2'b0;
assign arcache = 4'b0;
assign arprot = 3'b0;

always@(posedge clk) begin
	if(reset) begin
		rreq_state <= `WAIT_REQ;
	end
	else begin
		rreq_state <= rreq_next_state;
	end
end

always@(*) begin
	case(rreq_state)
	`WAIT_REQ:
		if(data_sram_req && !data_sram_wr && id1_read_transaction != 1'b1) begin
			rreq_next_state = `RECV_DATA_REQ;
		end
		else if(inst_sram_req && !inst_sram_wr && id0_read_transaction != 1'b1) begin
			rreq_next_state = `RECV_INST_REQ;
		end
        else begin
            rreq_next_state = `WAIT_REQ;
        end
	`RECV_INST_REQ:
        rreq_next_state = `SEND_REQ;
    `RECV_DATA_REQ:
        rreq_next_state = `SEND_REQ;
    `SEND_REQ:
        if(arvalid && arready) begin
            rreq_next_state = `WAIT_REQ;
        end
        else begin
            rreq_next_state = `SEND_REQ;
        end
	default:
		rreq_next_state = `WAIT_REQ;
	endcase
end

reg [3:0] rreq_id;
always@(posedge clk) begin
	if(rreq_state == `RECV_INST_REQ) begin
		rreq_id <= 4'b0;
	end
    else if(rreq_state == `RECV_DATA_REQ) begin
		rreq_id <= 4'b1;
	end
end

// RECV_INST_REQ: store info from sram / id0_read_transaction++ / output addr_ok / modify rreq_id
reg [31:0] rreq_inst_addr;
reg [ 1:0] rreq_inst_size;
always@(posedge clk) begin
	if(inst_sram_req && inst_sram_addr_ok) begin
		rreq_inst_addr <= inst_sram_addr;
        rreq_inst_size <= inst_sram_size;
	end
end

assign inst_sram_addr_ok = (rreq_state == `RECV_INST_REQ);

// RECV_DATA_REQ: store info from sram / id1_read_transaction++ / output addr_ok / modify rreq_id
reg [31:0] rreq_data_addr;
reg [ 1:0] rreq_data_size;
always@(posedge clk) begin
    if(data_sram_req && data_sram_addr_ok) begin
		rreq_data_addr <= data_sram_addr;
        rreq_data_size <= data_sram_size;
	end
end

// SEND_REQ: send arvalid and wait for arready
assign arid = rreq_id;
assign araddr = {32{rreq_id == 4'b0}} & rreq_inst_addr |
                {32{rreq_id == 4'b1}} & rreq_data_addr;
assign arsize = {3{rreq_id == 4'b0}} & {1'b0, rreq_inst_size} |
                {3{rreq_id == 4'b1}} & {1'b0, rreq_data_size};
assign arvalid = !reset && (rreq_state == `SEND_REQ);

/* read response */
always@(posedge clk) begin
	if(reset) begin
		rres_state <= `WAIT_RES;
	end
	else begin
		rres_state <= rres_next_state;
	end
end

always@(*) begin
	case(rres_state)
	`WAIT_RES:
        if(rvalid && rready && id1_read_transaction != 1'b0 && rid == 4'b1) begin
			rres_next_state = `RECV_DATA_RES;
		end
		else if(rvalid && rready && id0_read_transaction != 1'b0 && rid == 4'b0) begin
			rres_next_state = `RECV_INST_RES;
		end
		else begin
			rres_next_state = `WAIT_RES;
		end
	`RECV_INST_RES:
        rres_next_state = `WAIT_RES;
    `RECV_DATA_RES:
        rres_next_state = `WAIT_RES;
	default:
		rres_next_state = `WAIT_RES;
	endcase
end

// WAIT_RES: send rready and wait for rvalid
assign rready = !reset && (rres_state == `WAIT_RES);

reg [31:0] res_rdata;
always@(posedge clk) begin
	if(rready && rvalid) begin
		res_rdata <= rdata;
    end
end

// RECV_INST_RES: id0_read_transaction-- / output data_ok / return data
assign inst_sram_data_ok = (rres_state == `RECV_INST_RES);
assign inst_sram_rdata = res_rdata;

// RECV_DATA_RES: id1_read_transaction-- / output data_ok / return data
assign data_sram_rdata = res_rdata;

endmodule