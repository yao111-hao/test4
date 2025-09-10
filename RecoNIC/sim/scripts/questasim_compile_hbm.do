#==============================================================================
# Copyright (C) 2023, Advanced Micro Devices, Inc. All rights reserved.
# SPDX-License-Identifier: MIT
#
# Questasim编译脚本 - 支持HBM系统
#==============================================================================

set root_dir [file normalize ../..]
set sim_dir $root_dir/sim
set sim_src_dir $sim_dir/src
set build_dir $sim_dir/build
set ip_build_dir $build_dir/ip

# 创建work library
vlib work
vlib reco
vmap work work
vmap reco reco

# 编译Xilinx仿真库（使用预编译的库）
# 注意：需要预先编译Vivado仿真库

# 编译标准IP核
echo "编译标准IP核..."

# 编译AXI BRAM控制器
vcom -64 -work reco \
"../build/ip/axi_mm_bram/hdl/axi_bram_ctrl_v4_1_rfs.vhd" \
"../build/ip/axi_mm_bram/hdl/blk_mem_gen_v8_4_rfs.vhd" \
"../build/ip/axi_mm_bram/sim/axi_mm_bram.vhd" \

# 编译系统内存模型
vcom -64 -work reco \
"../build/ip/axi_sys_mm/sim/axi_sys_mm.vhd" \

# 编译AXI协议检查器
vlog -64 -work reco \
"../build/ip/axi_protocol_checker/sim/axi_protocol_checker.v" \

# 编译HBM块设计
echo "编译HBM块设计..."

# 编译块设计中的IP文件
set bd_sim_dir "../build/ip/design_1/sim"
if {[file exists $bd_sim_dir]} {
    # 编译块设计仿真文件
    set sim_files [glob -nocomplain "$bd_sim_dir/*.vhd" "$bd_sim_dir/*.v" "$bd_sim_dir/*/*.vhd" "$bd_sim_dir/*/*.v"]
    foreach sim_file $sim_files {
        if {[string match "*.vhd" $sim_file]} {
            vcom -64 -work reco $sim_file
        } elseif {[string match "*.v" $sim_file]} {
            vlog -64 -work reco $sim_file
        }
    }
    
    # 编译design_1的wrapper
    if {[file exists "$bd_sim_dir/design_1_wrapper.v"]} {
        vlog -64 -work reco "$bd_sim_dir/design_1_wrapper.v"
    }
} else {
    echo "WARNING: HBM块设计仿真文件不存在，请先运行 setup_hbm_simulation.sh"
}

# 编译HBM时钟生成器
vlog -64 -incr -work reco \
"$sim_src_dir/hbm_clk_gen.sv" \

# 编译HBM系统仿真包装器
vlog -64 -incr -work reco \
"$sim_src_dir/design_1_sim_wrapper.sv" \

# 编译主要的RecoNIC源文件
echo "编译RecoNIC源文件..."

# 编译包文件
vlog -64 -incr -work reco -sv \
"$sim_src_dir/rn_tb_pkg.sv"

# 编译基础模块
vlog -64 -incr -work reco -sv \
"$sim_src_dir/init_mem.sv" \
"$sim_src_dir/axi_read_verify.sv" \
"$sim_src_dir/rn_tb_generator.sv" \
"$sim_src_dir/rn_tb_driver.sv" \
"$sim_src_dir/rn_tb_checker.sv" \

# 编译互连模块
vlog -64 -incr -work reco -sv \
"$sim_src_dir/axi_3to1_interconnect_to_dev_mem.sv" \
"$sim_src_dir/axi_5to2_interconnect_to_sys_mem.sv" \
"$sim_src_dir/axil_3to1_crossbar_wrapper.sv" \

# 编译RDMA包装器
vlog -64 -incr -work reco -sv \
"$sim_src_dir/rdma_rn_wrapper.sv" \

# 编译主要testbench文件
echo "编译testbench文件..."

# 编译标准testbench
vlog -64 -incr -work reco -sv \
"$sim_src_dir/rn_tb_top.sv" \
"$sim_src_dir/rn_tb_2rdma_top.sv" \
"$sim_src_dir/cl_tb_top.sv" \

# 编译HBM testbench
vlog -64 -incr -work reco -sv \
"$sim_src_dir/rn_tb_top_hbm.sv" \

# 编译其他控制模块
vlog -64 -incr -work reco -sv \
"$sim_src_dir/axil_reg_control.sv" \
"$sim_src_dir/axil_reg_stimulus.sv" \

# 编译glbl模块
vlog -64 -work reco \
"$VIVADO_DIR/data/verilog/src/glbl.v"

echo "INFO: Questasim编译完成（支持HBM）"
