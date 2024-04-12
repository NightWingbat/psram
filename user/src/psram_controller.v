module psram_controller #(
    parameter CLK_FRE    = 500_000_000,
    parameter PSRAM_FRE  = 200_000_000,
    parameter LATENCY    = 5
) (
    input              sys_clk,
    input              sys_rst,

    input              psram_exe,  //when psram_exe is high,start one memory read/write
    input              rw_ctrl,    //0: read       1: write
    input              bit_ctrl,   //0: x8 mode    1: x16 mode
    input   [1:0]      byte_write,
    input              wrap_in,    //0: wrap       1: hybrid wrap
    input   [31:0]     addr_in,    //the starting read/write address
    input   [15:0]     data_in,     
    input   [11:0]     burst_len,
    input   [1:0]      command_in, //00: sync      01: linear      11: Global Reset

    output  reg        init_cable_complete, //psram config is done,can read/write psram memory

    output  reg        psram_clk,
    output  reg        psram_ce,
    inout   [15:0]     psram_dq,
    inout   [1:0]      psram_dm,

    output  reg        psram_done,     //one operation is done
    output  reg [15:0] psram_rd_data, 
    output  reg        psram_rd_valid, //can read data from psram
    output             psram_wr_valid  //can write data to psram
);

localparam CLK_TIME  = CLK_FRE/PSRAM_FRE;
localparam INIT_TIME = (160 * CLK_FRE)/1_000_000;        //160us
localparam CPH_TIME  = (24  * CLK_FRE)/1_000_000_000;   //24ns

localparam IDLE       = 4'd0;
localparam RESET      = 4'd1;
localparam RESET_WAIT = 4'd2;
localparam CONFIG     = 4'd3;
localparam INIT       = 4'd4;
localparam COMMAND    = 4'd5;
localparam ADDRESS    = 4'd6;
localparam WAIT       = 4'd7;
localparam WRITE      = 4'd8;
localparam READ       = 4'd9;
localparam DONE       = 4'd10;
localparam DONE_WAIT  = 4'd11;

reg [$clog2(CLK_TIME) - 1 : 0] clk_cnt;   //Clock division counter
reg [$clog2(INIT_TIME) - 1 : 0]init_cnt;  //Time required for initialization
reg [1:0]                      mr_clk_cnt;//mark the count or psram_clk
reg [2:0]                      mr_cnt;    //mark the count of registor written

reg                            mend_flag; //The data can change at this moment

reg  [3:0]                     state_now;
reg  [3:0]                     state_next;

reg  [1:0]                     address_cnt; //mark the count of address sended
reg  [3:0]                     latency_cnt; //mark the count of latency
reg  [11:0]                    data_cnt;    //mark the count of data
reg  [$clog2(CPH_TIME) - 1 : 0]cph_cnt;     //delay that satisfies TCPH

reg  [15:0]                    psram_dq_out;
reg  [1:0]                     psram_dm_out;

wire [15:0]                    psram_dq_in;
wire [1:0]                     psram_dm_in;

reg                            psram_dm_in_d0;
wire                           psram_dm_in_pos;
wire                           psram_dm_in_neg;

wire [2:0]                     latency_config;
wire [1:0]                     bl_config;

//assign                         mend_flag       = (clk_cnt == CLK_TIME/4 - 1'b1) || (clk_cnt == (3 * CLK_TIME)/4 - 1'b1) ? 1'b1 : 1'b0;

assign                         psram_dq_in     = psram_dq;
assign                         psram_dm_in     = psram_dm;
assign                         psram_dm_in_pos = (~psram_dm_in_d0) & psram_dm_in[0];
assign                         psram_dm_in_neg = (~psram_dm_in[0]) & psram_dm_in_d0;

assign                         latency_config  = (LATENCY == 3) ? 3'b000 : 
                                                 (LATENCY == 4) ? 3'b001 :
                                                 (LATENCY == 5) ? 3'b010 :
                                                 (LATENCY == 6) ? 3'b011 :
                                                 (LATENCY == 7) ? 3'b100 : 3'b010;

