set TB_NAME tb_hbram
set SWITCH_1 SIM
set SWITCH_2 EFX_IPM

## new lib

vlib work
vmap work work

## load design

vlog -sv        ../sim/tb_hbram.sv
vlog -work work ../sim/clock_gen.v
vlog -work work ../src/hyper_bus.v
vlog -work work ../src/hbram_rw.v
vlog -work work ../sim/EFX_GPIO_model.v
vlog -work work F:/FPGA_Project/IP_lib/user/src/memory/FIFO/DPRAM.v
vlog -sv        F:/FPGA_Project/IP_lib/user/src/memory/FIFO/ecc_encode.sv
vlog -sv        F:/FPGA_Project/IP_lib/user/src/memory/FIFO/ecc_decode.sv
vlog -work work F:/FPGA_Project/IP_lib/user/src/memory/FIFO/async_fifo.v
vlog -sv -sv09compat +define+$SWITCH_1 F:/FPGA_Project/PSRAM/psram/user/sim/W958D6NKY.modelsim.vp 

## sim design

vsim -t ps +notimingchecks -gui -voptargs="+acc" work.$TB_NAME

## add wave

add wave -divider {top_port}

add wave /tb_hbram/sys_clk
add wave /tb_hbram/sys_rst
add wave /tb_hbram/clk_out0
add wave /tb_hbram/locked

add wave /tb_hbram/native_ram_en
add wave /tb_hbram/native_rw_ctrl


add wave -divider {write_port}

add wave /tb_hbram/wr_en
add wave /tb_hbram/wr_data
add wave /tb_hbram/wr_valid
add wave /tb_hbram/wr_full
add wave /tb_hbram/wr_empty
add wave /tb_hbram/WR_wr_count
add wave /tb_hbram/WR_rd_count

add wave -divider {control_port}

add wave /tb_hbram/ram_wr_valid
add wave /tb_hbram/ram_wr_data
add wave /tb_hbram/ram_rd_valid
add wave /tb_hbram/ram_rd_data
add wave /tb_hbram/hbc_cal_pass
add wave /tb_hbram/wr_data_mask
add wave /tb_hbram/ctrl_idle


add wave -divider {hyper_bus_phy_port}

add wave /tb_hbram/hbc_ck_p_hi
add wave /tb_hbram/hbc_ck_p_lo
add wave /tb_hbram/hbc_ck_n_hi
add wave /tb_hbram/hbc_ck_n_lo
add wave /tb_hbram/hbc_cs_n
add wave /tb_hbram/hbc_rst_n
add wave /tb_hbram/hbc_dq_en
add wave /tb_hbram/hbc_dq_out_hi
add wave /tb_hbram/hbc_dq_out_lo
add wave /tb_hbram/hbc_dq_in_hi
add wave /tb_hbram/hbc_dq_in_lo
add wave /tb_hbram/hbc_rwds_en
add wave /tb_hbram/hbc_rwds_out_hi
add wave /tb_hbram/hbc_rwds_out_lo
add wave /tb_hbram/hbc_rwds_in_hi
add wave /tb_hbram/hbc_rwds_in_lo
add wave /tb_hbram/u_hyper_bus/r_data_mask


add wave -divider {read_port}

add wave /tb_hbram/rd_en
add wave /tb_hbram/rd_data
add wave /tb_hbram/rd_valid
add wave /tb_hbram/rd_full
add wave /tb_hbram/rd_empty
add wave /tb_hbram/RD_wr_count
add wave /tb_hbram/RD_rd_count


add wave -divider {hbram_phy_port}

add wave /tb_hbram/ram_rst_n
add wave /tb_hbram/ram_cs_n
add wave /tb_hbram/ram_ck_p
add wave /tb_hbram/ram_ck_n
add wave /tb_hbram/ram_rwds
add wave /tb_hbram/ram_dq

add wave /tb_hbram/u_hyper_bus/state_now
add wave /tb_hbram/u_hyper_bus/init_cnt
add wave /tb_hbram/u_hyper_bus/rst_cnt
add wave /tb_hbram/u_hyper_bus/rst_wait_cnt
add wave /tb_hbram/u_hyper_bus/clk_cnt
add wave /tb_hbram/u_hyper_bus/cph_cnt
add wave /tb_hbram/u_hyper_bus/cr_cnt
add wave /tb_hbram/u_hyper_bus/data_cnt

## run

run 500us
