del wave wave.vcd
iverilog -o wave tb_psram_controller.v E:\fpga\project\PSRAM\psram\user\src\psram_controller.v
vvp -n wave -lxt
gtkwave wave.vcd
pause
