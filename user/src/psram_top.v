module psram_top #(
    parameter CLK_FRE    = 800_000_000,
    parameter PSRAM_FRE  = 200_000_000,
    parameter LATENCY    = 5
) (
    input        sys_clk,
    input        sys_rst,

    output       psram_clk,
    output       psram_ce,
    inout [15:0] psram_dq,
    inout [1:0]  psram_dm,

	output		 psram_clk,
	output		 psram_ce
);

wire        	init_cable_complete;
wire        	psram_done;
wire [15:0] 	psram_rd_data;
wire        	psram_rd_valid;
wire        	psram_wr_valid;

wire        	psram_exe;
wire        	rw_ctrl;
wire        	bit_ctrl;
wire [1:0]  	byte_write;
wire        	wrap_in;
wire [31:0] 	addr_in;
wire [15:0] 	data_in;
wire [11:0] 	burst_len;
wire [1:0]  	command_in;

psram_controller #(
	.CLK_FRE   	( CLK_FRE  	   ),
	.PSRAM_FRE 	( PSRAM_FRE    ),
	.LATENCY   	( LATENCY      ))
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
	.psram_wr_valid      	( psram_wr_valid       )
);

psram_rw #(
	.BIT_MODE  	( 16      ),
	.WRAP_MODE 	( "wrap"  ))
u_psram_rw(
	.sys_clk             	( sys_clk              ),
	.sys_rst             	( sys_rst              ),
	
	.init_cable_complete 	( init_cable_complete  ),
	
	.psram_done          	( psram_done           ),
	.psram_wr_valid      	( psram_wr_valid       ),
	.psram_rd_valid      	( psram_rd_valid       ),
	
	.psram_exe           	( psram_exe            ),
	.rw_ctrl             	( rw_ctrl              ),
	.bit_ctrl            	( bit_ctrl             ),
	.byte_write          	( byte_write           ),
	.wrap_in             	( wrap_in              ),
	.addr_in             	( addr_in              ),
	.data_in             	( data_in              ),
	.burst_len           	( burst_len            ),
	.command_in          	( command_in           )
);

endmodule  //psram_top
