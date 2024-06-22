module psram_controller #(
    parameter PSRAM_FRE  = 200_000_000,
    parameter LATENCY    = 5,
    parameter BIT_WIDTH  = 16,
    parameter BURST_LEN  = 32,
    parameter WARP_MODE  = "Wrap",
    parameter RW_METHOD  = "Linear"
) (
    input                               ram_clk,
    input                               ram_clk_p,  //ram_clk shift 90
    input                               ram_rst,

    input                               ram_en,      //when ram_en is high,start one memory read/write
    input                               rw_ctrl,     //0: read       1: write
    input   [31:0]                      addr_in,     //the starting read/write address
    input   [BIT_WIDTH * 2 - 1 : 0]     ram_data_in, //write data in psram

    output  reg                         init_cable_complete, //psram config is done,can read/write psram memory
    output  reg                         ctrl_idle,   //when low,psram start to write or read

    output  reg                         psram_clk,
    output  reg                         psram_ce,

    //psram_dq
    output  reg                         dq_en,

    output  reg [BIT_WIDTH - 1 : 0]     dq_out_hi, //dq_out ris_edge data
    output  reg [BIT_WIDTH - 1 : 0]     dq_out_lo, //dq_out fal_edge data

    input       [BIT_WIDTH - 1 : 0]     dq_in_hi,  //dq_in ris_edge data
    input       [BIT_WIDTH - 1 : 0]     dq_in_lo,  //dq_in fal_edge data

    //psram_dm
    output  reg                         dm_en,

    output  reg [1 : 0]                 dm_out_hi,//dm_out[1] ris_edge and fal_edge
    output  reg [1 : 0]                 dm_out_lo,//dm_out[0] ris_edge and fal_edge

    input       [1 : 0]                 dm_in_hi,  //dm_in[1] ris_edge and fal_edge
    input       [1 : 0]                 dm_in_lo,  //dm_in[0] ris_edge and fal_edge

    output  reg [BIT_WIDTH * 2 - 1 : 0] ram_data_out, //read data from psram
    output  reg                         ram_rd_valid, //can read data from psram
    output                              ram_wr_valid  //can write data to psram
);

localparam TPU  = ((PSRAM_FRE / 1000) * 160) / 1000; //wait 160us for psram initialization
localparam TRST = ((PSRAM_FRE / 1000) * 3) / 1000; //after write global reset,wait 3us
localparam TCPH = 5;               //after config,wait 24ns

localparam IDLE        = 4'd0;
localparam RESET       = 4'd1;
localparam RESET_WAIT  = 4'd2;
localparam CONFIG      = 4'd3;
localparam CONFIG_DONE = 4'd4;
localparam CONFIG_WAIT = 4'd5;
localparam WAIT        = 4'd6;
localparam INIT        = 4'd7;
localparam WRITE       = 4'd8;
localparam READ        = 4'd9;
localparam DONE        = 4'd10;

reg [3:0] state_now;
reg [3:0] state_next;

reg [15:0] init_cnt;   //mark the time of initialization
reg [3:0]  clk_cnt;   //mark the number of ram_clk
reg [9:0]  rst_cnt;   //after reset,mark the time of wait
reg [2:0]  cph_cnt;   //after config registor,write or read,wait tcph
reg [1:0]  mr_cnt;    //mark the number of written register
reg [11:0] data_cnt;  //mark the count of data transmitted or received

reg        r_psram_clk;

wire [2:0] rlc_config; //READ Latency Code
wire [2:0] wlc_config; //WRITE Latency Code
reg  [7:0] command_config; //read or write config
wire       bit_config;     //bit mode config
wire       wrap_config;    //wrap mode config
wire [1:0] bl_config;      //Burst length config

reg        r_rw_ctrl;

assign     rlc_config = (LATENCY == 3) ? 3'b000 :
                        (LATENCY == 4) ? 3'b001 :
                        (LATENCY == 5) ? 3'b010 :
                        (LATENCY == 6) ? 3'b011 :
                        (LATENCY == 7) ? 3'b100 : 3'b010;

