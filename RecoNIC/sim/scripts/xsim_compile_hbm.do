#==============================================================================
# Copyright (C) 2023, Advanced Micro Devices, Inc. All rights reserved.
# SPDX-License-Identifier: MIT
#
# Xsim编译脚本 - 支持HBM系统
#==============================================================================

set root_dir [file normalize ../..]
set sim_dir $root_dir/sim
set sim_src_dir $sim_dir/src
set build_dir $sim_dir/build
set ip_build_dir $build_dir/ip

# 编译标准IP核
echo "INFO: 编译标准IP核..."

vlog -work xil_defaultlib -64 -incr -mfcu \
"../build/ip/axi_mm_bram/sim/axi_mm_bram.vhd" \

vlog -work xil_defaultlib -64 -incr -mfcu \
"../build/ip/axi_sys_mm/sim/axi_sys_mm.vhd" \

vlog -work xil_defaultlib -64 -incr -mfcu \
"../build/ip/axi_protocol_checker/sim/axi_protocol_checker.v" \

# 编译HBM块设计相关文件
echo "INFO: 编译HBM块设计..."

set bd_sim_dir "../build/ip/design_1/sim"

# 检查HBM块设计文件是否存在
if {[file exists $bd_sim_dir]} {
    # 编译块设计中的所有IP仿真文件
    set bd_verilog_files [glob -nocomplain "$bd_sim_dir/*.v" "$bd_sim_dir/*/*.v"]
    foreach vlog_file $bd_verilog_files {
        vlog -work xil_defaultlib -64 -incr -mfcu $vlog_file
    }
    
    set bd_vhdl_files [glob -nocomplain "$bd_sim_dir/*.vhd" "$bd_sim_dir/*/*.vhd"]
    foreach vhdl_file $bd_vhdl_files {
        vlog -work xil_defaultlib -64 -incr -mfcu $vhdl_file
    }
    
    # 编译design_1的wrapper（如果存在）
    if {[file exists "${bd_sim_dir}/design_1_wrapper.v"]} {
        vlog -work xil_defaultlib -64 -incr -mfcu "${bd_sim_dir}/design_1_wrapper.v"
    }
    
    echo "INFO: HBM块设计文件编译完成"
} else {
    echo "WARNING: HBM块设计文件不存在于 $bd_sim_dir"
    echo "请先运行: ./setup_hbm_simulation.sh"
}

# 编译HBM仿真支持文件
echo "INFO: 编译HBM仿真支持文件..."

vlog -work xil_defaultlib -64 -incr -mfcu -sv \
"$sim_src_dir/hbm_clk_gen.sv" \

vlog -work xil_defaultlib -64 -incr -mfcu -sv \
"$sim_src_dir/design_1_sim_wrapper.sv" \

# 编译RecoNIC源文件
echo "INFO: 编译RecoNIC源文件..."

vlog -work xil_defaultlib -64 -incr -mfcu -sv \
"$sim_src_dir/rn_tb_pkg.sv" \
"$sim_src_dir/init_mem.sv" \
"$sim_src_dir/axi_read_verify.sv" \
"$sim_src_dir/rn_tb_generator.sv" \
"$sim_src_dir/rn_tb_driver.sv" \
"$sim_src_dir/rn_tb_checker.sv" \
"$sim_src_dir/axi_3to1_interconnect_to_dev_mem.sv" \
"$sim_src_dir/axi_5to2_interconnect_to_sys_mem.sv" \
"$sim_src_dir/axil_3to1_crossbar_wrapper.sv" \
"$sim_src_dir/rdma_rn_wrapper.sv" \
"$sim_src_dir/axil_reg_control.sv" \
"$sim_src_dir/axil_reg_stimulus.sv" \

# 编译testbench文件
echo "INFO: 编译testbench文件..."

vlog -work xil_defaultlib -64 -incr -mfcu -sv \
"$sim_src_dir/rn_tb_top.sv" \
"$sim_src_dir/rn_tb_2rdma_top.sv" \
"$sim_src_dir/cl_tb_top.sv" \
"$sim_src_dir/rn_tb_top_hbm.sv" \

# 编译glbl
vlog -work xil_defaultlib -64 -incr -mfcu \
"$VIVADO_DIR/data/verilog/src/glbl.v"

echo "INFO: Xsim编译完成（支持HBM）"