assign                         bl_config       = (burst_len == 12'd16)   ? 2'b00 :
                                                 (burst_len == 12'd32)   ? 2'b01 :
                                                 (burst_len == 12'd64)   ? 2'b10 :
                                                 (burst_len == 12'd1024) ? 2'b11 :
                                                 (burst_len == 12'd2048) ? 2'b11 : 2'b00;

//delay 160us to initialize psram
always @(posedge sys_clk) begin
    if(sys_rst == 1'b0)begin
        init_cnt <= 1'b0;
    end
    else if(state_now == IDLE)begin
        if(init_cnt < INIT_TIME - 1)
            init_cnt <= init_cnt + 1'b1;
    end
    else begin
        init_cnt <= init_cnt;
    end
end

//Clock division counter
always @(posedge sys_clk) begin
    if(sys_rst == 1'b0)begin
        clk_cnt <= 1'b0;
    end
    else if(state_now == IDLE || state_now == INIT || state_now == DONE || state_now == DONE_WAIT)begin
        clk_cnt <= 1'b0;
    end
    else begin
        if(clk_cnt == CLK_TIME - 1'b1)
            clk_cnt <= 1'b0;
        else 
            clk_cnt <= clk_cnt + 1'b1;
    end
end

//when reset or config registor,mark the count of psram_clk
always @(posedge sys_clk) begin
    if(sys_rst == 1'b0)begin
        mr_clk_cnt <= 2'd0;
    end
    else if(state_now == RESET_WAIT || state_now == CONFIG)begin
        if(mr_clk_cnt < 2'd3)begin
            if(clk_cnt == CLK_TIME - 1'b1)
                mr_clk_cnt <= mr_clk_cnt + 1'b1;
            else 
                mr_clk_cnt <= mr_clk_cnt;
        end
        else begin
            mr_clk_cnt <= mr_clk_cnt;
        end
    end
    else begin
        mr_clk_cnt <= 2'd0;
    end
end

//mark the count of registor written
always @(posedge sys_clk) begin
    if(sys_rst == 1'b0)begin
        mr_cnt <= 3'd0;
    end
    else if(state_now == DONE)begin
        if(mr_cnt < 3'd4)
            mr_cnt <= mr_cnt + 1'b1;
        else 
            mr_cnt <= mr_cnt;
    end
    else begin
        mr_cnt <= mr_cnt;
    end
end

//mark the count of address sended
always @(posedge sys_clk) begin
    if(sys_rst == 1'b0)begin
        address_cnt <= 2'd0;
    end
    else if(state_now == ADDRESS)begin
        if(address_cnt < 2'd2)begin
            if(clk_cnt == CLK_TIME - 1'b1)
                address_cnt <= address_cnt + 1'b1;
            else 
                address_cnt <= address_cnt;
        end
        else begin
            address_cnt <= address_cnt;
        end
    end
    else begin
        address_cnt <= 2'd0;
    end
end

//mark the count of latency
always @(posedge sys_clk) begin
    if(sys_rst == 1'b0)begin
        latency_cnt <= 4'd0;
    end
    else if(state_now == WAIT)begin
        if(latency_cnt < LATENCY - 1)begin
            if(clk_cnt == CLK_TIME - 1'b1)
                latency_cnt <= latency_cnt + 1'b1;
            else 
                latency_cnt <= latency_cnt;
        end
        else begin
            latency_cnt <= latency_cnt;
        end
    end
    else begin
        latency_cnt <= 4'd0;
    end
end

//buffer
always @(posedge sys_clk) begin
    if(sys_rst == 1'b0)begin
        psram_dm_in_d0 <= 1'b0;
    end
    else begin
        psram_dm_in_d0 <= psram_dm_in[0];
    end
end

//mark the count of data
always @(posedge sys_clk) begin
    if(sys_rst == 1'b0)begin
        data_cnt <= 12'd0;
    end
    else if(state_now == WRITE)begin
        if(data_cnt == burst_len)begin
            data_cnt <= data_cnt;
        end
        else begin
            if(mend_flag)
                data_cnt <= data_cnt + 1'b1;
            else 
                data_cnt <= data_cnt;
        end
    end
    else if(state_now == READ)begin
        if(psram_dm_in_pos | psram_dm_in_neg)
            data_cnt <= data_cnt + 1'b1;
        else 
            data_cnt <= data_cnt;
    end
    else begin
        data_cnt <= 12'd0;
    end
end

//delay that satisfies TCPH
always @(posedge sys_clk) begin
    if(sys_rst == 1'b0)begin
        cph_cnt <= 1'b0;
    end
    else if(state_now == DONE_WAIT)begin
        if(cph_cnt < CPH_TIME - 1'b1)
            cph_cnt <= cph_cnt + 1'b1;
    end
    else begin
        cph_cnt <= 1'b0;
    end
end

//The data can change at this moment
always @(posedge sys_clk) begin
    if(sys_rst == 1'b0)begin
        mend_flag <= 1'b0;
    end
    else if((clk_cnt == CLK_TIME/4 - 1'b1) || (clk_cnt == (3 * CLK_TIME)/4 - 1'b1))begin
        mend_flag <= 1'b1;
    end
    else begin
        mend_flag <= 1'b0;
    end
end

//state machine
always @(posedge sys_clk) begin
    if(sys_rst == 1'b0)begin
        state_now <= IDLE;
    end
    else begin
        state_now <= state_next;
    end
end

always @(*) begin
    if(sys_rst == 1'b0)begin
        state_next <= IDLE;
    end
    else begin
        case(state_now)
            IDLE:begin
                if(init_cnt == INIT_TIME - 1'b1)
                    state_next <= RESET;
                else 
                    state_next <= IDLE;
            end
            RESET:begin
                if(clk_cnt == CLK_TIME - 1'b1)
                    state_next <= RESET_WAIT;
                else 
                    state_next <= RESET;
            end
            RESET_WAIT:begin
                if(mr_clk_cnt == 2'd3)
                    state_next <= DONE;
                else 
                    state_next <= RESET_WAIT;
            end
            CONFIG:begin
                if(mr_clk_cnt == 2'd3 && mr_cnt < 3'd4 && clk_cnt == CLK_TIME - 1'b1)
                    state_next <= DONE;
                else 
                    state_next <= CONFIG;
            end
            INIT:begin
                if(psram_exe)
                    state_next <= COMMAND;
                else 
                    state_next <= INIT;
            end
            COMMAND:begin
                if(clk_cnt == CLK_TIME - 1'b1)
                    state_next <= ADDRESS;
                else 
                    state_next <= COMMAND;
            end
            ADDRESS:begin
                if(address_cnt == 2'd2)
                    state_next <= WAIT;
                else 
                    state_next <= ADDRESS;
            end
            WAIT:begin
                if(latency_cnt == LATENCY - 1)begin
                    if(rw_ctrl == 1'b1)
                        state_next <= WRITE;
                    else 
                        state_next <= READ;
                end
                else begin
                    state_next <= WAIT;
                end
            end
            WRITE:begin
                if(data_cnt == burst_len && mend_flag == 1'b1)
                    state_next <= DONE;
                else 
                    state_next <= WRITE;
            end
            READ:begin
                if(data_cnt == burst_len)
                    state_next <= DONE;
                else 
                    state_next <= READ;
            end
            DONE:begin
                state_next <= DONE_WAIT;
            end
            DONE_WAIT:begin
                if(cph_cnt == CPH_TIME - 1'b1 && mr_cnt == 3'd4)
                    state_next <= INIT;
                else if(cph_cnt == CPH_TIME - 1'b1 && mr_cnt < 3'd4)
                    state_next <= CONFIG;
                else 
                    state_next <= DONE_WAIT;
            end
            default:begin
                state_next <= IDLE;
            end
        endcase
    end
end

//when coming into INIT state,psram configuration is done
always @(posedge sys_clk) begin
    if(sys_rst == 1'b0)begin
        init_cable_complete <= 1'b0;
    end
    else if(state_now == INIT)begin
        init_cable_complete <= 1'b1;
    end
end

//psram_clk
always @(posedge sys_clk) begin
    if(sys_rst == 1'b0)begin
        psram_clk <= 1'b0;
    end
    else if(state_now == IDLE || state_now == INIT || state_now == DONE || state_now == DONE_WAIT)begin
        psram_clk <= 1'b0;
    end
    else begin
        if(clk_cnt <= CLK_TIME/2 - 1'b1)
            psram_clk <= 1'b0;
        else 
            psram_clk <= 1'b1;
    end
end

//when in psram configuration and one transferion is done,psram_ce is high
always @(posedge sys_clk) begin
    if(sys_rst == 1'b0)begin
        psram_ce <= 1'b0;
    end
    else if(state_now == IDLE || state_now == INIT || state_now == DONE_WAIT)begin
        psram_ce <= 1'b1;
    end
    else begin
        psram_ce <= 1'b0;
    end
end

//psram_dq_out
always @(posedge sys_clk) begin
    if(sys_rst == 1'b0)begin
        psram_dq_out <= 16'd0;
    end
    else begin
        case(state_now)
            IDLE:begin
                psram_dq_out <= 16'h0000;
            end
            RESET:begin
                psram_dq_out <= 16'h00ff;
            end
            RESET_WAIT:begin
                if(mend_flag)
                    psram_dq_out <= 16'h0000;
                else
                    psram_dq_out <= psram_dq_out;
            end
            CONFIG:begin
                case(mr_cnt)
                    //config registor 0
                    3'd1:begin
                        case(mr_clk_cnt)
                            //command: registor write
                            2'd0:begin
                                psram_dq_out <= 16'h00c0;
                            end
                            //not care
                            2'd1:begin
                                if(mend_flag)
                                    psram_dq_out <= 16'h0000;
                                else
                                    psram_dq_out <= psram_dq_out;
                            end
                            //MA: Registor 0
                            2'd2:begin
                                if(mend_flag)
                                    psram_dq_out <= 16'h0000;
                                else
                                    psram_dq_out <= psram_dq_out;
                            end
                            //MR: {variable latency + READ_lATENCY_CODE + 50ou} 
                            2'd3:begin
                                if(mend_flag)
                                    psram_dq_out <= {3'b000,latency_config,2'b01};
                                else 
                                    psram_dq_out <= psram_dq_out;
                            end
                            default:begin
                                psram_dq_out <= 16'h0000;
                            end
                        endcase
                    end
                    //config registor 4
                    3'd2:begin
                        case(mr_clk_cnt)
                            //command: registor write
                            2'd0:begin
                                psram_dq_out <= 16'h00c0;
                            end
                            //not care
                            2'd1:begin
                                if(mend_flag)
                                    psram_dq_out <= 16'h0000;
                                else
                                    psram_dq_out <= psram_dq_out;
                            end
                            //MA: Registor 4
                            2'd2:begin
                                if(mend_flag)
                                    psram_dq_out <= 16'h0004;
                                else 
                                    psram_dq_out <= psram_dq_out;
                            end
                            //MR: {WRITE_LATENCY_CODE + 4X Refresh Frequency + Refresh Memory Array}
                            2'd3:begin
                                if(mend_flag)
                                    psram_dq_out <= {latency_config,2'b00,3'b000};
                                else 
                                    psram_dq_out <= psram_dq_out;
                            end
                            default:begin
                                psram_dq_out <= 16'h0000;
                            end
                        endcase
                    end
                    //config registor 8
                    3'd3:begin
                        case(mr_clk_cnt)
                            //command: registor write
                            2'd0:begin
                                psram_dq_out <= 16'h00c0;
                            end
                            //not care
                            2'd1:begin
                                if(mend_flag)
                                    psram_dq_out <= 16'h0000;
                                else 
                                    psram_dq_out <= psram_dq_out;
                            end
                            //MA: Registor 8
                            2'd2:begin
                                if(mend_flag)
                                    psram_dq_out <= 16'h0008;
                                else 
                                    psram_dq_out <= psram_dq_out;
                            end
                            //MR: { x8/x16 mdoe + within page boundary + wrap mode + burst_length_config}
                            2'd3:begin
                                if(mend_flag)
                                    psram_dq_out <= {1'b0,bit_ctrl,2'b00,1'b0,wrap_in,bl_config};
                                else 
                                    psram_dq_out <= psram_dq_out;
                            end
                            default:begin
                                psram_dq_out <= 16'h0000;
                            end
                        endcase
                    end
                    default:begin
                        psram_dq_out <= 16'h0000;
                    end
                endcase
            end
            INIT:begin
                psram_dq_out <= 16'h0000;
            end
            COMMAND:begin
                case(command_in)
                    //memory sync
                    2'b00:begin
                        if(rw_ctrl == 1'b1)
                            psram_dq_out <= 16'h0080;
                        else 
                            psram_dq_out <= 16'h0000;
                    end
                    //memory linear
                    2'b01:begin
                        if(rw_ctrl == 1'b1)
                            psram_dq_out <= 16'h00a0;
                        else 
                            psram_dq_out <= 16'h0020;
                    end
                    //global reset
                    2'b11:begin
                        psram_dq_out <= 16'h00ff;
                    end
                endcase
            end
            ADDRESS:begin
                psram_dq_out[15:8] <= 8'h00;
                case(address_cnt)
                    2'd0:begin
                        if(clk_cnt == CLK_TIME/4 - 1'b1)begin
                            psram_dq_out[7:0] <= addr_in[31:24];
                        end
                        else if(clk_cnt == (3 * CLK_TIME)/4 - 1'b1)begin
                            psram_dq_out[7:0] <= addr_in[23:16];
                        end
                        else begin
                            psram_dq_out <= psram_dq_out;
                        end
                    end
                    2'd1:begin
                        if(clk_cnt == CLK_TIME/4 - 1'b1)begin
                            psram_dq_out[7:0] <= addr_in[15:8];
                        end
                        else if(clk_cnt == (3 * CLK_TIME)/4 - 1'b1)begin
                            psram_dq_out[7:0] <= addr_in[7:0];
                        end
                        else begin
                            psram_dq_out <= psram_dq_out;
                        end
                    end
                    default:begin
                        psram_dq_out <= 16'h0000;
                    end
                endcase
            end
            WAIT:begin
                psram_dq_out <= 16'h0000;
            end
            WRITE:begin
                if(mend_flag)begin
                    psram_dq_out <= data_in;
                end
                else begin
                    psram_dq_out <= psram_dq_out;
                end
            end
            READ:begin
                psram_dq_out <= 16'h0000;
            end
            DONE:begin
                psram_dq_out <= 16'h0000;
            end
            DONE_WAIT:begin
                psram_dq_out <= 16'h0000;
            end
            default:begin
                psram_dq_out <= 16'h0000;
            end
        endcase
    end
end

//psram_dm_out
always @(posedge sys_clk) begin
    if(sys_rst == 1'b0)begin
        psram_dm_out <= 2'b00;
    end
    else if(state_now == WRITE)begin
        if(mend_flag)begin
            psram_dm_out <= byte_write;
        end
        else begin
            psram_dm_out <= psram_dm_out;
        end
    end
    else begin
        psram_dm_out <= 2'b00;
    end
end

//psram_done
always @(posedge sys_clk) begin
    if(sys_rst == 1'b0)begin
        psram_done <= 1'b0;
    end
    else if(state_now == DONE_WAIT && cph_cnt == CPH_TIME - 1'b1)begin
        psram_done <= 1'b1;
    end
    else begin
        psram_done <= 1'b0;
    end
end

//psram_rd_valid
always @(posedge sys_clk) begin
    if(sys_rst == 1'b0)begin
        psram_rd_valid <= 1'b0;
    end
    else if(psram_dm_in_pos | psram_dm_in_neg)begin
        psram_rd_valid <= 1'b1;
    end
    else begin
        psram_rd_valid <= 1'b0;
    end
end

//psram_rd_data
always @(posedge sys_clk) begin
    if(sys_rst == 1'b0)begin
        psram_rd_data <= 16'd0;
    end
    else if(psram_dm_in_pos | psram_dm_in_neg)begin
        psram_rd_data <= psram_dq_in;
    end
    else begin
        psram_rd_data <= psram_rd_data;
    end
end

//psram_wr_valid
assign psram_wr_valid = (state_now == WRITE && data_cnt < burst_len) ? mend_flag : 1'b0;

//psram_dq
assign psram_dq       = (state_now == READ)  ? 16'hzzzz : psram_dq_out;

//psram_dm
assign psram_dm       = (state_now == READ)  ? 2'bzz    : psram_dm_out;

endmodule  //psram_controller