assign     wlc_config = (LATENCY == 3) ? 3'b000 :
                        (LATENCY == 4) ? 3'b100 :
                        (LATENCY == 5) ? 3'b010 :
                        (LATENCY == 6) ? 3'b110 :
                        (LATENCY == 7) ? 3'b001 : 3'b010;

/*

assign     command_config = (RW_METHOD == "Linear") ? {rw_ctrl,7'b010_0000} :
                            (RW_METHOD == "Sync")   ? {rw_ctrl,7'b000_0000} : 8'hff;
*/
assign     bit_config     = (BIT_WIDTH == 8)        ? 1'b0 : 1'b1;

assign     wrap_config    = (WARP_MODE == "Wrap")   ? 1'b0 : 1'b1;

assign     bl_config      = (BURST_LEN == 16)   ? 2'b00 :
                            (BURST_LEN == 32)   ? 2'b01 :
                            (BURST_LEN == 64)   ? 2'b10 : 
                            (BURST_LEN == 2048) ? 2'b11 : 2'b00;

//command_config
always @(posedge ram_clk or negedge ram_rst) begin
    if(ram_rst == 1'b0)begin
        r_rw_ctrl <= 1'b0;
    end
    else if(ram_en)begin
        r_rw_ctrl <= rw_ctrl;
    end
    else begin
        r_rw_ctrl <= r_rw_ctrl;
    end
end

generate if(RW_METHOD == "Linear") begin : Linear_rw_config
    always @(posedge ram_clk or negedge ram_rst) begin
        if(ram_rst == 1'b0)begin
            command_config <= 8'hff;
        end
        else if(ram_en)begin
            command_config <= {rw_ctrl,7'b010_0000};
        end
        else begin
            command_config <= command_config;
        end
    end
end
endgenerate

generate if(RW_METHOD == "Sync") begin : Sync_rw_config
    always @(posedge ram_clk or negedge ram_rst) begin
        if(ram_rst == 1'b0)begin
            command_config <= 8'hff;
        end
        else if(ram_en)begin
            command_config <= {rw_ctrl,7'b000_0000};
        end
        else begin
            command_config <= command_config;
        end
    end
end
endgenerate

//mark the time of initialization
always @(posedge ram_clk or negedge ram_rst) begin
    if(ram_rst == 1'b0)begin
        init_cnt <= 16'd0;
    end
    else if(init_cnt < TPU - 1'b1)begin
        init_cnt <= init_cnt + 1'b1;
    end
    else begin
        init_cnt <= init_cnt;
    end
end

//mark the number of ram_clk
always @(posedge ram_clk or negedge ram_rst) begin
    if(ram_rst == 1'b0)begin
        clk_cnt <= 4'd0;
    end
    else if(state_now == RESET || state_now == CONFIG || state_now == INIT)begin
        clk_cnt <= clk_cnt + 1'b1;
    end
    else begin
        clk_cnt <= 4'd0;
    end
end

//after reset,mark the time of wait
always @(posedge ram_clk or negedge ram_rst) begin
    if(ram_rst == 1'b0)begin
        rst_cnt <= 10'd0;
    end
    else if(state_now == RESET_WAIT)begin
        if(rst_cnt < TRST - 1'b1)begin
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

//after config registor,write or read,wait tcph
always @(posedge ram_clk or negedge ram_rst) begin
    if(ram_rst == 1'b0)begin
        cph_cnt <= 3'd0;
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
always @(posedge ram_clk or negedge ram_rst) begin
    if(ram_rst == 1'b0)begin
        mr_cnt <= 2'd0;
    end
    else if(state_now == CONFIG_DONE)begin
        mr_cnt <= mr_cnt + 1'b1;
    end
    else begin
        mr_cnt <= mr_cnt;
    end
end

//mark the count of data transmitted or received
always @(posedge ram_clk or negedge ram_rst) begin
    if(ram_rst == 1'b0)begin
        data_cnt <= 12'd0;
    end
    else if(ram_wr_valid | ram_rd_valid)begin
        if(data_cnt < BURST_LEN - 2)begin
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

//state_machine
always @(posedge ram_clk or negedge ram_rst) begin
    if(ram_rst == 1'b0)begin
        state_now <= IDLE;
    end
    else begin
        state_now <= state_next;
    end
end

always @(*) begin
    if(ram_rst == 1'b0)begin
        state_next <= IDLE;
    end
    else begin
        case(state_now)
            IDLE:begin
                if(init_cnt == TPU - 1'b1)begin
                    state_next <= RESET;
                end
                else begin
                    state_next <= IDLE;
                end
            end
            RESET:begin
                if(clk_cnt == 4'd3)begin
                    state_next <= RESET_WAIT;
                end
                else begin
                    state_next <= RESET;
                end
            end
            RESET_WAIT:begin
                if(rst_cnt == TRST - 1'b1)begin
                    state_next <= CONFIG;
                end
                else begin
                    state_next <= RESET_WAIT;
                end
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
                if(cph_cnt == TCPH - 1'b1 && mr_cnt == 2'd3)begin
                    state_next <= WAIT;
                end
                else if(cph_cnt == TCPH - 1'b1 && mr_cnt < 2'd3)begin
                    state_next <= CONFIG;
                end
                else begin
                    state_next <= CONFIG_WAIT;
                end
            end
            WAIT:begin
                if(ram_en)begin
                    state_next <= INIT;
                end
                else begin
                    state_next <= WAIT;
                end
            end
            INIT:begin
                if(r_rw_ctrl == 1'b1)begin
                    if(clk_cnt == LATENCY + 1)begin
                        state_next <= WRITE;
                    end
                    else begin
                        state_next <= INIT;
                    end
                end
                else begin
                    if(clk_cnt == 4'd2)begin
                        state_next <= READ;
                    end
                    else begin
                        state_next <= INIT;
                    end
                end
            end
            WRITE:begin
                if(data_cnt == BURST_LEN - 2)begin
                    state_next <= DONE;
                end
                else begin
                    state_next <= WRITE;
                end
            end
            READ:begin
                if(data_cnt == BURST_LEN - 2)begin
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

//psram_clk
always @(posedge ram_clk or negedge ram_rst) begin
    if(ram_rst == 1'b0)begin
        psram_clk <= 1'b0;
    end
    else begin
        psram_clk <= r_psram_clk;
    end
end

always @(posedge ram_clk or negedge ram_rst) begin
    if(ram_rst == 1'b0)begin
        r_psram_clk <= 1'b0;
    end
    else begin
        case(state_now)
            IDLE:begin
                r_psram_clk <= 1'b0;
            end
            CONFIG_DONE:begin
                r_psram_clk <= 1'b0;
            end
            CONFIG_WAIT:begin
                r_psram_clk <= 1'b0;
            end
            WAIT:begin
                r_psram_clk <= 1'b0;
            end
            DONE:begin
                r_psram_clk <= 1'b0;
            end
            default:begin
                r_psram_clk <= 1'b1;
            end
        endcase
    end
end

//psram_dq_en
always @(posedge ram_clk or negedge ram_rst) begin
    if(ram_rst == 1'b0)begin
        dq_en <= 1'b0;
    end
    else begin
        case(state_now)
            RESET:begin
                if(clk_cnt == 4'd0)begin
                    dq_en <= 1'b1;
                end
                else begin
                    dq_en <= 1'b0;
                end
            end
            CONFIG:begin
                dq_en <= 1'b1;
            end
            INIT:begin
                if(clk_cnt <= 4'd2)begin
                    dq_en <= 1'b1;
                end
                else begin
                    dq_en <= 1'b0;
                end
            end
            WRITE:begin
                dq_en <= 1'b1;
            end
            default:begin
                dq_en <= 1'b0;
            end
        endcase
    end
end

//psram_dm_en
always @(posedge ram_clk or negedge ram_rst) begin
    if(ram_rst == 1'b0)begin
        dm_en <= 1'b0;
    end
    else if(state_now == WRITE)begin
        dm_en <= 1'b1; 
    end
    else begin
        dm_en <= 1'b0;
    end
end

//psram_dq
always @(posedge ram_clk or negedge ram_rst) begin
    if(ram_rst == 1'b0)begin
        dq_out_hi <= 8'h00;
        dq_out_lo <= 8'h00;
    end
    else begin
        case(state_now)
            IDLE:begin
                dq_out_hi <= 8'h00;
                dq_out_lo <= 8'h00;
            end
            RESET:begin
                dq_out_hi <= 8'hff;
                dq_out_lo <= 8'hff;
            end
            RESET_WAIT:begin
                dq_out_hi <= dq_out_hi;
                dq_out_lo <= dq_out_lo;
            end
            CONFIG:begin
                case(mr_cnt)
                    //register 0
                    2'd0:begin
                        case(clk_cnt)
                            //register write command
                            4'd0:begin
                                dq_out_hi <= 8'hc0;
                                dq_out_lo <= 8'hc0;
                            end
                            //not care
                            4'd1:begin
                                dq_out_hi <= 8'h00;
                                dq_out_lo <= 8'h00;
                            end
                            //MA: Registor 0
                            4'd2:begin
                                dq_out_hi <= 8'h00;
                                dq_out_lo <= 8'h00;
                            end
                            //MR: {variable latency + READ_lATENCY_CODE + 50ou} 
                            4'd3:begin
                                dq_out_hi <= {3'b000,rlc_config,2'b01};
                                dq_out_lo <= {3'b000,rlc_config,2'b01};
                            end
                            default:begin
                                dq_out_hi <= 8'h00;
                                dq_out_lo <= 8'h00;
                            end
                        endcase
                    end
                    //register 4
                    2'd1:begin
                        case(clk_cnt)
                            //register write command
                            4'd0:begin
                                dq_out_hi <= 8'hc0;
                                dq_out_lo <= 8'hc0;
                            end
                            //not care
                            4'd1:begin
                                dq_out_hi <= 8'h00;
                                dq_out_lo <= 8'h00;
                            end
                            //MA: Registor 4
                            4'd2:begin
                                dq_out_hi <= 8'h04;
                                dq_out_lo <= 8'h04;
                            end
                            //MR: {WRITE_LATENCY_CODE + 4X Refresh Frequency + Refresh Memory Array}
                            4'd3:begin
                                dq_out_hi <= {wlc_config,2'b00,3'b000};
                                dq_out_lo <= {wlc_config,2'b00,3'b000};
                            end
                            default:begin
                                dq_out_hi <= 8'h00;
                                dq_out_lo <= 8'h00;
                            end
                        endcase
                    end
                    //register 8
                    2'd2:begin
                        case(clk_cnt)
                            //register write command
                            4'd0:begin
                                dq_out_hi <= 8'hc0;
                                dq_out_lo <= 8'hc0;
                            end
                            //not care
                            4'd1:begin
                                dq_out_hi <= 8'h00;
                                dq_out_lo <= 8'h00;
                            end
                            //MA: Registor 8
                            4'd2:begin
                                dq_out_hi <= 8'h08;
                                dq_out_lo <= 8'h08;
                            end
                            //MR: {x8/x16 mode + within page boundary + wrap mode + burst_length_config}
                            4'd3:begin
                                dq_out_hi <= {1'b0,bit_config,2'b00,1'b0,wrap_config,bl_config};
                                dq_out_lo <= {1'b0,bit_config,2'b00,1'b0,wrap_config,bl_config};
                            end
                            default:begin
                                dq_out_hi <= 8'h00;
                                dq_out_lo <= 8'h00;
                            end
                        endcase
                    end
                    default:begin
                        dq_out_hi <= 8'h00;
                        dq_out_lo <= 8'h00;
                    end
                endcase
                end
            CONFIG_DONE:begin
                dq_out_hi <= 8'h00;
                dq_out_lo <= 8'h00;
            end
            CONFIG_WAIT:begin
                dq_out_hi <= 8'h00;
                dq_out_lo <= 8'h00;
            end
            WAIT:begin
                dq_out_hi <= 8'h00;
                dq_out_lo <= 8'h00;
            end
            INIT:begin
                case(clk_cnt)
                    4'd0:begin
                        dq_out_hi <= command_config;
                        dq_out_lo <= command_config;
                    end
                    4'd1:begin
                        dq_out_hi <= addr_in[31:24];
                        dq_out_lo <= addr_in[23:16];
                    end
                    4'd2:begin
                        dq_out_hi <= addr_in[15:8];
                        dq_out_lo <= addr_in[7:0];
                    end
                    default:begin
                        dq_out_hi <= 8'h00;
                        dq_out_lo <= 8'h00;
                    end
                endcase
                end
            WRITE:begin
                dq_out_hi <= ram_data_in[BIT_WIDTH * 2 - 1 : BIT_WIDTH];
                dq_out_lo <= ram_data_in[BIT_WIDTH - 1 : 0];
            end
            READ:begin
                dq_out_hi <= 8'h00;
                dq_out_lo <= 8'h00;
            end
            DONE:begin
                dq_out_hi <= 8'h00;
                dq_out_lo <= 8'h00;
            end
            default:begin
                dq_out_hi <= 8'h00;
                dq_out_lo <= 8'h00;
            end
        endcase
    end
end

//psram_dm
always @(posedge ram_clk or negedge ram_rst) begin
    if(ram_rst == 1'b0)begin
        dm_out_hi <= 2'b00;
        dm_out_lo <= 2'b00;
    end
    else begin
        dm_out_hi <= 2'b00;
        dm_out_lo <= 2'b00;
    end
end

//psram_ce
always @(posedge ram_clk or negedge ram_rst) begin
    if(ram_rst == 1'b0)begin
        psram_ce <= 1'b1;
    end
    else begin
        case(state_now)
            IDLE:begin
                psram_ce <= 1'b1;
            end
            RESET:begin
                psram_ce <= 1'b0;
            end
            RESET_WAIT:begin
                psram_ce <= 1'b1;
            end
            CONFIG:begin
                psram_ce <= 1'b0;
            end
            CONFIG_DONE:begin
                psram_ce <= 1'b1;
            end
            CONFIG_WAIT:begin
                psram_ce <= 1'b1;
            end
            WAIT:begin
                psram_ce <= 1'b1;
            end
            INIT:begin
                psram_ce <= 1'b0;
            end
            WRITE:begin
                psram_ce <= 1'b0;
            end
            READ:begin
                psram_ce <= 1'b0;
            end
            DONE:begin
                psram_ce <= 1'b1;
            end
            default:begin
                psram_ce <= 1'b1;
            end
        endcase
    end
end

//psram config is done,can read/write psram memory
always @(posedge ram_clk or negedge ram_rst) begin
    if(ram_rst == 1'b0)begin
        init_cable_complete <= 1'b0;
    end
    else if(state_now == WAIT)begin
        init_cable_complete <= 1'b1;
    end
    else begin
        init_cable_complete <= init_cable_complete;
    end
end

//ctrl_idle
always @(posedge ram_clk or negedge ram_rst) begin
    if(ram_rst == 1'b0)begin
        ctrl_idle <= 1'b1;
    end
    else if(state_now == INIT || state_now == WRITE || state_now == READ || state_now == DONE)begin
        ctrl_idle <= 1'b0;
    end
    else begin
        ctrl_idle <= 1'b1;
    end
end

//ram_wr_valid
assign ram_wr_valid = (state_now == WRITE) ? 1'b1 : 1'b0;

/*
always @(posedge ram_clk or negedge ram_rst) begin
    if(ram_rst == 1'b0)begin
        ram_wr_valid <= 1'b0;
    end
    else if(state_now == WRITE)begin
        ram_wr_valid <= 1'b1;
    end
    else begin
        ram_wr_valid <= 1'b0;
    end
end
*/

//ram_rd_valid
always @(posedge ram_clk or negedge ram_rst) begin
    if(ram_rst == 1'b0)begin
        ram_rd_valid <= 1'b0;
    end
    else if(state_now == READ)begin
        if(dm_in_lo[0] ^ dm_in_lo[1])begin
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

//ram_data_out
always @(posedge ram_clk or negedge ram_rst) begin
    if(ram_rst == 1'b0)begin
        ram_data_out <= 1'b0;
    end
    else if(state_now == READ)begin
        if(dm_in_lo[0] ^ dm_in_lo[1])begin
            ram_data_out <= {dq_in_hi,dq_in_lo};
        end
        else begin
            ram_data_out <= ram_data_out;
        end
    end
    else begin
        ram_data_out <= ram_data_out;
    end
end

endmodule  //psram_controller
