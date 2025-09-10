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

# 编译design_1 HBM块设计
echo "编译design_1 HBM块设计..."

# 设置块设计仿真目录
set bd_sim_dir "../build/ip/design_1/sim"

if {[file exists $bd_sim_dir]} {
    echo "找到HBM块设计仿真文件在: $bd_sim_dir"
    
    # 编译design_1_wrapper
    if {[file exists "$bd_sim_dir/design_1_wrapper.v"]} {
        vlog -64 -work reco "$bd_sim_dir/design_1_wrapper.v"
        echo "design_1_wrapper.v 编译完成"
    } else {
        echo "ERROR: design_1_wrapper.v 不存在于 $bd_sim_dir"
        echo "请检查 design_1 块设计是否正确生成"
        exit 1
    }
    
    echo "design_1 HBM块设计编译完成"
} else {
    echo "ERROR: HBM块设计仿真文件不存在于 $bd_sim_dir"
    echo "请先运行: cd scripts && ./setup_hbm_simulation.sh"
    exit 1
}

# 编译HBM时钟生成器
vlog -64 -incr -work reco \
"$sim_src_dir/hbm_clk_gen.sv" \

# 编译主要的RecoNIC源文件
echo "编译RecoNIC源文件..."

# 编译包文件
vlog -64 -incr -work reco -sv \
"$sim_src_dir/rn_tb_pkg.sv"

# 编译open_nic_shell及其相关文件
echo "编译open_nic_shell..."
set base_src_dir "$root_dir/base_nics/open-nic-shell/src"

# 编译macros文件
vlog -64 -incr -work reco \
"$base_src_dir/open_nic_shell_macros.vh" \

# 编译各个子系统
vlog -64 -incr -work reco -sv \
"$base_src_dir/system_config/system_config.sv" \
"$base_src_dir/system_config/system_config_register.v" \
"$base_src_dir/system_config/system_config_address_map.sv" \
"$base_src_dir/qdma_subsystem/qdma_subsystem.sv" \
"$base_src_dir/packet_adapter/packet_adapter.sv" \
"$base_src_dir/packet_adapter/packet_adapter_rx.sv" \
"$base_src_dir/packet_adapter/packet_adapter_tx.sv" \
"$base_src_dir/packet_adapter/packet_adapter_register.v" \
"$base_src_dir/cmac_subsystem/cmac_subsystem.sv" \
"$base_src_dir/rdma_subsystem/rdma_subsystem_wrapper.sv" \
"$base_src_dir/rdma_subsystem/rdma_subsystem.sv" \
"$base_src_dir/box_250mhz/box_250mhz.sv" \
"$base_src_dir/box_322mhz/box_322mhz.sv" \
"$base_src_dir/utility/axi_5to2_interconnect_to_sys_mem.sv" \

# 编译主要的open_nic_shell
vlog -64 -incr -work reco -sv \
"$base_src_dir/open_nic_shell.sv" \

# 编译基础模块
vlog -64 -incr -work reco -sv \
"$sim_src_dir/init_mem.sv" \
"$sim_src_dir/axi_read_verify.sv" \
"$sim_src_dir/rn_tb_generator.sv" \
"$sim_src_dir/rn_tb_driver.sv" \
"$sim_src_dir/rn_tb_checker.sv" \

# 编译互连模块（仿真中仍需要这些用于系统内存连接）
vlog -64 -incr -work reco -sv \
"$sim_src_dir/axi_5to2_interconnect_to_sys_mem.sv" \

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