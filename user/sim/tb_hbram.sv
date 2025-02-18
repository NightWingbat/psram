`timescale 1 ns / 1 ns

module tb_hbram();

`include "Config-AC.v"

parameter WR_WIDTH    = 64;
parameter WR_wr_DEPTH = 128;
parameter WR_rd_DEPTH = 256;

parameter RD_WIDTH    = 64;
parameter RD_wr_DEPTH = 256;
parameter RD_rd_DEPTH = 128;

parameter HBRAM_FRE   = 200_000_000;
parameter BIT_WIDTH   = 16;
parameter LATENCY     = 7;
parameter STRENGTH    = "34_ohms";
parameter BURST_MODE  = "legacy";
parameter BURST_LEN   = 64;
parameter REFRESH     = "Full_Array";
parameter CLOCK_TYPE  = "Single_Ended";
parameter MASK_WIDTH  = 8;

parameter MAIN_FRE   = 100; //unit MHz
reg                   sys_clk = 0;
reg                   sys_rst = 1;
reg					  rst     = 1;

always begin
    #(500/MAIN_FRE) sys_clk = ~sys_clk;
end

always begin
    #50 sys_rst = 0;
end

localparam					 TCYC	 = 1000000/200;
localparam  				 TS       = TCYC/100;

wire						 clk_out0;
wire						 clk_out45;
wire						 clk_out90;
wire						 clk_out135;
wire						 locked;

reg							 wr_en;
reg	 [WR_WIDTH - 1 : 0]		 wr_data;
wire						 wr_valid;
wire						 wr_full;
wire						 wr_empty;
wire [$clog2(WR_wr_DEPTH):0] WR_wr_count;
wire [$clog2(WR_rd_DEPTH):0] WR_rd_count;

wire                   	     ram_wr_valid;
wire [BIT_WIDTH*2-1:0]       ram_wr_data;
wire                   	     ram_rd_valid;
wire [BIT_WIDTH*2-1:0] 	     ram_rd_data;
wire                   	     hbc_cal_pass;
reg  [MASK_WIDTH-1:0]        wr_data_mask;
wire                   	     ctrl_idle;

wire [31:0]            		 ram_addr;
wire                   		 rw_ctrl;
wire                   		 ram_en;

wire                   		 hbc_ck_p_hi;
wire                   		 hbc_ck_p_lo;
wire                   		 hbc_ck_n_hi;
wire                   		 hbc_ck_n_lo;
wire                   		 hbc_cs_n;
wire                   		 hbc_rst_n;
wire [BIT_WIDTH-1:0]   		 hbc_dq_en;
wire [BIT_WIDTH-1:0]   		 hbc_dq_out_hi;
wire [BIT_WIDTH-1:0]   		 hbc_dq_out_lo;
wire [BIT_WIDTH-1:0]   		 hbc_dq_in_hi;
wire [BIT_WIDTH-1:0]   		 hbc_dq_in_lo;
wire [BIT_WIDTH/8-1:0] 		 hbc_rwds_en;
wire [BIT_WIDTH/8-1:0] 		 hbc_rwds_out_hi;
wire [BIT_WIDTH/8-1:0] 		 hbc_rwds_out_lo;
wire [BIT_WIDTH/8-1:0] 		 hbc_rwds_in_hi;
wire [BIT_WIDTH/8-1:0] 		 hbc_rwds_in_lo;

reg							 rd_en;
reg  [RD_WIDTH - 1 : 0]		 rd_data;
wire						 rd_valid;
wire						 rd_full;
wire						 rd_empty;
wire [$clog2(RD_wr_DEPTH):0] RD_wr_count;
wire [$clog2(RD_rd_DEPTH):0] RD_rd_count;

wire						 ram_rst_n = hbc_rst_n;
wire						 ram_cs_n;
wire						 ram_ck_p;
wire						 ram_ck_n;
wire [BIT_WIDTH/8 - 1 : 0]	 ram_rwds;
wire [BIT_WIDTH - 1 : 0]	 ram_dq;

