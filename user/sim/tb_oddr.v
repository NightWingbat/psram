`timescale 1ns /1ps

module tb_oddr();

parameter MAIN_FRE   = 100; //unit MHz
reg                   sys_clk = 0;
reg                   sys_rst = 0;

always begin
    #(500/MAIN_FRE) sys_clk = ~sys_clk;
end

always begin
    #50 sys_rst = 1;
end

reg  [7:0] D0;
reg  [7:0] D1;
wire [7:0] Q0;

always @(posedge sys_clk or negedge sys_rst) begin
	if(sys_rst == 1'b0)begin
		D0 <= 8'd0;
	end
	else begin
		D0 <= D0 + 1'b1;
	end
end

always @(posedge sys_clk or negedge sys_rst) begin
	if(sys_rst == 1'b0)begin
		D1 <= 8'd1;
	end
	else begin
		D1 <= D1 + 1'b1;
	end
end

GSR GSR(.GSRI(1'b1));

genvar i;
generate for(i = 0 ; i < 7; i = i + 1) begin : oddr_test
	ODDR uut(
		.Q0(Q0[i]),
		.Q1(),
		.D0(D0[i]),
		.D1(D1[i]),
		.TX(),
 		.CLK(sys_clk)
	);
end
endgenerate

initial begin            
    $dumpfile("wave.vcd");        
    $dumpvars(0, tb_oddr);    
    #50000 $finish;
end

endmodule  //TOP
