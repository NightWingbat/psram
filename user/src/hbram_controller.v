`timescale 1 ns / 1 ns

/*
*   Date : 2024-12-09
*   Author : cjh
*   Module Name:   hyper_bus.v - hyper_bus
*   Target Device: [Target FPGA and ASIC Device]
*   Tool versions: vivado 18.3 & DC 2016
*   Revision Historyc :
*   Revision :
*       Revision 0.01 - File Created
*   Description : The synchronous dual-port SRAM has A, B ports to access the same memory location. 
*                 Both ports can be independently read or written from the memory array.
*                 1. In Vivado, EDA can directly use BRAM for synthesis.
*                 2. The module continuously outputs data when enabled, and when disabled, 
*                    it outputs the last data.
*                 3. When writing data to the same address on ports A and B simultaneously, 
*                    the write operation from port B will take precedence.
*                 4. In write mode, the current data input takes precedence for writing, 
*                    and the data from the address input at the previous clock cycle is read out. 
*                    In read mode, the data from the address input at the current clock cycle 
*                    is directly read out. In write mode, when writing to different addresses, 
*                    the data corresponding to the current address input at the current clock cycle 
*                    is directly read out.
*   Dependencies: none(FPGA) auto for BRAM in vivado | RAM_IP with IC 
*   Company : ncai Technology .Inc
*   Copyright(c) 1999, ncai Technology Inc, All right reserved
*/

// wavedom
/*
{signal: [
  {name: 'clka/b', wave: '101010101'},
  {name: 'ena/b', wave: '01...0...'},
  {name: 'wea/b', wave: '01...0...'},
  {name: 'addra/b', wave: 'x3...3.x.', data: ['addr0','addr2']},
  {name: 'dina/b', wave: 'x4.4.x...', data: ['data0','data1']},
  {name: 'douta/b', wave: 'x..5.5.x.', data: ['data0','data2']},
]}
*/
module hbram_controller #(
    //Hyper_ram drive clock frequency
    parameter HBRAM_FRE   = 200_000_000,
    //Hyper_ram data width
    parameter BIT_WIDTH   = 16,
    //Hyper_ram initialization data number
    parameter INIT_NUM    = 256,
    //Hyper_ram initial latency count
    parameter LATENCY     = 7,
    //Hyper_ram output drive strength
    parameter STRENGTH    = "34_ohms",
    //Hyper_ram burst write or read mode
    parameter BURST_MODE  = "legacy",
    //Hyper_ram burst write or read length
    parameter BURST_LEN   = 16,
    //Hyper_ram partial array refresh
    parameter REFRESH     = "Full_Array",
    //Clock type
    parameter CLOCK_TYPE  = "Single_Ended",
    //Write Data Width
    parameter WR_WIDTH    = 32,
    //Write FIFO Depth
    parameter WR_DEPTH    = 128,
    //Read Data Width
    parameter RD_WIDTH    = 32,
    //Read FIFO Depth
    parameter RD_DEPTH    = 128,
    //Read Mode
    parameter RD_MODE     = "Standard",
    //
    parameter DIRECTION   = "MSB"
) (

    //User Write Port

    //Write FIFO Clock
    input                              native_wr_clock,
    //Write FIFO enable active high
    input                              native_wr_en,
    //Write FIFO data input
    input   [WR_WIDTH - 1 : 0]         native_wr_data,
    //Write FIFO is ready to receive data
    output                             native_wr_buf_ready,
    //Write FIFO is full
    output                             native_wr_full,
    //Write FIFO num of the input data
    output  [$clog2(WR_DEPTH) : 0]     native_wr_count,


    //User Read Port

    //Read FIFO Clock
    input                              native_rd_clock,
    //Read FIFO enable active high
    input                              native_rd_en,
    //Read FIFO rd_data valid active high
    output                             native_rd_valid,
    //Read FIFO read data
    output  [RD_WIDTH - 1 : 0]         native_rd_data,
    //Read FIFO is empty
    output                             native_rd_empty,
    //Read FIFO num of the output data
    output  [$clog2(RD_DEPTH) : 0]     native_rd_count,

    //User Control Port

    //Hyper_ram controller system clock
    input                              ram_clock,
    //Hyper_ram controller system clock shift 90°
    input                              ram_clock_p,
    //Hyper_ram controller system reset active high
    input                              ram_reset,
    //When ram_en is high,start one hyper_ram read/write
    input                              native_ram_en,
    //1: hyper_ram read  0: hyper_ram write
    input                              native_rw_ctrl,
    //the hyper_ram starting read or write address
    input   [31:0]                     native_ram_address,
    //write: WR_DEPTH must be bigger than burst_len   read: RFIFO_WR_DEPTH must be bigger than burst_len
    input   [10:0]                     native_ram_burst_len,
    //
    input   [WR_WIDTH/8 - 1 : 0]       native_wr_datamask,
    //the initialization of hyper_ram is done,can write or read hyper_ram 
    output                             hbc_cal_pass,
    //When low,the hyper_ram is being read or written
    output                             native_ctrl_idle,

    //Phy Port

    //hyper_ram phy positive clock high 
    output                             hbc_ck_p_hi,
    //hyper_ram phy positive clock low
    output                             hbc_ck_p_lo,
    //hyper_ram phy negative clock high
    output                             hbc_ck_n_hi,
    //hyper_ram phy negative clock low
    output                             hbc_ck_n_lo,
    //hyper_ram chip select
    output                             hbc_cs_n,
    //hyper_ram reset signal
    output                             hbc_rst_n,
    //hyper_ram dq out enable
    output  [BIT_WIDTH - 1 : 0]        hbc_dq_en,
    //hyper_ram dq out for command,address and data high
    output  [BIT_WIDTH - 1 : 0]        hbc_dq_out_hi,
    //hyper_ram dq out for command,address and data low
    output  [BIT_WIDTH - 1 : 0]        hbc_dq_out_lo,
    //hyper_ram dq in for data
    input   [BIT_WIDTH - 1 : 0]        hbc_dq_in_hi,
    //hyper_ram dq in for data
    input   [BIT_WIDTH - 1 : 0]        hbc_dq_in_lo,
    //hyper_ram rwds out enable
    output  [BIT_WIDTH/8 - 1 : 0]      hbc_rwds_en,
    //hyper_ram rwds out ports for data mask during write operation high
    output  [BIT_WIDTH/8 - 1 : 0]      hbc_rwds_out_hi,
    //hyper_ram rwds out ports for data mask during write operation low
    output  [BIT_WIDTH/8 - 1 : 0]      hbc_rwds_out_lo,
    //hyper_ram rwds in ports for latency indication, also center-aligned reference strobe for read data high
    input   [BIT_WIDTH/8 - 1 : 0]      hbc_rwds_in_hi,
    //hyper_ram rwds in ports for latency indication, also center-aligned reference strobe for read data low
    input   [BIT_WIDTH/8 - 1 : 0]      hbc_rwds_in_lo
);

localparam                   MASK_WIDTH      = WR_WIDTH/8;
localparam                   WFIFO_RD_DEPTH  = (WR_WIDTH >= 32) ? (WR_WIDTH/32) * WR_DEPTH : (32/WR_WIDTH) * WR_DEPTH;
localparam                   RFIFO_WR_DEPTH  = (RD_WIDTH >= 32) ? (RD_WIDTH/32) * RD_DEPTH : (32/RD_WIDTH) * RD_DEPTH;
localparam                   FIFO_WIDTH      = (WR_WIDTH >= BIT_WIDTH) ? (WR_WIDTH/BIT_WIDTH) : (BIT_WIDTH/WR_WIDTH);

wire                         ram_wr_valid;      //high:now the data in fifo can be written into hyper_ram
wire [31:0]                  ram_wr_data;       //the hyper_ram write data from write fifo
wire                   	     ram_rd_valid;      //high:the hyper_ram read data is valid
wire [BIT_WIDTH * 2 - 1 : 0] ram_rd_data;       //the hyper_ram read data

wire [31:0]                  ram_burst_len;

assign                       ram_burst_len = (native_ram_burst_len * FIFO_WIDTH);

async_fifo #(
	.INPUT_WIDTH       	( WR_WIDTH        ),
	.OUTPUT_WIDTH      	( 32              ),
	.WR_DEPTH          	( WR_DEPTH        ),
	.RD_DEPTH          	( WFIFO_RD_DEPTH  ),
	.MODE              	( "FWFT"          ),
	.DIRECTION         	( DIRECTION       ),
	.ECC_MODE          	( "no_ecc"        ),
	.PROG_EMPTY_THRESH 	( 10              ),
	.PROG_FULL_THRESH  	( 10              ),
	.USE_ADV_FEATURES  	( 16'h0404        ))
u_wr_fifo(
	.reset         	( ram_reset           ),
	
    .wr_clock      	( native_wr_clock     ),
	.wr_en         	( native_wr_en        ),
	.wr_ready      	( native_wr_buf_ready ),
	.din           	( native_wr_data      ),
	
    .rd_clock      	( ram_clock           ),
	.rd_en         	( ram_wr_valid        ),
	.valid         	(                     ),
	.dout          	( ram_wr_data         ),
	
    .full          	( native_wr_full      ),
	.empty         	(                     ),
	
    .wr_data_count 	( native_wr_count     ),
	.wr_data_space 	(                     ),
	.rd_data_count 	(                     ),
	.rd_data_space 	(                     ),
	
    .almost_full   	(                     ),
	.almost_empty  	(                     ),
	.prog_full     	(                     ),
	.prog_empty    	(                     ),
	.overflow      	(                     ),
	.underflow     	(                     ),
	.wr_ack        	(                     ),
	.sbiterr       	(                     ),
	.dbiterr       	(                     )
);

hyper_bus #(
	.HBRAM_FRE  	( HBRAM_FRE                ),
	.BIT_WIDTH  	( BIT_WIDTH                ),
	.INIT_NUM   	( INIT_NUM                 ),
	.LATENCY    	( LATENCY                  ),
	.STRENGTH   	( STRENGTH                 ),
	.BURST_MODE 	( BURST_MODE               ),
	.BURST_LEN  	( BURST_LEN                ),
	.REFRESH    	( REFRESH                  ),
	.CLOCK_TYPE 	( CLOCK_TYPE               ),
	.MASK_WIDTH 	( MASK_WIDTH               ))
u_hyper_bus(
	.ram_clock       	( ram_clock            ),
	.ram_clock_p     	( ram_clock_p          ),
	.ram_reset       	( ram_reset            ),
	
    .ram_en          	( native_ram_en        ),
	.rw_ctrl         	( native_rw_ctrl       ),
	.ram_addr        	( native_ram_address   ),
	.ram_burst_len   	( ram_burst_len        ),
	
    .ram_wr_valid    	( ram_wr_valid         ),
	.ram_wr_data     	( ram_wr_data          ),
	   
    .ram_rd_valid    	( ram_rd_valid         ),
	.ram_rd_data     	( ram_rd_data          ),
	.ram_data_mask   	( native_wr_datamask   ),
	   
    .hbc_cal_pass    	( hbc_cal_pass         ),
	.ctrl_idle       	( native_ctrl_idle     ),
	   
    .hbc_ck_p_hi     	( hbc_ck_p_hi          ),
	.hbc_ck_p_lo     	( hbc_ck_p_lo          ),
	.hbc_ck_n_hi     	( hbc_ck_n_hi          ),
	.hbc_ck_n_lo     	( hbc_ck_n_lo          ),
	.hbc_cs_n        	( hbc_cs_n             ),
	.hbc_rst_n       	( hbc_rst_n            ),
	.hbc_dq_en       	( hbc_dq_en            ),
	.hbc_dq_out_hi   	( hbc_dq_out_hi        ),
	.hbc_dq_out_lo   	( hbc_dq_out_lo        ),
	.hbc_dq_in_hi    	( hbc_dq_in_hi         ),
	.hbc_dq_in_lo    	( hbc_dq_in_lo         ),
	.hbc_rwds_en     	( hbc_rwds_en          ),
	.hbc_rwds_out_hi 	( hbc_rwds_out_hi      ),
	.hbc_rwds_out_lo 	( hbc_rwds_out_lo      ),
	.hbc_rwds_in_hi  	( hbc_rwds_in_hi       ),
	.hbc_rwds_in_lo  	( hbc_rwds_in_lo       )
);

async_fifo #(
	.INPUT_WIDTH       	( 32              ),
	.OUTPUT_WIDTH      	( RD_WIDTH        ),
	.WR_DEPTH          	( RFIFO_WR_DEPTH  ),
	.RD_DEPTH          	( RD_DEPTH        ),
	.MODE              	( RD_MODE         ),
	.DIRECTION         	( DIRECTION       ),
	.ECC_MODE          	( "no_ecc"        ),
	.PROG_EMPTY_THRESH 	( 10              ),
	.PROG_FULL_THRESH  	( 10              ),
	.USE_ADV_FEATURES  	( 16'h0404        ))
u_rd_fifo(
	.reset         	( ram_reset           ),
	
    .wr_clock      	( ram_clock           ),
	.wr_en         	( ram_rd_valid        ),
	.wr_ready      	(                     ),
	.din           	( ram_rd_data         ),
	
    .rd_clock      	( native_rd_clock     ),
	.rd_en         	( native_rd_en        ),
	.valid         	( native_rd_valid     ),
	.dout          	( native_rd_data      ),

    .full          	(                     ),
	.empty         	( native_rd_empty     ),

    .wr_data_count 	(                     ),
	.wr_data_space 	(                     ),
	.rd_data_count 	( native_rd_count     ),
	.rd_data_space 	(                     ),
	
    .almost_full   	(                     ),
	.almost_empty  	(                     ),
	.prog_full     	(                     ),
	.prog_empty    	(                     ),
	.overflow      	(                     ),
	.underflow     	(                     ),
	.wr_ack        	(                     ),
	.sbiterr       	(                     ),
	.dbiterr       	(                     )
);

endmodule
