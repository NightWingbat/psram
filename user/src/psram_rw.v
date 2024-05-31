module psram_rw #(
    parameter BIT_MODE  = 16,
    parameter WRAP_MODE = "wrap"
) (
    input              sys_clk,
    input              sys_rst,

    input              init_cable_complete,

    input              psram_done,
    input              psram_wr_valid,
    input              psram_rd_valid,

    output  reg        psram_exe,
    output  reg        rw_ctrl,
    output             bit_ctrl,
    output      [1:0]  byte_write,
    output             wrap_in,
    output      [31:0] addr_in,
    output      [15:0] data_in,
    output      [11:0] burst_len,
    output      [1:0]  command_in
);

localparam IDLE    = 3'd0;
localparam WRITE   = 3'd1;
localparam WR_WAIT = 3'd2;
localparam WR_DONE = 3'd3;
localparam READ    = 3'd4;
localparam RD_WAIT = 3'd5;
localparam RD_DONE = 3'd6;

reg [2:0]  state_now;
reg [2:0]  state_next;

reg [11:0] wr_cnt;
reg [11:0] rd_cnt;

assign bit_ctrl   = (BIT_MODE == 16) ? 1'b1 : 1'b0;

assign byte_write = 2'b00;

assign wrap_in    = (WRAP_MODE == "wrap") ? 1'b0 : 1'b1;

assign addr_in    = 32'd0;

assign burst_len  = 12'd32;

assign command_in = 2'b00;

assign data_in    = {4'd0,wr_cnt};

always @(posedge sys_clk or negedge sys_rst) begin
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
                if(init_cable_complete)begin
                    state_next <= WRITE;
                end
                else begin
                    state_next <= IDLE;
                end
            end
            WRITE:begin
                state_next <= WR_WAIT;
            end
            WR_WAIT:begin
                if(wr_cnt == burst_len)begin
                    state_next <= WR_DONE;
                end
                else begin
                    state_next <= WR_WAIT;
                end
            end
            WR_DONE:begin
                if(psram_done)begin
                    state_next <= READ;
                end
                else begin
                    state_next <= WR_DONE;
                end
            end
            READ:begin
                state_next <= RD_WAIT;
            end
            RD_WAIT:begin
                if(rd_cnt == burst_len)begin
                    state_next <= RD_DONE;
                end
                else begin
                    state_next <= RD_WAIT;
                end
            end
            RD_DONE:begin
                state_next <= WRITE;
            end
            default:begin
                state_next <= IDLE;
            end
        endcase
    end
end

//psram_exe
always @(posedge sys_clk or negedge sys_rst) begin
    if(sys_rst == 1'b0)begin
        psram_exe <= 1'b0;
    end
    else if(psram_done)begin
        psram_exe <= 1'b1;
    end
    else begin
        psram_exe <= 1'b0;
    end
end

//rw_ctrl
always @(posedge sys_clk or negedge sys_rst) begin
    if(sys_rst == 1'b0)begin
        rw_ctrl <= 1'b0;
    end
    else if(state_now == WRITE)begin
        rw_ctrl <= 1'b1;
    end
    else if(state_now == READ)begin
        rw_ctrl <= 1'b0;
    end
    else begin
        rw_ctrl <= rw_ctrl;
    end
end

//wr_cnt
always @(posedge sys_clk or negedge sys_rst) begin
    if(sys_rst == 1'b0)begin
        wr_cnt <= 12'd0;
    end
    else if(state_now == WR_WAIT)begin
        if(psram_wr_valid)
            wr_cnt <= wr_cnt + 1'b1;
        else
            wr_cnt <= wr_cnt;
    end
    else begin
        wr_cnt <= 12'd0;
    end
end

//rd_cnt
always @(posedge sys_clk or negedge sys_rst) begin
    if(sys_rst == 1'b0)begin
        rd_cnt <= 12'd0;
    end
    else if(state_now == RD_WAIT)begin
        if(psram_rd_valid)
            rd_cnt <= rd_cnt + 1'b1;
        else
            rd_cnt <= rd_cnt;
    end
    else begin
        rd_cnt <= 12'd0;
    end
end

endmodule