reg							 native_ram_en;
reg							 native_rw_ctrl;
reg	  [10:0]				 ram_burst_len;

logic [WR_WIDTH - 1 : 0]	 wr_mem[$];
logic [RD_WIDTH - 1 : 0]	 rd_mem[$];

initial begin
	rst = 1'b1;
	#(100*TS);
	rst = 1'b0;
end

//wr_en
initial begin
	wr_en = 1'b0;
	
	@(posedge locked);
	wait(hbc_cal_pass);
	#1000
	wr_en = 1'b1;

	wait(wr_full);
	wr_en = 1'b0;
end

//wr_data
initial begin
	wr_data = 64'h1122_3344_5566_7788;
	forever begin
		@(posedge sys_clk)
		if(wr_en)begin
			wr_data[7:0]   <= wr_data[7:0]   + 1'b1;
			wr_data[15:8]  <= wr_data[15:8]  + 1'b1;
			wr_data[23:16] <= wr_data[23:16] + 1'b1;
			wr_data[31:24] <= wr_data[31:24] + 1'b1;
			wr_data[39:32] <= wr_data[39:32] + 1'b1;
			wr_data[47:40] <= wr_data[47:40] + 1'b1;
			wr_data[55:48] <= wr_data[55:48] + 1'b1;
			wr_data[63:56] <= wr_data[63:56] + 1'b1;
		end
	end
end

//wr_mem
initial begin
	forever begin
		@(posedge sys_clk);
		if(wr_en)begin
			wr_mem.push_back(wr_data);
		end
	end
end

//native_ram_en
initial begin
	native_ram_en  = 1'b0;

	//write
	@(posedge clk_out0);
	wait(wr_full);
	#1000
	native_ram_en  = 1'b1;
	#5
	native_ram_en  = 1'b0;
	//read
	@(posedge ctrl_idle);
	#1000
	native_ram_en  = 1'b1;
	#5
	native_ram_en  = 1'b0;
end

//native_rw_ctrl
initial begin
	native_rw_ctrl = 1'b0;

	@(posedge clk_out0);
	wait(hbc_cal_pass);
	#500
	native_rw_ctrl = 1'b0;

	@(posedge ctrl_idle);
	native_rw_ctrl = 1'b1;
end

//ram_burst_len
initial begin
	ram_burst_len = (WR_WIDTH/BIT_WIDTH) * WR_wr_DEPTH;
end

//wr_data_mask
initial begin
	wr_data_mask = 8'h01;
end

