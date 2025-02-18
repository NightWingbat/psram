module hbram_test #(
    //The parameter for clock idle state level
    parameter    CPOL              = 1, 
    //The parameter for clock phase
    parameter    CPHA              = 1, 
    //chip selection enable level
    parameter    CE_LEVEL          = 0, 
    //The width parameter for register control
    parameter    CTRL_WIDTH        = 8,
    //The width parameter for register address
    parameter    ADDR_WIDTH        = 8,
    //The width parameter for writing or receiving data
    parameter    DATA_WIDTH        = 8,
    //Burst read or write length
    parameter    LEN_WIDTH         = 11,
    //SPI write command
    parameter    CTRL_WRITE        = 8'h3a, 
    //SPI read  command
    parameter    CTRL_READ         = 8'h3b 
) (
    //internal oscillator
    input         intosc_clkout,
    output        intosc_en,
    //hyperram clock
    input         ram_clk,
    input         ram_clk_cal,
    //spi and fifo clock
    input         native_clk,
    input         locked,
    //PLL Phase setting
    output [2:0]  hbc_cal_SHIFT,
    output [4:0]  hbc_cal_SHIFT_SEL,
    output        hbc_cal_SHIFT_ENA,
    output        sysClk_pll_rstn,
    output        hbramClk_pll_rstn,
    //hyperram_phy
    output        hbc_rst_n,
    output        hbc_cs_n,
    output        hbc_ck_p_HI,
    output        hbc_ck_p_LO,
    output        hbc_ck_n_HI,
    output        hbc_ck_n_LO,
    output [1:0]  hbc_rwds_OUT_HI,
    output [1:0]  hbc_rwds_OUT_LO,
    input  [1:0]  hbc_rwds_IN_HI,
    input  [1:0]  hbc_rwds_IN_LO,
    input  [15:0] hbc_dq_IN_LO,
    input  [15:0] hbc_dq_IN_HI,
    output [15:0] hbc_dq_OUT_HI,
    output [15:0] hbc_dq_OUT_LO,
    output [15:0] hbc_dq_OE,
    output [1:0]  hbc_rwds_OE,
    //spi_phy
    input         sclk,
    input         ce,
    input         mosi,
    output        miso
);

//Hyperram complete signal
wire                            hbc_cal_pass;

//SPI control and address signal
wire                            spi_done;
wire [CTRL_WIDTH-1:0] 	        spi_ctrl;
wire [ADDR_WIDTH-1:0] 	        spi_address;

//SPI Data Write
wire  [DATA_WIDTH-1:0]	        slave_rx_data;            

//SPI Data Read
wire					        slave_tx_en;
wire					        slave_tx_valid;
wire  [DATA_WIDTH-1:0]	        slave_tx_data;

//Hyperram
wire         	                native_ram_en;
wire         	                native_ram_rdwr;
wire [31:0] 	                native_ram_address;
wire [10:0] 	                native_ram_burst_len = 11'd64;
wire                            native_ctrl_idle;

//Hyperram Date Write
wire         	                native_wr_en;
wire [31:0] 	                native_wr_data = {24'd0,slave_rx_data};
wire                            native_wr_buf_ready;
wire [3:0]  	                native_wr_datamask = 4'hf;

//Hyperram Date Read
wire                            native_rd_valid;
wire [31:0]                     native_rd_data;

//Hyperram PLL_Phase
wire                            dyn_pll_phase_en;
wire                            dyn_pll_phase_sel;

//fifo empty and full signal
wire                            full;
wire                            empty;

reg								r_full;

//wait_cnt
reg  [9:0]						wr_wait_cnt;
reg  [9:0]						ram_wait_cnt;

reg								ctrl_idle_d1;
wire							ctrl_idle_pos;

assign                          intosc_en         = 1'b1;
assign                          hbramClk_pll_rstn = 1'b1;
assign                          sysClk_pll_rstn   = 1'b1;

assign                          dyn_pll_phase_en  = 1'b1;
assign                          dyn_pll_phase_sel = 3'b010;

assign                          hbc_cal_SHIFT_ENA = 1'b1;
assign                          hbc_cal_SHIFT_SEL = 5'b00010;
assign                          hbc_cal_SHIFT     = 3'b011;

hbram_ctrl #(
	.CTRL_WIDTH 	( CTRL_WIDTH        ),
	.ADDR_WIDTH 	( ADDR_WIDTH        ),
	.CTRL_WRITE 	( CTRL_WRITE        ),
	.CTRL_READ  	( CTRL_READ         ))
u_hbram_ctrl(
	.clock        	( native_clk                ),
	.reset        	( ~locked                   ),
	.hbc_cal_pass 	( hbc_cal_pass			    ),
	.spi_done     	( spi_done                  ),
	.ctrl         	( spi_ctrl                  ),
	.address      	( spi_address               ),
    .burst_len      ( native_ram_burst_len      ),
	.ram_idle     	( native_ctrl_idle          ),
	.ram_en       	( native_ram_en             ),
	.ram_addr     	( native_ram_address        ),
	.ram_rdwr     	( native_ram_rdwr           ));

