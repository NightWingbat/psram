module tb_psram_controller();

parameter CLK_FRE    = 528_000_000;
parameter PSRAM_FRE  = 66_000_000;
parameter LATENCY    = 3;
parameter MAIN_FRE   = 528; //unit MHz
reg                   sys_clk = 0;
reg                   sys_rst;

always begin
    #(528/MAIN_FRE) sys_clk = ~sys_clk;
end

/*
always begin
    #50 sys_rst = 1;
end
*/

//Instance 
wire        	init_cable_complete;
wire        	psram_clk;
wire        	psram_ce;
wire        	psram_done;
wire [15:0] 	psram_rd_data;
wire        	psram_rd_valid;
wire        	psram_wr_valid;
wire [15:0]     psram_dq;
wire [1:0]      psram_dm;

reg				psram_exe;
reg				rw_ctrl;
reg				bit_ctrl;
reg	 [1:0]		byte_write;
reg				wrap_in;
reg  [31:0]     addr_in;
reg  [15:0]		data_in;
reg  [11:0]		burst_len;
reg  [1:0]		command_in;

//psram_exe
always @(posedge sys_clk) begin
	if(sys_rst == 1'b0)begin
		psram_exe <= 1'b0;
	end
	else if(psram_done)begin
		psram_exe <= 1'b1;
	end
	else begin
		psram_exe <= 1'b0;
	end
end

//data_in
always @(posedge psram_wr_valid or negedge sys_rst) begin
	if(sys_rst == 1'b0)begin
		data_in <= 16'd0;
	end
	else if(psram_wr_valid)begin
		data_in <= data_in + 1'b1;
	end
end

initial begin
	sys_rst = 1'b0;
	#50
	sys_rst = 1'b1;
	#50
	sys_rst = 1'b0;
	#50
	sys_rst = 1'b1;
end

initial begin
	rw_ctrl    = 1'b1;
	bit_ctrl   = 1'b1;
	byte_write = 2'b00;
	wrap_in    = 1'b0;
	addr_in    = 32'd0;
	burst_len  = 12'd32;
	command_in = 2'b00;
end

psram_controller #(
	.CLK_FRE   	( CLK_FRE    ),
	.PSRAM_FRE 	( PSRAM_FRE  ),
	.LATENCY   	( LATENCY    ))
u_psram_controller(
	.sys_clk             	( sys_clk              ),
	.sys_rst             	( sys_rst              ),
	
	.psram_exe           	( psram_exe            ),
	.rw_ctrl             	( rw_ctrl              ),
	.bit_ctrl            	( bit_ctrl             ),
	.byte_write          	( byte_write           ),
	.wrap_in             	( wrap_in              ),
	.addr_in             	( addr_in              ),
	.data_in             	( data_in              ),
	.burst_len           	( burst_len            ),
	.command_in          	( command_in           ),
	
	.init_cable_complete 	( init_cable_complete  ),
	
	.psram_clk           	( psram_clk            ),
	.psram_ce            	( psram_ce             ),
	.psram_dq            	( psram_dq             ),
	.psram_dm            	( psram_dm             ),
	
	.psram_done          	( psram_done           ),
	.psram_rd_data       	( psram_rd_data        ),
	.psram_rd_valid      	( psram_rd_valid       ),
	.psram_wr_valid      	( psram_wr_valid       ));

initial begin            
    $dumpfile("wave.vcd");        
    $dumpvars(0, tb_psram_controller);    
    #500000 $finish;
end

endmodule  //TOP