//rd_en
initial begin
	rd_en = 1'b0;

	wait(rd_empty == 1'b0);
	#905
	rd_en = 1'b1;

	wait(rd_empty == 1'b1);
	#100
	rd_en = 1'b0;
end

//rd_mem
initial begin
	forever begin
		@(posedge sys_clk);
		if(rd_valid)begin
			rd_mem.push_back(rd_data);
		end
	end
end

initial begin
	@(posedge sys_clk);
	wait(rd_full);
	wait(rd_empty);
	foreach(rd_mem[i])begin
		$display("the count is %d   wr_data is %h   rd_data is %h\t",i,wr_mem[i],rd_mem[i]);
		if(rd_mem[i][7:0] != wr_mem[i][7:0])begin
			$display("not equal\n");
		end
		else begin
			$display("equal\n");
		end
	end
end

clock_gen #(
	.FREQ_CLK_MHZ 	( 200		  ))
u_clock_gen(
	.rst        	( rst         ),
	.clk_out0   	( clk_out0    ),
	.clk_out45  	( clk_out45   ),
	.clk_out90  	( clk_out90   ),
	.clk_out135 	( clk_out135  ),
	.locked     	( locked      ));

async_fifo #(
	.INPUT_WIDTH       	( WR_WIDTH  		),
	.OUTPUT_WIDTH      	( 32        		),
	.WR_DEPTH          	( WR_wr_DEPTH       ),
	.RD_DEPTH          	( WR_rd_DEPTH       ),
	.MODE              	( "FWFT"    		),
	.DIRECTION         	( "MSB"     		),
	.ECC_MODE          	( "no_ecc"  		),
	.PROG_EMPTY_THRESH 	( 10        		),
	.PROG_FULL_THRESH  	( 10        		),
	.USE_ADV_FEATURES  	( 16'h0404  		))
wr_fifo(
	.reset         	( sys_rst & (~locked)),
	
	.wr_clock      	( sys_clk        ),
	.wr_en         	( wr_en          ),
	.wr_ready      	( 		         ),
	.din           	( wr_data        ),
	
	.rd_clock      	( clk_out0       ),
	.rd_en         	( ram_wr_valid   ),
	.valid         	( wr_valid       ),
	.dout          	( ram_wr_data    ),
	
	.full          	( wr_full        ),
	.empty         	( wr_empty       ),
	
	.wr_data_count 	( WR_wr_count    ),
	.wr_data_space 	(   			 ),
	.rd_data_count 	( WR_rd_count    ),
	.rd_data_space 	(   			 ),
	
	.almost_full   	(     		     ),
	.almost_empty  	(     		     ),
	.prog_full     	(       		 ),
	.prog_empty    	(       		 ),
	.overflow      	(        		 ),
	.underflow     	(        		 ),
	.wr_ack        	(          		 ),
	.sbiterr       	(         		 ),
	.dbiterr       	(         		 ));

hyper_bus #(
	.HBRAM_FRE  	( HBRAM_FRE    ),
	.BIT_WIDTH  	( BIT_WIDTH    ),
	.INIT_NUM		( 1024		   ),
	.LATENCY    	( LATENCY      ),
	.STRENGTH   	( STRENGTH     ),
	.BURST_MODE 	( BURST_MODE   ),
	.BURST_LEN  	( BURST_LEN    ),
	.REFRESH    	( REFRESH      ),
	.CLOCK_TYPE 	( CLOCK_TYPE   ),
	.MASK_WIDTH 	( MASK_WIDTH   ))
u_hyper_bus(
	.ram_clock       	( clk_out0         ),
	.ram_clock_p     	( clk_out90        ),
	.ram_reset       	( sys_rst & (~locked)),
	
	.ram_en          	( native_ram_en    ),
	.rw_ctrl         	( native_rw_ctrl   ),
	.ram_addr        	( 32'd0            ),
	.ram_burst_len		( ram_burst_len	   ),
	
	.ram_wr_valid    	( ram_wr_valid     ),
	.ram_wr_data     	( ram_wr_data      ),
	.ram_rd_valid    	( ram_rd_valid     ),
	.ram_rd_data     	( ram_rd_data      ),
	.ram_data_mask    	( wr_data_mask     ),
	
	.hbc_cal_pass    	( hbc_cal_pass     ),
	.ctrl_idle       	( ctrl_idle        ),
	
	.hbc_ck_p_hi     	( hbc_ck_p_hi      ),
	.hbc_ck_p_lo     	( hbc_ck_p_lo      ),
	.hbc_ck_n_hi     	( hbc_ck_n_hi      ),
	.hbc_ck_n_lo     	( hbc_ck_n_lo      ),
	.hbc_cs_n        	( hbc_cs_n         ),
	.hbc_rst_n       	( hbc_rst_n        ),
	.hbc_dq_en       	( hbc_dq_en        ),
	.hbc_dq_out_hi   	( hbc_dq_out_hi    ),
	.hbc_dq_out_lo   	( hbc_dq_out_lo    ),
	.hbc_dq_in_hi    	( hbc_dq_in_hi     ),
	.hbc_dq_in_lo    	( hbc_dq_in_lo     ),
	.hbc_rwds_en     	( hbc_rwds_en      ),
	.hbc_rwds_out_hi 	( hbc_rwds_out_hi  ),
	.hbc_rwds_out_lo 	( hbc_rwds_out_lo  ),
	.hbc_rwds_in_hi  	( hbc_rwds_in_hi   ),
	.hbc_rwds_in_lo  	( hbc_rwds_in_lo   ));

async_fifo #(
	.INPUT_WIDTH       	( 32              ),
	.OUTPUT_WIDTH      	( RD_WIDTH        ),
	.WR_DEPTH          	( RD_wr_DEPTH     ),
	.RD_DEPTH          	( RD_rd_DEPTH     ),
	.MODE              	( "FWFT"    	  ),
	.DIRECTION         	( "MSB"     	  ),
	.ECC_MODE          	( "no_ecc"  	  ),
	.PROG_EMPTY_THRESH 	( 10        	  ),
	.PROG_FULL_THRESH  	( 10        	  ),
	.USE_ADV_FEATURES  	( 16'h0404  	  ))
rd_fifo(
	.reset         	( sys_rst & (~locked)),
	
	.wr_clock      	( clk_out0       ),
	.wr_en         	( ram_rd_valid   ),
	.wr_ready      	(                ),
	.din           	( ram_rd_data    ),
	
	.rd_clock      	( sys_clk        ),
	.rd_en         	( rd_en          ),
	.valid         	( rd_valid       ),
	.dout          	( rd_data        ),
	
	.full          	( rd_full        ),
	.empty         	( rd_empty       ),
	
	.wr_data_count 	( RD_wr_count    ),
	.wr_data_space 	( 			     ),
	.rd_data_count 	( RD_rd_count    ),
	.rd_data_space 	(   			 ),
	
	.almost_full   	(     			 ),
	.almost_empty  	(    			 ),
	.prog_full     	(       		 ),
	.prog_empty    	(       		 ),
	.overflow      	(        		 ),
	.underflow     	(        		 ),
	.wr_ack        	(         		 ),
	.sbiterr       	(         		 ),
	.dbiterr       	(         		 ));

EFX_GPIO_model #(
	.BUS_WIDTH   (1     	  ), // define ddio bus width
	.TYPE        ("OUT" 	  ), // "IN"=input "OUT"=output "INOUT"=inout
	.OUT_REG     (1     	  ), // 1: enable 0: disable
	.OUT_DDIO    (0     	  ), // 1: enable 0: disable
	.OUT_RESYNC  (0     	  ), // 1: enable 0: disable
	.OUTCLK_INV  (0     	  ), // 1: enable 0: disable
	.OE_REG      (0     	  ), // 1: enable 0: disable
	.IN_REG      (0     	  ), // 1: enable 0: disable
	.IN_DDIO     (0     	  ), // 1: enable 0: disable
	.IN_RESYNC   (0     	  ), // 1: enable 0: disable
	.INCLK_INV   (0     	  )  // 1: enable 0: disable
) cs_n_inst (
	.out_HI      (hbc_cs_n    ), // tx HI data input from internal logic
	.out_LO      (1'b0 	      ), // tx LO data input from internal logic
	.outclk      (clk_out0    ), // tx data clk input from internal logic
	.oe          (1'b1        ), // tx data output enable from internal logic
	.in_HI       (            ), // rx HI data output to internal logic
	.in_LO       (            ), // rx LO data output to internal logic
	.inclk       (1'b0        ), // rx data clk input from internal logic
	.io          (ram_cs_n    )  // outside io signal
);

//CK_P
EFX_GPIO_model #(
	.BUS_WIDTH   (1     	  ), 
	.TYPE        ("OUT" 	  ), 
	.OUT_REG     (1     	  ), 
	.OUT_DDIO    (1     	  ), 
	.OUT_RESYNC  (0     	  ), 
	.OUTCLK_INV  (1     	  ), 
	.OE_REG      (0     	  ), 
	.IN_REG      (0     	  ), 
	.IN_DDIO     (0     	  ), 
	.IN_RESYNC   (0     	  ), 
	.INCLK_INV   (0     	  )  
) ck_p_inst (
	.out_HI      (hbc_ck_p_hi ), 
	.out_LO      (hbc_ck_p_lo ), 
	.outclk      (clk_out90   ), 
	.oe          (1'b1        ), 
	.in_HI       (            ), 
	.in_LO       (            ), 
	.inclk       (1'b0        ), 
	.io          (ram_ck_p    ));

//CK_N
EFX_GPIO_model #(
	.BUS_WIDTH   (1           ), 
	.TYPE        ("OUT"       ), 
	.OUT_REG     (1           ), 
	.OUT_DDIO    (1           ), 
	.OUT_RESYNC  (0           ), 
	.OUTCLK_INV  (1           ), 
	.OE_REG      (0           ), 
	.IN_REG      (0           ), 
	.IN_DDIO     (0           ), 
	.IN_RESYNC   (0           ), 
	.INCLK_INV   (0           )  
) ck_n_inst (
	.out_HI      (hbc_ck_n_hi ), 
	.out_LO      (hbc_ck_n_lo ), 
	.outclk      (clk_out90   ), 
	.oe          (1'b1        ), 
	.in_HI       (            ), 
	.in_LO       (            ), 
	.inclk       (1'b0        ), 
	.io          (ram_ck_n    ));

//RWDS
EFX_GPIO_model #(
	.BUS_WIDTH   (2			  ), 
	.TYPE        ("INOUT"     ), 
	.OUT_REG     (1           ), 
	.OUT_DDIO    (1           ), 
	.OUT_RESYNC  (0           ), 
	.OUTCLK_INV  (0           ), 
	.OE_REG      (1           ), 
	.IN_REG      (1           ), 
	.IN_DDIO     (1           ), 
	.IN_RESYNC   (1           ), 
	.INCLK_INV   (0           )  
) rwds_inst (
	.out_HI      (hbc_rwds_out_hi), 
	.out_LO      (hbc_rwds_out_lo), 
	.outclk      (clk_out0       ), 
	.oe          (hbc_rwds_en[0] ), 
	.in_HI       (hbc_rwds_in_hi ), 
	.in_LO       (hbc_rwds_in_lo ), 
	.inclk       (clk_out0       ), 
	.io          (ram_rwds       ));

//DQ
EFX_GPIO_model #(
	.BUS_WIDTH   (16         ), 
	.TYPE        ("INOUT"    ), 
	.OUT_REG     (1          ), 
	.OUT_DDIO    (1          ), 
	.OUT_RESYNC  (0          ), 
	.OUTCLK_INV  (1          ), 
	.OE_REG      (1          ), 
	.IN_REG      (1          ), 
	.IN_DDIO     (1          ), 
	.IN_RESYNC   (1          ), 
	.INCLK_INV   (0          )  
) dq_inst (
	.out_HI      (hbc_dq_out_hi ), 
	.out_LO      (hbc_dq_out_lo ), 
	.outclk      (clk_out0      ), 
	.oe          (hbc_dq_en[0]  ), 
	.in_HI       (hbc_dq_in_hi  ), 
	.in_LO       (hbc_dq_in_lo  ), 
	.inclk       (clk_out0      ), 
	.io          (ram_dq        ));

W958D6NKY ram_x16_inst(
	.adq	(ram_dq		), 		
    .clk	(ram_ck_p   ),		
    .clk_n	(1'b0		),      
    .csb	(ram_cs_n 	),		
    .rwds	(ram_rwds   ),        
    .VCC	(1'b1		),
    .VSS	(1'b0		),
    .resetb	(ram_rst_n	),
    .die_stack	(1'b0	),
    .optddp	(1'b0		));

initial begin            
    $dumpfile("wave.vcd");        
    $dumpvars(0, tb_hbram);    
    #5000000 $finish;
end

endmodule  //TOP
