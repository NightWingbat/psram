module psram_rw #(
    parameter BIT_WIDTH  = 16,
    parameter BURST_LEN  = 32
) (
    input                         ram_clk,
    input                         ram_rst,

    input                         init_cable_complete,
    input                         ctrl_idle,

    input                         ram_wr_valid,
    input                         ram_rd_valid,

    output  [31:0]                addr_in,
    output                        rw_ctrl,
    output                        ram_en,
    output  reg [BIT_WIDTH*2-1:0] ram_data_in

);

localparam IDLE  = 3'd0;
localparam WAIT1 = 3'd1;
localparam WRITE = 3'd2;
localparam WAIT2 = 3'd3;
localparam READ  = 3'd4;

reg [5:0]  wait_cnt;
reg [11:0] wr_cnt;
reg [11:0] rd_cnt;

reg [2:0]  state_now;
reg [2:0]  state_next;

assign     addr_in = 32'd4;
assign     rw_ctrl = (state_now == WAIT1) ? 1'b1 : (state_now == WAIT2) ? 1'b0 : 1'b1;
assign     ram_en  = (wait_cnt == 6'd63) ? 1'b1 : 1'b0;

//wait_cnt
always @(posedge ram_clk or negedge ram_rst) begin
    if(ram_rst == 1'b0)begin
        wait_cnt <= 6'd0;
    end
    else if((state_now == WAIT1 || state_now == WAIT2) && ctrl_idle == 1'b1)begin
        wait_cnt <= wait_cnt + 1'b1;
    end
    else begin
        wait_cnt <= 6'd0;
    end
end

//wr_cnt
always @(posedge ram_clk or negedge ram_rst) begin
    if(ram_rst == 1'b0)begin
        wr_cnt <= 12'd0;
    end
    else if(state_now == WRITE && ram_wr_valid == 1'b1)begin
        if(wr_cnt < BURST_LEN - 2)begin
            wr_cnt <= wr_cnt + 2'd2;
        end
        else begin
            wr_cnt <= wr_cnt;
        end
    end
    else begin
        wr_cnt <= 12'd0;
    end
end

//rd_cnt
always @(posedge ram_clk or negedge ram_rst) begin
    if(ram_rst == 1'b0)begin
        rd_cnt <= 12'd0;
    end
    else if(state_now == READ && ram_rd_valid == 1'b1)begin
        if(rd_cnt < BURST_LEN - 2)begin
            rd_cnt <= rd_cnt + 2'd2;
        end
        else begin
            rd_cnt <= rd_cnt;
        end
    end
    else begin
        rd_cnt <= 12'd0;
    end
end

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
                if(init_cable_complete)begin
                    state_next <= WAIT1;
                end
                else begin
                    state_next <= IDLE;
                end
            end
            WAIT1:begin
                if(wait_cnt == 6'd63)begin
                    state_next <= WRITE;
                end
                else begin
                    state_next <= WAIT1;
                end
            end
            WRITE:begin
                if(wr_cnt == BURST_LEN - 2)begin
                    state_next <= WAIT2;
                end
                else begin
                    state_next <= WRITE;
                end
            end
            WAIT2:begin
                if(wait_cnt == 6'd63)begin
                    state_next <= READ;
                end
                else begin
                    state_next <= WAIT2;
                end
            end
            READ:begin
                if(rd_cnt == BURST_LEN - 2)begin
                    state_next <= WAIT1;
                end
                else begin
                    state_next <= READ;
                end
            end
            default:begin
                state_next <= IDLE;
            end
        endcase
    end
end

//ram_data_in
always @(posedge ram_clk or negedge ram_rst) begin
    if(ram_rst == 1'b0)begin
        ram_data_in <= 32'h04060103;
    end
    else if(state_now == WRITE && ram_wr_valid == 1'b1)begin
        ram_data_in[7:0]   <= ram_data_in[7:0]   + 1'b1;
		ram_data_in[15:8]  <= ram_data_in[15:8]  + 1'b1;
		ram_data_in[23:16] <= ram_data_in[23:16] + 1'b1;
		ram_data_in[31:24] <= ram_data_in[31:24] + 1'b1;
    end
end

endmodule
