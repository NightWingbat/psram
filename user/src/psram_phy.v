module psram_phy #(
    parameter DEVICE     = "Gowin",
    parameter BIT_WIDTH  = 16
) (
    input                       ram_clk,
    input                       ram_clk_p,

    //psram_dq
    input                       dq_en,

    input   [BIT_WIDTH - 1 : 0] dq_out_hi,
    input   [BIT_WIDTH - 1 : 0] dq_out_lo,

    output  [BIT_WIDTH - 1 : 0] dq_in_hi,
    output  [BIT_WIDTH - 1 : 0] dq_in_lo,

    //psram_dm
    input                       dm_en,

    input   [1:0]               dm_out_hi,
    input   [1:0]               dm_out_lo,

    output  [1:0]               dm_in_hi,
    output  [1:0]               dm_in_lo,

    //psram_clk and psram_ce
    input                       psram_clk,
    input                       psram_ce,

    //phy_inout
    output                      o_psram_clk,
    output                      o_psram_ce,
    inout   [BIT_WIDTH - 1 : 0] io_psram_dq,
    inout   [1:0]               io_psram_dm

);

wire [1:0]               o_psram_dm;
wire [1:0]               psram_dm_en;

wire [BIT_WIDTH - 1 : 0] o_psram_dq;
wire [BIT_WIDTH - 1 : 0] psram_dq_en;

assign io_psram_dm[0] = psram_dm_en[0] ? o_psram_dm[0] : 1'bz;
assign io_psram_dm[1] = psram_dm_en[1] ? o_psram_dm[1] : 1'bz;

ODDR oddr_clk(
    .CLK(ram_clk_p), .D0(psram_clk), .D1(1'b0), .Q0(o_psram_clk));

ODDR oddr_ce(
    .CLK(ram_clk), .D0(psram_ce), .D1(psram_ce), .Q0(o_psram_ce));

ODDR oddr_dm_0(
    .CLK(ram_clk), .D0(dm_out_lo[1]), .D1(dm_out_lo[0]), .TX(dm_en), .Q0(o_psram_dm[0]), .Q1(psram_dm_en[0]));

ODDR oddr_dm_1(
    .CLK(ram_clk), .D0(dm_out_hi[1]), .D1(dm_out_hi[0]), .TX(dm_en), .Q0(o_psram_dm[1]), .Q1(psram_dm_en[1]));

genvar i;
generate for(i = 0 ; i < BIT_WIDTH; i = i + 1) begin : psram_dq_o

    ODDR oddr_dq(
            .CLK(ram_clk), .D0(dq_out_hi[i]), .D1(dq_out_lo[i]), .TX(dq_en), .Q0(o_psram_dq[i]), .Q1(psram_dq_en[i]));
            
    assign io_psram_dq[i] = psram_dq_en[i] ? o_psram_dq[i] : 1'bz;

end
endgenerate

IDDR iddr_dm_0(
    .CLK(ram_clk), .D(io_psram_dm[0]), .Q0(dm_in_lo[1]), .Q1(dm_in_lo[0])
);

IDDR iddr_dm_1(
    .CLK(ram_clk), .D(io_psram_dm[1]), .Q0(dm_in_hi[1]), .Q1(dm_in_hi[0])
);

genvar j;
generate for(j = 0 ; j < BIT_WIDTH; j = j + 1) begin : psram_dq_i
    IDDR iddr_dq(
            .CLK(ram_clk), .D(io_psram_dq[j]), .Q0(dq_in_hi[j]), .Q1(dq_in_lo[j]));
end
endgenerate

endmodule  //psram_phy