hbram_controller #(
	.HBRAM_FRE  	( 200_000_000    ),
	.BIT_WIDTH  	( 16             ),
	.INIT_NUM   	( 1024           ),
	.LATENCY    	( 7              ),
	.STRENGTH   	( "34_ohms"      ),
	.BURST_MODE 	( "legacy"       ),
	.BURST_LEN  	( 32             ),
	.REFRESH    	( "Full_Array"   ),
	.CLOCK_TYPE 	( "Single_Ended" ),
	.WR_WIDTH   	( 32             ),
	.WR_DEPTH   	( 256            ),
	.RD_WIDTH   	( 32             ),
	.RD_DEPTH   	( 256            ),
	.RD_MODE    	( "Standard"     ),
	.DIRECTION  	( "MSB"          ))
u_hbram_controller(
	.native_wr_clock      	( native_clk            ),
	.native_wr_en         	( native_wr_en          ),
	.native_wr_data       	( native_wr_data        ),
	.native_wr_buf_ready  	( native_wr_buf_ready   ),
	.native_wr_full       	( full                  ),
	.native_wr_count      	(                       ),
	
    .native_rd_clock      	( native_clk            ),
	.native_rd_en         	( slave_tx_en           ),
	.native_rd_valid      	( native_rd_valid       ),
	.native_rd_data       	( native_rd_data        ),
	.native_rd_empty      	( empty                 ),
	.native_rd_count      	(                       ),
	
    .ram_clock            	( ram_clk               ),
	.ram_clock_p          	( ram_clk_cal           ),
	.ram_reset            	( ~locked               ),
	
    .native_ram_en        	( native_ram_en         ),
	.native_rw_ctrl       	( native_ram_rdwr       ),
	.native_ram_address   	( native_ram_address    ),
	.native_ram_burst_len 	( native_ram_burst_len  ),
	.native_wr_datamask   	( native_wr_datamask    ),
	.hbc_cal_pass         	( hbc_cal_pass          ),
	.native_ctrl_idle     	( native_ctrl_idle      ),
	
    .hbc_ck_p_hi          	( hbc_ck_p_HI           ),
	.hbc_ck_p_lo          	( hbc_ck_p_LO           ),
	.hbc_ck_n_hi          	( hbc_ck_n_HI           ),
	.hbc_ck_n_lo          	( hbc_ck_n_LO           ),
	.hbc_cs_n             	( hbc_cs_n              ),
	.hbc_rst_n            	( hbc_rst_n             ),
	.hbc_dq_en            	( hbc_dq_OE             ),
	.hbc_dq_out_hi        	( hbc_dq_OUT_HI         ),
	.hbc_dq_out_lo        	( hbc_dq_OUT_LO         ),
	.hbc_dq_in_hi         	( hbc_dq_IN_HI          ),
	.hbc_dq_in_lo         	( hbc_dq_IN_LO          ),
	.hbc_rwds_en          	( hbc_rwds_OE           ),
	.hbc_rwds_out_hi      	( hbc_rwds_OUT_HI       ),
	.hbc_rwds_out_lo      	( hbc_rwds_OUT_LO       ),
	.hbc_rwds_in_hi       	( hbc_rwds_IN_HI        ),
	.hbc_rwds_in_lo       	( hbc_rwds_IN_LO        )
);

spi_slave #(
	.CPOL       	( CPOL          ),
	.CPHA       	( CPHA          ),
	.CE_LEVEL   	( CE_LEVEL      ),
	.CTRL_WIDTH 	( CTRL_WIDTH    ),
	.ADDR_WIDTH 	( ADDR_WIDTH    ),
	.DATA_WIDTH 	( DATA_WIDTH    ),
	.LEN_WIDTH  	( LEN_WIDTH     ),
	.CTRL_WRITE 	( CTRL_WRITE    ),
	.CTRL_READ  	( CTRL_READ     ))
u_spi_slave(
	.clock        	( native_clk    ),
	.reset        	( ~locked       ),
	
    .hbc_cal_pass 	( hbc_cal_pass	),
	.burst_len    	( 11'd16        ),
	.ctrl         	( spi_ctrl      ),
	.address      	( spi_address   ),
	
    .tx_en        	( slave_tx_en   ),
	.tx_valid     	( native_rd_valid),
	.tx_data      	( native_rd_data[7:0] ),
	
    .rx_en        	( native_wr_en  ),
	.rx_data      	( slave_rx_data ),
	
    .spi_done     	( spi_done      ),
	
    .sclk         	( sclk          ),
	.ce           	( ce            ),
	.mosi         	( mosi          ),
	.miso         	( miso          ));

endmodule  //hbram_loop
