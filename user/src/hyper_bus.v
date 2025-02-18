`timescale 1 ns / 1 ns

/*
*   Date : 2024-11-18
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
module hyper_bus #(
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
    //Mask Data Width
    parameter MASK_WIDTH  = 4
) (
    //User Port

    //Hyper_ram controller system clock
    input                              ram_clock,
    //Hyper_ram controller system clock shift 90°
    input                              ram_clock_p,
    //Hyper_ram controller system reset active high
    input                              ram_reset,
    //When ram_en is high,start one hyper_ram read/write
    input                              ram_en,
    //1: hyper_ram read  0: hyper_ram write
    input                              rw_ctrl,
    //the hyper_ram starting read or write address
    input      [31:0]                  ram_addr,
    //the hyper_ram burst write or read data length
    input      [31:0]                  ram_burst_len,
    //high:now the data in fifo can be written into hyper_ram
    output                             ram_wr_valid,
    //the hyper_ram write data
    input      [BIT_WIDTH * 2 - 1 : 0] ram_wr_data,
    //high:the hyper_ram read data is valid
    output reg                         ram_rd_valid,
    //the hyper_ram read data
    output reg [BIT_WIDTH * 2 - 1 : 0] ram_rd_data,
    //data mask
    input      [MASK_WIDTH - 1 : 0]    ram_data_mask,
    //the initialization of hyper_ram is done,can write or read hyper_ram 
    output  reg                        hbc_cal_pass,
    //When low,the hyper_ram is being read or written
    output  reg                        ctrl_idle,

    //PHY Port

    //hyper_ram phy positive clock high 
    output  reg                        hbc_ck_p_hi,
    //hyper_ram phy positive clock low
    output                             hbc_ck_p_lo,
    //hyper_ram phy negative clock high
    output                             hbc_ck_n_hi,
    //hyper_ram phy negative clock low
    output                             hbc_ck_n_lo,
    //hyper_ram chip select
    output  reg                        hbc_cs_n,
    //hyper_ram reset signal
    output  reg                        hbc_rst_n,
    //hyper_ram dq out enable
    output reg [BIT_WIDTH - 1 : 0]     hbc_dq_en,
    //hyper_ram dq out for command,address and data high
    output reg [BIT_WIDTH - 1 : 0]     hbc_dq_out_hi,
    //hyper_ram dq out for command,address and data low
    output reg [BIT_WIDTH - 1 : 0]     hbc_dq_out_lo,
    //hyper_ram dq in for data
    input      [BIT_WIDTH - 1 : 0]     hbc_dq_in_hi,
    //hyper_ram dq in for data
    input      [BIT_WIDTH - 1 : 0]     hbc_dq_in_lo,
    //hyper_ram rwds out enable
    output reg [BIT_WIDTH - 1 : 0]     hbc_rwds_en,
    //hyper_ram rwds out ports for data mask during write operation high
    output reg [BIT_WIDTH/8 - 1 : 0]   hbc_rwds_out_hi,
    //hyper_ram rwds out ports for data mask during write operation low
    output reg [BIT_WIDTH/8 - 1 : 0]   hbc_rwds_out_lo,
    //hyper_ram rwds in ports for latency indication, also center-aligned reference strobe for read data high
    input      [BIT_WIDTH/8 - 1 : 0]   hbc_rwds_in_hi,
    //hyper_ram rwds in ports for latency indication, also center-aligned reference strobe for read data low
    input      [BIT_WIDTH/8 - 1 : 0]   hbc_rwds_in_lo
);

localparam                TVCS = ((HBRAM_FRE / 1000) * 160) / 1000;            //The tVCS period is used primarily to perform refresh operations on the DRAM array to initialize it. 
localparam                TRP  = (((HBRAM_FRE / 1000) / 1000) * 200) / 1000;   //RESET Pulse Width
localparam                TRPH = (((HBRAM_FRE / 1000) / 1000) * 400) / 1000;   //RESET TIME
localparam                TRST = ((HBRAM_FRE / 1000) * 3) / 1000;              //after write global reset,wait 3us
localparam                TCPH = ((HBRAM_FRE / 1000) * 2) / 1000;              //after write global reset,wait 2us

localparam                IDLE        = 4'd0;
localparam                RESET       = 4'd1;
localparam                RESET_WAIT  = 4'd2;
localparam                CONFIG_PRE  = 4'd3;
localparam                CONFIG      = 4'd4;
localparam                CONFIG_DONE = 4'd5;
localparam                CONFIG_WAIT = 4'd6;
localparam                WAIT        = 4'd7;
localparam                INIT_PRE    = 4'd8;
localparam                INIT        = 4'd9;
localparam                WRITE       = 4'd10;
localparam                READ        = 4'd11;
localparam                DONE        = 4'd12;

reg                       flag;               //1: the hyper_ram has completed initialization,can write into hyper_ram  0: hyper_ram is initializing

reg  [15:0]               init_cnt;           //the hyper_ram initialize period
reg  [6:0]                rst_cnt;            //the hyper_ram reset period
reg  [15:0]               rst_wait_cnt;       //after reset,need to wait 3us
reg  [3:0]                clk_cnt;            //mark the count of ram_clock
reg  [9:0]                cph_cnt;            //after config registor,write or read,wait tcph
reg  [1:0]                cr_cnt;             //mark the number of written register
reg  [31:0]               data_cnt;           //mark the count of the written or read data 

wire [3:0]                latency_config;     //cr0 register read or write latency config
wire [2:0]                str_config;         //cr0 register read drive strength config
wire                      mode_config;        //cr0 register read or write mode config
wire [1:0]                len_config;         //cr0 register read or write burst length config
wire [2:0]                refresh_config;     //cr1 register array refresh config
wire                      clock_config;       //cr1 register clock type config
wire [7:0]                command_config;
wire [15:0]               cr0_config;         //cr0 register config
wire [15:0]               cr1_config;         //cr1 register config

reg  [31:0]               r_ram_addr;
reg                       r_rw_ctrl;

reg  [MASK_WIDTH - 1 : 0] r_data_mask;
wire [MASK_WIDTH - 1 : 0] read_data_mask;

reg  [BIT_WIDTH/8 - 1 : 0]r_hbc_rwds_in_hi;
reg  [BIT_WIDTH - 1 : 0]  r_hbc_dq_in_hi;

reg  [3:0]                state_now;
reg  [3:0]                state_next;

assign                    command_config = {r_rw_ctrl,1'b0,mode_config,r_ram_addr[31:27]};
assign                    cr0_config     = {1'b1,str_config,4'hf,latency_config,1'b1,mode_config,len_config};
assign                    cr1_config     = {8'hff,1'b1,clock_config,1'b0,refresh_config,2'b01};
assign                    read_data_mask = ~r_data_mask;

//flag
always @(posedge ram_clock or posedge ram_reset) begin
    if(ram_reset == 1'b1)begin
        flag <= 1'b0;
    end
    else if(state_now == DONE)begin
        flag <= 1'b1;
    end
    else begin
        flag <= flag;
    end
end

//When starting to read and write, store the address
always @(posedge ram_clock or posedge ram_reset) begin
    if(ram_reset == 1'b1)begin
        r_rw_ctrl <= 1'b0;
    end
    else if(ram_en)begin
        r_rw_ctrl <= rw_ctrl;
    end
    else begin
        r_rw_ctrl <= r_rw_ctrl;
    end
end

//When starting to read and write, store the read or write control signal
always @(posedge ram_clock or posedge ram_reset) begin
    if(ram_reset == 1'b1)begin
        r_ram_addr <= 1'b0;
    end
    else if(ram_en)begin
        r_ram_addr <= ram_addr;
    end
    else begin
        r_ram_addr <= r_ram_addr;
    end
end

//config hyper_ram initial latency
generate
    case (LATENCY)
        3 : begin : three_delay
            assign latency_config = 4'b1110;
        end
        4 : begin : four_delay
            assign latency_config = 4'b1111;
        end
        5 : begin : five_delay
            assign latency_config = 4'b0000;
        end
        6 : begin : six_delay
            assign latency_config = 4'b0001;
        end
        7 : begin : seven_delay
            assign latency_config = 4'b0010;
        end
        default : begin
            assign latency_config = 4'b0010;
        end
endcase
endgenerate

//config hyper_ram drive strength
generate
    case (STRENGTH)
        "34_ohms"  : begin : Drive_34_ohms
            assign str_config = 3'b000;
        end
        "115_ohms" : begin : Drive_115_ohms
            assign str_config = 3'b001;
        end
        "67_ohms"  : begin : Drive_67_ohms
            assign str_config = 3'b010;
        end
        "46_ohms"  : begin : Drive_46_ohms
            assign str_config = 3'b011;
        end
        "27_ohms"  : begin : Drive_27_ohms
            assign str_config = 3'b101;
        end
        "22_ohms"  : begin : Drive_22_ohms
            assign str_config = 3'b110;
        end
        "19_ohms"  : begin : Drive_19_ohms
            assign str_config = 3'b111;
        end
        default    : begin
            assign str_config = 3'b000;
        end
endcase
endgenerate

//config hyper_ram burst write or read mode
generate
    case (BURST_MODE)
        "legacy" : begin : legacy_burst_mode
            assign mode_config = 1'b1;
        end
        "hybrid" : begin : hybrid_burst_mode
            assign mode_config = 1'b0;
        end
        default : begin
            assign mode_config = 1'b1;
        end
    endcase
endgenerate

//config hyper_ram burst write or read length
generate
    case (BURST_LEN)
        16  : begin : length_16
            assign len_config = 2'b10;
        end
        32  : begin : length_32
            assign len_config = 2'b11;
        end
        64  : begin : length_64
            assign len_config = 2'b01;
        end
        128 : begin : length_128
            assign len_config = 2'b00;
        end
        default : begin : NOP end
endcase
endgenerate

//config hyper_ram partial array refresh
generate
    case (REFRESH)
        "Full_Array" : begin : FULL_ARRAY
            assign refresh_config = 3'b000;
        end
        "Bottom_1_2_Array" : begin : BOTTOM_1_2_ARRAY
            assign refresh_config = 3'b001;
        end
        "Bottom_1_4_Array" : begin : BOTTOM_1_4_ARRAY
            assign refresh_config = 3'b010;
        end
        "Bottom_1_8_Arrray" : begin : BOTTOM_1_8_ARRAY
            assign refresh_config = 3'b011;
        end
        "None" : begin : NONE
            assign refresh_config = 3'b100;
        end
        "Top_1_2_Array" : begin : TOP_1_2_ARRAY
            assign refresh_config = 3'b101;
        end
        "Top_1_4_Array" : begin : TOP_1_4_ARRAY
            assign refresh_config = 3'b110;
        end
        "Top_1_8_Array" : begin : TOP_1_8_ARRAY
            assign refresh_config = 3'b111;
        end
        default : begin
            assign refresh_config = 3'b000;
        end
endcase
endgenerate

//Clock Type
generate
    case (CLOCK_TYPE)
        "legacy" : begin : Singal_Ended_Config
            assign clock_config = 1'b1;
        end
        "hybrid" : begin : Different_Config
            assign clock_config = 1'b0;
        end
        default : begin
            assign mode_config = 1'b1;
        end
    endcase
endgenerate

//mark the time of initialization
always @(posedge ram_clock or posedge ram_reset) begin
    if(ram_reset == 1'b1)begin
        init_cnt <= 16'd0;
    end
    else if(init_cnt < 16'd1000)begin
        init_cnt <= init_cnt + 1'b1;
    end
    else begin
        init_cnt <= init_cnt;
    end
end

//mark the time of reset
always @(posedge ram_clock or posedge ram_reset) begin
    if(ram_reset == 1'b1)begin
        rst_cnt <= 7'd0;
    end
    else if(state_now == RESET)begin
        if(rst_cnt < TRPH - 1)begin
            rst_cnt <= rst_cnt + 1'b1;
        end
        else begin
            rst_cnt <= rst_cnt;
        end
    end
    else begin
        rst_cnt <= rst_cnt;
    end
end

//mark the time of reset wait
always @(posedge ram_clock or posedge ram_reset) begin
    if(ram_reset == 1'b1)begin
        rst_wait_cnt <= 10'd0;
    end
    else if(state_now == RESET_WAIT)begin
        if(rst_wait_cnt < TVCS - 1)begin
            rst_wait_cnt <= rst_wait_cnt + 1'b1;
        end
        else begin
            rst_wait_cnt <= rst_wait_cnt;
        end
    end
    else begin
        rst_wait_cnt <= rst_wait_cnt;
    end
end

//mark the time of ram_clock
always @(posedge ram_clock or posedge ram_reset) begin
    if(ram_reset == 1'b1)begin
        clk_cnt <= 4'd0;
    end
    else if(state_now == CONFIG || state_now == INIT)begin
        clk_cnt <= clk_cnt + 1'b1;
    end
    else begin
        clk_cnt <= 4'd0;
    end
end

//after config registor,write or read,wait tcph
always @(posedge ram_clock or posedge ram_reset) begin
    if(ram_reset == 1'b1)begin
        cph_cnt <= 4'd0;
    end
    else if(state_now == CONFIG_WAIT || state_now == DONE)begin
        if(cph_cnt < TCPH - 1'b1)begin
            cph_cnt <= cph_cnt + 1'b1;
        end
        else begin
            cph_cnt <= cph_cnt;
        end
    end
    else begin
        cph_cnt <= 3'd0;
    end
end

//mark the number of written register
always @(posedge ram_clock or posedge ram_reset) begin
    if(ram_reset == 1'b1)begin
        cr_cnt <= 2'd0;
    end
    else if(state_now == CONFIG_DONE)begin
        cr_cnt <= cr_cnt + 1'b1;
    end
    else begin
        cr_cnt <= cr_cnt;
    end
end

//mark the count of the written or read data
always @(posedge ram_clock or posedge ram_reset) begin
    if(ram_reset == 1'b1)begin
        data_cnt <= 12'd0;
    end
    else if(state_now == WRITE)begin
        data_cnt <= data_cnt + 2'd2;
    end
    else if(state_now == READ)begin
        if(r_hbc_rwds_in_hi[0] ^ hbc_rwds_in_lo[0])begin
            data_cnt <= data_cnt + 2'd2;
        end
        else begin
            data_cnt <= data_cnt;
        end
    end
    else begin
        data_cnt <= 12'd0;
    end
end

//state machine
always @(posedge ram_clock or posedge ram_reset) begin
    if(ram_reset == 1'b1)begin
        state_now <= IDLE;
    end
    else begin
        state_now <= state_next;
    end
end

always @(*) begin
    if(ram_reset == 1'b1)begin
        state_next <= IDLE;
    end
    else begin
        case(state_now)

            IDLE:begin
                if(init_cnt == 16'd1000)begin
                    state_next <= RESET;
                end
                else begin
                    state_next <= IDLE;
                end
            end

            RESET:begin
                if(rst_cnt == TRPH - 1)begin
                    state_next <= RESET_WAIT;
                end
                else begin
                    state_next <= RESET;
                end
            end

            RESET_WAIT:begin
                if(rst_wait_cnt == TVCS - 1)begin
                    state_next <= CONFIG_PRE;
                end
                else begin
                    state_next <= RESET_WAIT;
                end
            end

            CONFIG_PRE:begin
                state_next <= CONFIG;
            end

            CONFIG:begin
                if(clk_cnt == 4'd3)begin
                    state_next <= CONFIG_DONE;
                end
                else begin
                    state_next <= CONFIG;
                end
            end

            CONFIG_DONE:begin
                state_next <= CONFIG_WAIT;
            end

            CONFIG_WAIT:begin
                if(cr_cnt == 2'd2)begin
                    if(cph_cnt == TCPH - 1)begin
                        state_next <= WAIT;
                    end
                    else begin
                        state_next <= CONFIG_WAIT;
                    end
                end
                else begin
                    if(cph_cnt == TCPH - 1)begin
                        state_next <= CONFIG_PRE;
                    end
                    else begin
                        state_next <= CONFIG_WAIT;
                    end
                end
            end

            WAIT:begin
                if(flag == 1'b0)begin
                    state_next <= INIT_PRE;
                end
                else begin
                    if(ram_en)begin
                        state_next <= INIT_PRE;
                    end
                    else begin
                        state_next <= WAIT;
                    end
                end
            end

            INIT_PRE:begin
                state_next <= INIT;
            end

            INIT:begin
                if(flag == 1'b0)begin
                    if(clk_cnt == LATENCY * 2 + 1)begin
                        state_next <= WRITE;
                    end
                    else begin
                        state_next <= INIT;
                    end
                end
                else begin
                    if(clk_cnt == LATENCY * 2 + 1)begin
                        if(r_rw_ctrl)begin
                            state_next <= READ;
                        end
                        else begin
                            state_next <= WRITE;
                        end
                    end
                    else begin
                        state_next <= INIT;
                    end
                end
            end

            WRITE:begin
                if(flag == 1'b0)begin
                    if(data_cnt == INIT_NUM - 2)begin
                        state_next <= DONE;
                    end
                    else begin
                        state_next <= WRITE;
                    end
                end
                else begin
                    if(data_cnt == ram_burst_len - 2)begin
                        state_next <= DONE;
                    end
                    else begin
                        state_next <= WRITE;
                    end
                end
            end

            READ:begin
                if(data_cnt == ram_burst_len - 2)begin
                    state_next <= DONE;
                end
                else begin
                    state_next <= READ;
                end
            end

            DONE:begin
                if(cph_cnt == TCPH - 1'b1)begin
                    state_next <= WAIT;
                end
                else begin
                    state_next <= DONE;
                end
            end

            default:begin
                state_next <= IDLE;
            end
        endcase
    end
end

//hyper_ram phy clock

assign hbc_ck_p_lo = 1'b0;
assign hbc_ck_n_lo = 1'b0;

always @(posedge ram_clock or posedge ram_reset) begin
        if(ram_reset == 1'b1)begin
            hbc_ck_p_hi <= 1'b0;
        end
        else begin
            case(state_now)

                IDLE:begin
                    hbc_ck_p_hi <= 1'b0;
                end

                RESET:begin
                    hbc_ck_p_hi <= 1'b0;
                end

                RESET_WAIT:begin
                    hbc_ck_p_hi <= 1'b0;
                end

                CONFIG_PRE:begin
                    hbc_ck_p_hi <= 1'b0;
                end

                CONFIG_DONE:begin
                    hbc_ck_p_hi <= 1'b0;
                end

                CONFIG_WAIT:begin
                    hbc_ck_p_hi <= 1'b0;
                end

                WAIT:begin
                    hbc_ck_p_hi <= 1'b0;
                end

                INIT_PRE:begin
                    hbc_ck_p_hi <= 1'b0;
                end

                DONE:begin
                    hbc_ck_p_hi <= 1'b0;
                end

                default:begin
                    hbc_ck_p_hi <= 1'b1;
                end

            endcase
        end
    end

generate if(CLOCK_TYPE == "Single_Ended") begin : Single_Ended_Clock
    
    assign hbc_ck_n_hi = 1'b0;

end
endgenerate

generate if(CLOCK_TYPE == "Different") begin : Different_Clock

    assign hbc_ck_n_hi = ~hbc_ck_p_hi;

end
endgenerate

//hbc_cs_n
always @(posedge ram_clock or negedge ram_reset) begin
    if(ram_reset == 1'b1)begin
        hbc_cs_n <= 1'b1;
    end
    else begin
        case(state_now)

            IDLE:begin
                hbc_cs_n <= 1'b1;
            end

            RESET:begin
                hbc_cs_n <= 1'b1;
            end

            RESET_WAIT:begin
                hbc_cs_n <= 1'b1;
            end

            CONFIG_PRE:begin
                hbc_cs_n <= 1'b0;
            end

            CONFIG:begin
                hbc_cs_n <= 1'b0;
            end

            CONFIG_DONE:begin
                hbc_cs_n <= 1'b1;
            end

            CONFIG_WAIT:begin
                hbc_cs_n <= 1'b1;
            end

            WAIT:begin
                hbc_cs_n <= 1'b1;
            end

            INIT_PRE:begin
                hbc_cs_n <= 1'b0;
            end

            INIT:begin
                hbc_cs_n <= 1'b0;
            end

            WRITE:begin
                hbc_cs_n <= 1'b0;
            end

            READ:begin
                hbc_cs_n <= 1'b0;
            end

            DONE:begin
                hbc_cs_n <= 1'b1;
            end

            default:begin
                hbc_cs_n <= 1'b1;
            end

        endcase
    end
end

//hbc_rst_n
always @(posedge ram_clock or posedge ram_reset) begin
    if(ram_reset == 1'b1)begin
        hbc_rst_n <= 1'b1;
    end
    else if(state_now == RESET)begin
        if(rst_cnt <= TRP - 1)begin
            hbc_rst_n <= 1'b0;
        end
        else begin
            hbc_rst_n <= 1'b1;
        end
    end
    else begin
        hbc_rst_n <= 1'b1;
    end
end

//hbc_dq_en
always @(posedge ram_clock or negedge ram_reset) begin
    if(ram_reset == 1'b1)begin
        hbc_dq_en <= {(BIT_WIDTH){1'b0}};
    end
    else begin
        case(state_now)

            RESET:begin
                if(rst_cnt <= TRP - 1)begin
                    hbc_dq_en <= {(BIT_WIDTH){1'b0}};
                end
                else begin
                    hbc_dq_en <= {(BIT_WIDTH){1'b1}};
                end
            end

            INIT:begin
                if(clk_cnt <= 4'd2)begin
                    hbc_dq_en <= {(BIT_WIDTH){1'b1}};
                end
                else begin
                    hbc_dq_en <= {(BIT_WIDTH){1'b0}};
                end
            end

            READ:begin
                hbc_dq_en <= {(BIT_WIDTH){1'b0}};
            end

            DONE:begin
                hbc_dq_en <= {(BIT_WIDTH){1'b0}};
            end

            default:begin
                hbc_dq_en <= {(BIT_WIDTH){1'b1}};
            end
        endcase
    end
end

//hbc_dq_out
always @(posedge ram_clock or posedge ram_reset) begin
    if(ram_reset == 1'b1)begin
        hbc_dq_out_hi <= 0;
        hbc_dq_out_lo <= 0;
    end
    else begin
        case(state_now)

            IDLE:begin
                hbc_dq_out_hi <= 0;
                hbc_dq_out_lo <= 0;
            end

            RESET:begin
                hbc_dq_out_hi <= 0;
                hbc_dq_out_lo <= 0;
            end

            RESET_WAIT:begin
                hbc_dq_out_hi <= 0;
                hbc_dq_out_lo <= 0;
            end

            CONFIG:begin

                case(clk_cnt)

                    4'd0:begin
                        hbc_dq_out_hi <= (BIT_WIDTH == 16) ? 16'h6060 : 8'h60;
                        hbc_dq_out_lo <= 0;
                    end

                    4'd1:begin
                        hbc_dq_out_hi <= (BIT_WIDTH == 16) ? 16'h0101 : 8'h01;
                        hbc_dq_out_lo <= 0;
                    end

                    4'd2:begin
                        hbc_dq_out_hi <= 0;

                        case(cr_cnt)

                            2'd0:begin
                                hbc_dq_out_lo <= 0;
                            end

                            2'd1:begin
                                hbc_dq_out_lo <= (BIT_WIDTH == 16) ? 16'h0101 : 8'h01;
                            end

                            default:begin
                                hbc_dq_out_lo <= 0;
                            end

                        endcase
                    end

                    4'd3:begin

                        case(cr_cnt)

                            2'd0:begin
                                hbc_dq_out_hi <= (BIT_WIDTH == 16) ? {cr0_config[15:8],cr0_config[15:8]} : cr0_config[15:8];
                                hbc_dq_out_lo <= (BIT_WIDTH == 16) ? {cr0_config[7:0],cr0_config[7:0]}  : cr0_config[7:0];
                            end

                            2'd1:begin
                                hbc_dq_out_hi <= (BIT_WIDTH == 16) ? {cr1_config[15:8],cr1_config[15:8]} : cr1_config[15:8];
                                hbc_dq_out_lo <= (BIT_WIDTH == 16) ? {cr1_config[7:0],cr1_config[7:0]}  : cr1_config[7:0];
                            end

                            default:begin
                                hbc_dq_out_lo <= 0;
                            end
                        endcase

                    end

                    default:begin
                        hbc_dq_out_hi <= 0;
                        hbc_dq_out_lo <= 0;
                    end

                endcase

            end

            CONFIG_DONE:begin
                hbc_dq_out_hi <= 0;
                hbc_dq_out_lo <= 0;
            end

            CONFIG_WAIT:begin
                hbc_dq_out_hi <= 0;
                hbc_dq_out_lo <= 0;
            end

            WAIT:begin
                hbc_dq_out_hi <= 0;
                hbc_dq_out_lo <= 0;
            end

            INIT:begin
                case(clk_cnt)
                    4'd0:begin
                        hbc_dq_out_hi <= (BIT_WIDTH == 16) ? {command_config,command_config}       : command_config;
                        hbc_dq_out_lo <= (BIT_WIDTH == 16) ? {r_ram_addr[26:19],r_ram_addr[26:19]} : r_ram_addr[26:19];
                    end
                    4'd1:begin
                        hbc_dq_out_hi <= (BIT_WIDTH == 16) ? {r_ram_addr[18:11],r_ram_addr[18:11]} : r_ram_addr[18:11];
                        hbc_dq_out_lo <= (BIT_WIDTH == 16) ? {r_ram_addr[10:3],r_ram_addr[10:3]}   : r_ram_addr[10:3];
                    end
                    4'd2:begin
                        hbc_dq_out_hi <= (BIT_WIDTH == 16) ? 16'h0000 : 8'h00;
                        hbc_dq_out_lo <= (BIT_WIDTH == 16) ? {5'd0,r_ram_addr[2:0],5'd0,r_ram_addr[2:0]} : {5'd0,r_ram_addr[2:0]};
                    end
                    default:begin
                        hbc_dq_out_hi <= 0;
                        hbc_dq_out_lo <= 0;
                    end
                endcase
            end

            WRITE:begin
                if(flag == 1'b0)begin
                    hbc_dq_out_hi <= 0;
                    hbc_dq_out_lo <= 0;
                end
                else begin
                    hbc_dq_out_hi <= ram_wr_data[BIT_WIDTH * 2 - 1 : BIT_WIDTH];
                    hbc_dq_out_lo <= ram_wr_data[BIT_WIDTH - 1 : 0];
                end
            end

            READ:begin
                hbc_dq_out_hi <= 0;
                hbc_dq_out_lo <= 0;
            end

            DONE:begin
                hbc_dq_out_hi <= 0;
                hbc_dq_out_lo <= 0;
            end

            default:begin
                hbc_dq_out_hi <= 0;
                hbc_dq_out_lo <= 0;
            end

        endcase
    end
end

//hbc_rwds_en
always @(posedge ram_clock or posedge ram_reset) begin
    if(ram_reset == 1'b1)begin
        hbc_rwds_en <= 0;
    end
    else begin
        case(state_now)

            CONFIG_PRE:begin
                hbc_rwds_en <= (BIT_WIDTH == 16) ? 2'b11 : 1'b1;
            end

            CONFIG:begin
                hbc_rwds_en <= (BIT_WIDTH == 16) ? 2'b11 : 1'b1;
            end

            INIT_PRE:begin
                hbc_rwds_en <= (BIT_WIDTH == 16) ? 2'b11 : 1'b1;
            end

            INIT:begin
                if(clk_cnt <= 4'd2)begin
                    hbc_rwds_en <= (BIT_WIDTH == 16) ? 2'b11 : 1'b1;
                end
                else if(clk_cnt == LATENCY * 2 + 1)begin
                    if(r_rw_ctrl)begin
                        hbc_rwds_en <= (BIT_WIDTH == 16) ? 2'b00 : 1'b0;
                    end
                    else begin
                        hbc_rwds_en <= (BIT_WIDTH == 16) ? 2'b11 : 1'b1;
                    end
                end
                else begin
                    hbc_rwds_en <= 0;
                end
            end

            WRITE:begin
                hbc_rwds_en <= (BIT_WIDTH == 16) ? 2'b11 : 1'b1;
            end

            default:begin
                hbc_rwds_en <= 0;
            end
        endcase
    end
end

//hbc_rwds_out
generate if(MASK_WIDTH >= 4) begin : BIG_TO_SMALL
    
    case(BIT_WIDTH)

        8 : begin
            
            //data_mask shift register
            always @(posedge ram_clock or posedge ram_reset) begin
                if(ram_reset == 1'b1)begin
                    r_data_mask <= 0;
                end
                else if(ram_en)begin
                    r_data_mask <= ram_data_mask;
                end
                else if(state_now == WRITE)begin
                    r_data_mask <= {r_data_mask[MASK_WIDTH - 3 : 0],r_data_mask[MASK_WIDTH - 1 : MASK_WIDTH - 2]};
                end
                else begin
                    r_data_mask <= r_data_mask;
                end
            end

            //hbc_rwds_out
            always @(posedge ram_clock or posedge ram_reset) begin
                if(ram_reset == 1'b1)begin
                    hbc_rwds_out_hi <= 1'b0;
                    hbc_rwds_out_lo <= 1'b0;
                end
                else if(state_now == INIT)begin
                    if(clk_cnt <= 4'd3)begin
                        hbc_rwds_out_hi <= 1'b1;
                        hbc_rwds_out_lo <= 1'b1;
                    end
                    else begin
                        hbc_rwds_out_hi <= 1'b0;
                        hbc_rwds_out_lo <= 1'b0;
                    end
                end
                else if(state_now == CONFIG_PRE || state_now == CONFIG || state_now == INIT_PRE)begin
                    hbc_rwds_out_hi <= 1'b1;
                    hbc_rwds_out_lo <= 1'b1;
                end
                else if(state_now == WRITE)begin
                    if(flag == 1'b0)begin
                        hbc_rwds_out_hi <= 1'b0;
                        hbc_rwds_out_lo <= 1'b0;
                    end
                    else begin
                        hbc_rwds_out_hi <= ~r_data_mask[MASK_WIDTH - 1];
                        hbc_rwds_out_lo <= ~r_data_mask[MASK_WIDTH - 2];
                    end
                end
                else begin
                    hbc_rwds_out_hi <= 1'b0;
                    hbc_rwds_out_lo <= 1'b0;
                end
            end

        end

        16 : begin

            //data_mask shift register
            if(MASK_WIDTH == 4)begin
                
                always @(posedge ram_clock or posedge ram_reset) begin
                    if(ram_reset == 1'b1)begin
                        r_data_mask <= 0;
                    end
                    else if(ram_en)begin
                        r_data_mask <= ram_data_mask;
                    end
                    else begin
                        r_data_mask <= r_data_mask;
                    end
                end

            end
            else begin
                
                always @(posedge ram_clock or posedge ram_reset) begin
                    if(ram_reset == 1'b1)begin
                        r_data_mask <= 0;
                    end
                    else if(ram_en)begin
                        r_data_mask <= ram_data_mask;
                    end
                    else if(state_now == WRITE)begin
                        r_data_mask <= {r_data_mask[MASK_WIDTH - 5 : 0],r_data_mask[MASK_WIDTH - 1 : MASK_WIDTH - 4]};
                    end
                    else begin
                        r_data_mask <= r_data_mask;
                    end
                end

            end

            //hbc_rwds_out
            always @(posedge ram_clock or posedge ram_reset) begin
                if(ram_reset == 1'b1)begin
                    hbc_rwds_out_hi <= 2'b00;
                    hbc_rwds_out_lo <= 2'b00;
                end
                else if(state_now == INIT)begin
                    if(clk_cnt <= 4'd3)begin
                        hbc_rwds_out_hi <= 2'b11;
                        hbc_rwds_out_lo <= 2'b11;
                    end
                    else begin
                        hbc_rwds_out_hi <= 2'b00;
                        hbc_rwds_out_lo <= 2'b00;
                    end
                end
                else if(state_now == CONFIG_PRE || state_now == CONFIG || state_now == INIT_PRE)begin
                    hbc_rwds_out_hi <= 2'b11;
                    hbc_rwds_out_lo <= 2'b11;
                end
                else if(state_now == WRITE)begin
                    if(flag == 1'b0)begin
                        hbc_rwds_out_hi <= 2'b00;
                        hbc_rwds_out_lo <= 2'b00;
                    end
                    else begin
                        hbc_rwds_out_hi <= ~r_data_mask[MASK_WIDTH - 3 : MASK_WIDTH - 4];
                        hbc_rwds_out_lo <= ~r_data_mask[MASK_WIDTH - 1 : MASK_WIDTH - 2];
                    end
                end
                else begin
                    hbc_rwds_out_hi <= 2'b00;
                    hbc_rwds_out_lo <= 2'b00;
                end
            end

        end

        default : begin

            always @(posedge ram_clock) begin
                hbc_rwds_out_hi <= 0;
                hbc_rwds_out_lo <= 0;
            end

        end

    endcase

end
endgenerate

generate if(MASK_WIDTH < 4) begin : SMALL_TO_BIG

    //data_mask shift register
    always @(posedge ram_clock or posedge ram_reset) begin
        if(ram_reset == 1'b1)begin
            r_data_mask <= 0;
        end
        else if(ram_en)begin
            r_data_mask <= ram_data_mask;
        end
        else begin
            r_data_mask <= r_data_mask;
        end
    end

    if(MASK_WIDTH <= 1)begin
        
        always @(posedge ram_clock or posedge ram_reset) begin
            if(ram_reset == 1'b1)begin
                hbc_rwds_out_hi <= 0;
                hbc_rwds_out_lo <= 0;
            end
            else if(state_now == INIT)begin
                if(clk_cnt <= 4'd3)begin
                    hbc_rwds_out_hi <= (BIT_WIDTH == 16) ? 2'b11 : 1'b1;
                    hbc_rwds_out_lo <= (BIT_WIDTH == 16) ? 2'b11 : 1'b1;
                end
                else begin
                    hbc_rwds_out_hi <= 0;
                    hbc_rwds_out_lo <= 0;
                end
            end
            else if(state_now == CONFIG_PRE || state_now == CONFIG || state_now == INIT_PRE)begin
                hbc_rwds_out_hi <= (BIT_WIDTH == 16) ? 2'b11 : 1'b1;
                hbc_rwds_out_lo <= (BIT_WIDTH == 16) ? 2'b11 : 1'b1;
            end
            else if(state_now == WRITE)begin
                if(flag == 1'b0)begin
                    hbc_rwds_out_hi <= 0;
                    hbc_rwds_out_lo <= 0;
                end
                else begin
                    hbc_rwds_out_hi <= ~r_data_mask;
                    hbc_rwds_out_lo <= ~r_data_mask;
                end
            end
            else begin
                hbc_rwds_out_hi <= 0;
                hbc_rwds_out_lo <= 0;
            end
        end

    end
    else begin

        always @(posedge ram_clock or posedge ram_reset) begin
            if(ram_reset == 1'b1)begin
                hbc_rwds_out_hi <= 0;
                hbc_rwds_out_lo <= 0;
            end
            else if(state_now == INIT)begin
                if(clk_cnt <= 4'd3)begin
                    hbc_rwds_out_hi <= (BIT_WIDTH == 16) ? 2'b11 : 1'b1;
                    hbc_rwds_out_lo <= (BIT_WIDTH == 16) ? 2'b11 : 1'b1;
                end
                else begin
                    hbc_rwds_out_hi <= 0;
                    hbc_rwds_out_lo <= 0;
                end
            end
            else if(state_now == CONFIG_PRE || state_now == CONFIG || state_now == INIT_PRE)begin
                hbc_rwds_out_hi <= (BIT_WIDTH == 16) ? 2'b11 : 1'b1;
                hbc_rwds_out_lo <= (BIT_WIDTH == 16) ? 2'b11 : 1'b1;
            end
            else if(state_now == WRITE)begin
                if(flag == 1'b0)begin
                    hbc_rwds_out_hi <= 0;
                    hbc_rwds_out_lo <= 0;
                end
                else begin
                    hbc_rwds_out_hi <= (BIT_WIDTH == 16) ? ~r_data_mask : ~r_data_mask[MASK_WIDTH - 1];
                    hbc_rwds_out_lo <= (BIT_WIDTH == 16) ? ~r_data_mask : ~r_data_mask[MASK_WIDTH - 2];
                end
            end
            else begin
                hbc_rwds_out_hi <= 0;
                hbc_rwds_out_lo <= 0;
            end
        end

    end

end
endgenerate

//hbc_cal_pass
always @(posedge ram_clock or posedge ram_reset) begin
    if(ram_reset == 1'b1)begin
        hbc_cal_pass <= 1'b0;
    end
    else if(state_now == WAIT && flag)begin
        hbc_cal_pass <= 1'b1;
    end
    else begin
        hbc_cal_pass <= hbc_cal_pass;
    end
end

//ram_rd_valid
always @(posedge ram_clock or posedge ram_reset) begin
    if(ram_reset == 1'b1)begin
        r_hbc_rwds_in_hi <= 0;
    end
    else begin
        r_hbc_rwds_in_hi <= hbc_rwds_in_hi;
    end
end

always @(posedge ram_clock or posedge ram_reset) begin
    if(ram_reset == 1'b1)begin
        ram_rd_valid <= 1'b0;
    end
    else if(state_now == READ)begin
        if(r_hbc_rwds_in_hi[0] ^ hbc_rwds_in_lo[0])begin
            ram_rd_valid <= 1'b1;
        end
        else begin
            ram_rd_valid <= 1'b0;
        end
    end
    else begin
        ram_rd_valid <= 1'b0;
    end
end

//ram_rd_data
always @(posedge ram_clock or posedge ram_reset) begin
    if(ram_reset == 1'b1)begin
        r_hbc_dq_in_hi <= 0;
    end
    else begin
        r_hbc_dq_in_hi <= hbc_dq_in_hi;
    end
end

always @(posedge ram_clock or posedge ram_reset) begin
    if(ram_reset == 1'b1)begin
        ram_rd_data <= 0;
    end
    else if(state_now == READ)begin
        if(r_hbc_rwds_in_hi[0] ^ hbc_rwds_in_lo[0])begin
            ram_rd_data <= {r_hbc_dq_in_hi,hbc_dq_in_lo};
        end
        else begin
            ram_rd_data <= ram_rd_data;
        end
    end
    else begin
        ram_rd_data <= ram_rd_data;
    end
end

//ram_wr_valid
assign ram_wr_valid = (state_now == WRITE && flag) ? 1'b1 : 1'b0;

//ctrl_idle
always @(posedge ram_clock or negedge ram_reset) begin
    if(ram_reset == 1'b1)begin
        ctrl_idle <= 1'b1;
    end
    else if(flag && (state_now == INIT || state_now == WRITE || state_now == READ || state_now == DONE))begin
        ctrl_idle <= 1'b0;
    end
    else begin
        ctrl_idle <= 1'b1;
    end
end

endmodule  //hbram_operate
