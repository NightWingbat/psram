set TB_NAME tb_psram_controller
set SWITCH_1 SIM
set SWITCH_2 EFX_IPM

## new lib

vlib work
vmap work work

## load design

vlog +define+$SWITCH_1+$SWITCH_2 F:/FPGA_Project/PSRAM/psram/user/sim/tb_psram_controller.v
vlog +define+$SWITCH_1+$SWITCH_2 F:/FPGA_Project/PSRAM/psram/user/src/psram_rw.v
vlog +define+$SWITCH_1+$SWITCH_2 F:/FPGA_Project/PSRAM/psram/user/src/psram_controller.v
vlog +define+$SWITCH_1+$SWITCH_2 F:/FPGA_Project/PSRAM/psram/user/src/psram_phy.v
vlog +define+$SWITCH_1+$SWITCH_2 F:/FPGA_Project/PSRAM/psram/user/sim/clock_gen.v
vlog +define+$SWITCH_1+$SWITCH_2 E:/Software/Gowin/EDA/Gowin/Gowin_V1.9.9.03_x64/IDE/simlib/gw5a/prim_sim.v

vlog -sv -sv09compat +define+$SWITCH_1 F:/FPGA_Project/PSRAM/psram/user/sim/W958D6NKY.modelsim.vp 

## sim design

vsim -t ps +notimingchecks -gui -voptargs="+acc" work.$TB_NAME

## add wave

add wave -divider {psram_top}

add wave /tb_psram_controller/clk_400m
add wave /tb_psram_controller/clk_out0
add wave /tb_psram_controller/clk_out90
add wave /tb_psram_controller/init_cable_complete
add wave /tb_psram_controller/ctrl_idle
add wave /tb_psram_controller/o_psram_clk
add wave /tb_psram_controller/o_psram_ce
add wave /tb_psram_controller/io_psram_dq
add wave /tb_psram_controller/io_psram_dm
add wave /tb_psram_controller/ram_en
add wave /tb_psram_controller/rw_ctrl
add wave /tb_psram_controller/ram_data_in
add wave /tb_psram_controller/ram_data_out
add wave /tb_psram_controller/ram_rd_valid
add wave /tb_psram_controller/ram_wr_valid

add wave -divider {u_psram_controller}

add wave /tb_psram_controller/u_psram_controller/state_now
add wave /tb_psram_controller/u_psram_controller/init_cnt
add wave /tb_psram_controller/u_psram_controller/clk_cnt
add wave /tb_psram_controller/u_psram_controller/rst_cnt
add wave /tb_psram_controller/u_psram_controller/cph_cnt
add wave /tb_psram_controller/u_psram_controller/mr_cnt
add wave /tb_psram_controller/u_psram_controller/data_cnt
add wave /tb_psram_controller/u_psram_controller/ram_data_in
add wave /tb_psram_controller/u_psram_controller/psram_clk
add wave /tb_psram_controller/u_psram_controller/psram_ce
add wave /tb_psram_controller/u_psram_controller/dq_en
add wave /tb_psram_controller/u_psram_controller/dq_out_hi
add wave /tb_psram_controller/u_psram_controller/dq_out_lo

add wave -divider {u_psram_phy}

add wave /tb_psram_controller/u_psram_phy/psram_dm_en
add wave /tb_psram_controller/u_psram_phy/psram_dq_en
add wave /tb_psram_controller/u_psram_phy/o_psram_dm
add wave /tb_psram_controller/u_psram_phy/o_psram_dq
add wave /tb_psram_controller/u_psram_phy/io_psram_dm
add wave /tb_psram_controller/u_psram_phy/io_psram_dq

#add wave -divider {u_psram_rw}

#add wave /tb_psram_controller/u_psram_rw/state_now
#add wave /tb_psram_controller/u_psram_rw/wait_cnt
#add wave /tb_psram_controller/u_psram_rw/wr_cnt
#add wave /tb_psram_controller/u_psram_rw/rd_cnt

## run

run 200us
