module hbram_rw #(
    parameter WR_rd_DEPTH  = 256,
    parameter RD_wr_DEPTH  = 256,
    parameter BURST_LENGTH = 64
) (

    input                             ram_clock,

    input                             ram_reset,

    input   [$clog2(WR_rd_DEPTH) : 0] wfifo_rd_count,

    input   [$clog2(RD_wr_DEPTH) : 0] rfifo_wr_count,

    input                             hbc_cal_pass,

    input                             rw_en,
    //1:read   0:write
    input                             rw_ctrl,

    input   [31:0]                    wr_addr_min,

    input   [31:0]                    wr_addr_max,

    input   [31:0]                    rd_addr_min,

    input   [31:0]                    rd_addr_max,

    input                             operating,

    input   [10:0]                    burst_len,

    output  reg                       ram_en,

    output                            ram_rw_ctrl,

    output  [31:0]                    ram_addr,

    output                            ctrl_idle

);

localparam IDLE  = 3'd0;
localparam DONE  = 3'd1;
localparam WRITE = 3'd2;
localparam READ  = 3'd3;

reg        r_operating;
wire       operating_pos;

reg [31:0] wr_addr;
reg [31:0] rd_addr;

reg [2:0]  state_now;
reg [2:0]  state_next;

assign     operating_pos = (~r_operating) & operating;

always @(posedge ram_clock or posedge ram_reset) begin
    if(ram_reset == 1'b1)begin
        r_operating <= 1'b0;
    end
    else begin
        r_operating <= operating;
    end
end

//wr_addr
always @(posedge ram_clock or posedge ram_reset) begin
    if(ram_reset == 1'b1)begin
        wr_addr <= 32'd0;
    end
    else if(state_now == DONE)begin
        wr_addr <= wr_addr_min;
    end
    else if(state_now == WRITE)begin
        if(operating_pos)begin
            wr_addr <= wr_addr + BURST_LENGTH;
        end
        else begin
            wr_addr <= wr_addr;
        end
    end
    else begin
        wr_addr <= wr_addr;
    end
end

//rd_addr
always @(posedge ram_clock or posedge ram_reset) begin
    if(ram_reset == 1'b1)begin
        rd_addr <= 32'd0;
    end
    else if(state_now == DONE)begin
        rd_addr <= rd_addr_min;
    end
    else if(state_now == READ)begin
        if(operating_pos)begin
            rd_addr <= rd_addr + BURST_LENGTH;
        end
        else begin
            rd_addr <= rd_addr;
        end
    end
    else begin
        rd_addr <= rd_addr;
    end
end

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
                if(hbc_cal_pass)begin
                    state_next <= DONE;
                end
                else begin
                    state_next <= IDLE;
                end
            end

            DONE:begin
                if({wfifo_rd_count,1'b0} >= burst_len && rw_en && (~rw_ctrl))begin
                    state_next <= WRITE;
                end
                else if({rfifo_wr_count,1'b0} < burst_len && rw_en && rw_ctrl)begin
                    state_next <= READ;
                end
                else begin
                    state_next <= DONE;
                end
            end

            WRITE:begin
                if(wr_addr == wr_addr_max - BURST_LENGTH && operating_pos)begin
                    state_next <= DONE;
                end
                else begin
                    state_next <= WRITE;
                end
            end

            READ:begin
                if(rd_addr == rd_addr_max - BURST_LENGTH && operating_pos)begin
                    state_next <= DONE;
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

//ram_en
always @(posedge ram_clock or posedge ram_reset) begin
    if(ram_reset == 1'b1)begin
        ram_en <= 1'b0;
    end
    else if(rw_en)begin
        ram_en <= 1'b1;
    end
    else if(operating_pos)begin
        if(wr_addr == wr_addr_max - BURST_LENGTH)begin
            ram_en <= 1'b0;
        end
        else begin
            ram_en <= 1'b1;
        end
    end
    else begin
        ram_en <= 1'b0;
    end
end

//ram_rw_ctrl
assign ram_rw_ctrl = (state_now == WRITE) ? 1'b0 : 1'b1;

//ram_addr
assign ram_addr    = (state_now == WRITE) ? wr_addr : 
                     (state_now == READ)  ? rd_addr : 32'd0;

//ctrl_idle
assign ctrl_idle   = (state_now == IDLE || state_now == DONE) ? 1'b1 : 1'b0;

endmodule
