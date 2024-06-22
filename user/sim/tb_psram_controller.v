`timescale 100ps/10ps

module tb_psram_controller();

`include "Config-AC.v"

parameter PSRAM_FRE  = 200_000_000;
parameter LATENCY    = 7;
parameter BIT_WIDTH  = 16;
parameter BURST_LEN  = 16;
parameter WARP_MODE  = "Wrap";
parameter RW_METHOD  = "Linear";

parameter MAIN_FRE     = 200; //unit MHz
parameter FREQ_CLK_MHZ = 200;
reg                   sys_clk = 0;
reg                   sys_rst = 0;

always begin
    #(500/MAIN_FRE) sys_clk = ~sys_clk;
end

always begin
    #50 sys_rst = 1;
end

//clock
reg		rst;

wire	clk_400m;
wire   	clk_out0;
wire   	clk_out45;
wire   	clk_out90;
wire   	clk_out135;
wire   	locked;

//psram
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

wire				    ram_en;
wire					rw_ctrl;
wire[31:0]				addr_in;
reg [BIT_WIDTH*2-1:0]   ram_data_in;

wire[BIT_WIDTH-1:0]     dq_in_hi;
wire[BIT_WIDTH-1:0]     dq_in_lo;

wire[1:0]             	dm_in_hi;
wire[1:0]             	dm_in_lo;

wire                 	o_psram_clk;
wire                 	o_psram_ce;
wire[BIT_WIDTH-1:0]		io_psram_dq;
wire[1:0]				io_psram_dm;

localparam	TCYC	 = 1000000/FREQ_CLK_MHZ;
localparam  TS       = TCYC/100;

initial begin
	rst = 1'b1;
	#(100*TS);
	rst = 1'b0;
end

assign addr_in = 32'd4;
assign rw_ctrl = 1'b1;
assign ram_en  = init_cable_complete & ctrl_idle;

always @(posedge clk_out0 or negedge locked) begin
    if(locked == 1'b0)begin
        ram_data_in <= 32'h04060103;
    end
    else if(ram_wr_valid == 1'b1)begin
        ram_data_in[7:0]   <= ram_data_in[7:0]   + 1'b1;
		ram_data_in[15:8]  <= ram_data_in[15:8]  + 1'b1;
		ram_data_in[23:16] <= ram_data_in[23:16] + 1'b1;
		ram_data_in[31:24] <= ram_data_in[31:24] + 1'b1;
    end
end

clock_gen #(
	.FREQ_CLK_MHZ 	( FREQ_CLK_MHZ  ))
u_clock_gen(
	.rst        	( rst         ),
	.clk_out0   	( clk_out0    ),
	.clk_out45  	( clk_out45   ),
	.clk_out90  	( clk_out90   ),
	.clk_out135 	( clk_out135  ),
	.locked     	( locked      )
);

clock_gen #(
	.FREQ_CLK_MHZ 	( 400		  ))
u_clock_400m(
	.rst        	( rst         ),
	.clk_out0   	( clk_400m    ),
	.clk_out45  	(    		  ),
	.clk_out90  	(    		  ),
	.clk_out135 	(   		  ),
	.locked     	(       	  )
);

/*
psram_rw #(
	.BIT_WIDTH 	( BIT_WIDTH  ),
	.BURST_LEN 	( BURST_LEN  ))
u_psram_rw(
	.ram_clk             	( clk_out0             ),
	.ram_rst             	( locked               ),
	
	.init_cable_complete 	( init_cable_complete  ),
	.ctrl_idle           	( ctrl_idle            ),
	
	.ram_wr_valid        	( ram_wr_valid         ),
	.ram_rd_valid        	( ram_rd_valid         ),
	
	.addr_in             	( addr_in              ),
	.rw_ctrl             	( rw_ctrl              ),
	.ram_en              	( ram_en               ),
	.ram_data_in         	( ram_data_in          )
);
*/

psram_controller #(
	.PSRAM_FRE 	( PSRAM_FRE  ),
	.LATENCY   	( LATENCY    ),
	.BIT_WIDTH 	( BIT_WIDTH  ),
	.BURST_LEN 	( BURST_LEN  ),
	.WARP_MODE 	( WARP_MODE  ),
	.RW_METHOD 	( RW_METHOD  ))
u_psram_controller(
	.ram_clk             	( clk_out0             ),
	.ram_clk_p           	( clk_out90            ),
	.ram_rst             	( locked               ),
	
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
	.ram_wr_valid        	( ram_wr_valid         )
);

psram_phy #(
	.DEVICE    	( "Gowin"   ),
	.BIT_WIDTH 	( BIT_WIDTH ))
u_psram_phy(
	.ram_clk     	( clk_out0     ),
	.ram_clk_p   	( clk_out90    ),
	
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

GSR GSR(.GSRI(1'b1));

/*
W958D6NKY ram_x16_inst(
	.adq	(io_psram_dq), 		
    .clk	(o_psram_clk),		
    .clk_n	(1'b0		),      
    .csb	(o_psram_ce	),		
    .rwds	(io_psram_dm),        
    .VCC	(1'b1		),
    .VSS	(1'b0		),
    .resetb	(	),
    .die_stack	(1'b0	),
    .optddp	(1'b0		));
*/

endmodule  //TOP
