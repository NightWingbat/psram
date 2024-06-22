module psram_top #(
    parameter PSRAM_FRE  = 200_000_000,
    parameter LATENCY    = 3,
    parameter BIT_WIDTH  = 16,
    parameter BURST_LEN  = 32,
    parameter WARP_MODE  = "Wrap",
    parameter RW_METHOD  = "Linear"
) (
    input        				sys_clk,
    input        				sys_rst,

    output                      o_psram_clk,
    output                      o_psram_ce,
    inout   [BIT_WIDTH - 1 : 0] io_psram_dq,
    inout   [1:0]               io_psram_dm
);

// outports wire
wire                   	init_cable_complete;
wire                   	ctrl_idle;

wire                   	psram_clk;
wire                   	psram_ce;

wire                   	dq_en;
wire [BIT_WIDTH-1:0]   	dq_out_hi;
wire [BIT_WIDTH-1:0]   	dq_out_lo;

wire                   	dm_en;
wire [1:0]             	dm_out_hi;
wire [1:0]             	dm_out_lo;

wire [BIT_WIDTH*2-1:0] 	ram_data_out;
wire                   	ram_rd_valid;
wire                   	ram_wr_valid;

wire [BIT_WIDTH-1:0] 	dq_in_hi;
wire [BIT_WIDTH-1:0] 	dq_in_lo;

wire [1:0]           	dm_in_hi;
wire [1:0]           	dm_in_lo;

wire				    ram_en;
reg						rw_ctrl;
reg	[31:0]				addr_in;
reg [BIT_WIDTH*2-1:0]   ram_data_in;

psram_rw #(
	.BIT_WIDTH 	( BIT_WIDTH  ),
	.BURST_LEN 	( BURST_LEN  ))
u_psram_rw(
	.ram_clk             	( ram_clk              ),
	.ram_rst             	( ram_rst              ),
	
	.init_cable_complete 	( init_cable_complete  ),
	.ctrl_idle           	( ctrl_idle            ),
	
	.ram_wr_valid        	( ram_wr_valid         ),
	.ram_rd_valid        	( ram_rd_valid         ),
	
	.addr_in             	( addr_in              ),
	.rw_ctrl             	( rw_ctrl              ),
	.ram_en              	( ram_en               ),
	.ram_data_in         	( ram_data_in          )
);

psram_controller #(
	.PSRAM_FRE 	( PSRAM_FRE    ),
	.LATENCY   	( LATENCY      ),
	.BIT_WIDTH 	( BIT_WIDTH    ),
	.BURST_LEN 	( BURST_LEN    ),
	.WARP_MODE 	( WARP_MODE    ),
	.RW_METHOD 	( RW_METHOD    ))
u_psram_controller(
	.ram_clk             	( ram_clk              ),
	.ram_clk_p           	( ram_clk_p            ),
	.ram_rst             	( ram_rst              ),
	
	.ram_en              	( ram_en               ),
	.rw_ctrl             	( rw_ctrl              ),
	.addr_in             	( addr_in              ),
	.ram_data_in         	( ram_data_in          ),
	
	.init_cable_complete 	( init_cable_complete  ),
	.ctrl_idle           	( ctrl_idle            ),
	
	.psram_clk           	( psram_clk            ),
	.psram_ce            	( psram_ce             ),
	
	.dq_en               	( dq_en                ),
	.dq_out_hi           	( dq_out_hi            ),
	.dq_out_lo           	( dq_out_lo            ),
	.dq_in_hi            	( dq_in_hi             ),
	.dq_in_lo            	( dq_in_lo             ),
	
	.dm_en               	( dm_en                ),
	.dm_out_hi           	( dm_out_hi            ),
	.dm_out_lo           	( dm_out_lo            ),
	.dm_in_hi            	( dm_in_hi             ),
	.dm_in_lo            	( dm_in_lo             ),
	
	.ram_data_out        	( ram_data_out         ),
	.ram_rd_valid        	( ram_rd_valid         ),
	.ram_wr_valid        	( ram_wr_valid         ));

psram_phy #(
	.DEVICE    	( "Gowin"  ),
	.BIT_WIDTH 	( BIT_WIDTH))
u_psram_phy(
	.ram_clk     	( ram_clk      ),
	.ram_clk_p   	( ram_clk_p    ),
	
	.dq_en       	( dq_en        ),
	.dq_out_hi   	( dq_out_hi    ),
	.dq_out_lo   	( dq_out_lo    ),
	.dq_in_hi    	( dq_in_hi     ),
	.dq_in_lo    	( dq_in_lo     ),
	
	.dm_en       	( dm_en        ),
	.dm_out_hi   	( dm_out_hi    ),
	.dm_out_lo   	( dm_out_lo    ),
	.dm_in_hi    	( dm_in_hi     ),
	.dm_in_lo    	( dm_in_lo     ),
	
	.psram_clk   	( psram_clk    ),
	.psram_ce    	( psram_ce     ),
	
	.o_psram_clk 	( o_psram_clk  ),
	.o_psram_ce  	( o_psram_ce   ),
	.io_psram_dq 	( io_psram_dq  ),
	.io_psram_dm 	( io_psram_dm  )
);

endmodule  //psram_top
