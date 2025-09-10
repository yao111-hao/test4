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
set sim_script_dir $sim_dir/scripts

# 设置环境变量
set VIVADO_DATA_DIR $env(VIVADO_DIR)/data
set XVIP_PATH $VIVADO_DATA_DIR/xilinx_vip
set XPM_PATH $VIVADO_DATA_DIR/ip/xpm
set USER_LIB ${build_dir}/questa_lib

echo "HBM Questasim编译开始..."
echo "使用库目录: $USER_LIB"

# 创建库目录
file mkdir $USER_LIB
vlib $USER_LIB/reco
vlib $USER_LIB/xilinx_vip
vlib $USER_LIB/xpm

# 映射库
vmap reco $USER_LIB/reco
vmap work $USER_LIB/reco
vmap xilinx_vip $USER_LIB/xilinx_vip
vmap xpm $USER_LIB/xpm

echo "编译标准仿真IP核..."

# 编译AXI BRAM控制器
vcom -64 -work reco \
"${ip_build_dir}/axi_mm_bram/sim/axi_mm_bram.vhd"

vcom -64 -work reco \
"${ip_build_dir}/axi_sys_mm/sim/axi_sys_mm.vhd"

# 编译AXI协议检查器
vlog -64 -work reco \
"${ip_build_dir}/axi_protocol_checker/sim/axi_protocol_checker.v"

# 编译design_1 HBM块设计
echo "编译design_1 HBM块设计..."

set bd_sim_dir "${ip_build_dir}/design_1/sim"

if {[file exists $bd_sim_dir]} {
    echo "找到HBM块设计仿真文件在: $bd_sim_dir"
    
    # 编译design_1_wrapper
    if {[file exists "${bd_sim_dir}/design_1_wrapper.v"]} {
        vlog -64 -work reco "${bd_sim_dir}/design_1_wrapper.v"
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
echo "编译HBM支持文件..."
vlog -64 -work reco -sv \
"${sim_src_dir}/hbm_clk_gen.sv"

# 编译open_nic_shell及其相关文件
echo "编译open_nic_shell..."
set base_src_dir "${root_dir}/base_nics/open-nic-shell/src"

# 编译宏定义文件
vlog -64 -work reco \
"${base_src_dir}/open_nic_shell_macros.vh"

# 编译各个子系统（按依赖顺序）
echo "编译各个子系统..."

# 编译utility模块
vlog -64 -work reco -sv \
"${base_src_dir}/utility/generic_reset.sv" \
"${base_src_dir}/utility/level_trigger_cdc.sv" \
"${base_src_dir}/utility/rr_arbiter.sv" \
"${base_src_dir}/utility/axi_lite_register.sv" \
"${base_src_dir}/utility/axi_lite_slave.sv" \
"${base_src_dir}/utility/axi_stream_register_slice.sv" \
"${base_src_dir}/utility/axi_stream_size_counter.sv" \
"${base_src_dir}/utility/axi_stream_packet_buffer.sv" \
"${base_src_dir}/utility/axi_stream_packet_fifo.sv" \

# 编译system_config
echo "编译system_config..."
vlog -64 -work reco \
"${base_src_dir}/system_config/system_config_register.v" \

vlog -64 -work reco -sv \
"${base_src_dir}/system_config/system_config_address_map.sv" \
"${base_src_dir}/system_config/system_config.sv" \

# 编译qdma_subsystem
echo "编译qdma_subsystem..."
vlog -64 -work reco -sv \
"${base_src_dir}/qdma_subsystem/qdma_subsystem_address_map.sv" \
"${base_src_dir}/qdma_subsystem/qdma_subsystem_register.sv" \
"${base_src_dir}/qdma_subsystem/qdma_subsystem_function_register.sv" \
"${base_src_dir}/qdma_subsystem/qdma_subsystem_function.sv" \
"${base_src_dir}/qdma_subsystem/qdma_subsystem_hash.sv" \
"${base_src_dir}/qdma_subsystem/qdma_subsystem_h2c.sv" \
"${base_src_dir}/qdma_subsystem/qdma_subsystem_c2h.sv" \
"${base_src_dir}/qdma_subsystem/qdma_subsystem.sv" \

# 编译packet_adapter
echo "编译packet_adapter..."
vlog -64 -work reco \
"${base_src_dir}/packet_adapter/packet_adapter_register.v" \

vlog -64 -work reco -sv \
"${base_src_dir}/packet_adapter/packet_adapter_rx.sv" \
"${base_src_dir}/packet_adapter/packet_adapter_tx.sv" \
"${base_src_dir}/packet_adapter/packet_adapter.sv" \

# 编译cmac_subsystem
echo "编译cmac_subsystem..."
vlog -64 -work reco \
"${base_src_dir}/cmac_subsystem/cmac_subsystem_address_map.v" \

vlog -64 -work reco -sv \
"${base_src_dir}/cmac_subsystem/cmac_subsystem_cmac_wrapper.sv" \
"${base_src_dir}/cmac_subsystem/cmac_subsystem.sv" \

# 编译rdma_subsystem
echo "编译rdma_subsystem..."
vlog -64 -work reco -sv \
"${base_src_dir}/rdma_subsystem/rdma_subsystem.sv" \
"${base_src_dir}/rdma_subsystem/rdma_subsystem_wrapper.sv" \

# 编译box模块
echo "编译box模块..."
vlog -64 -work reco -sv \
"${base_src_dir}/box_250mhz/box_250mhz.sv" \
"${base_src_dir}/box_322mhz/box_322mhz.sv" \

# 编译5to2互连模块
vlog -64 -work reco -sv \
"${base_src_dir}/utility/axi_5to2_interconnect_to_sys_mem.sv" \

# 编译主要的open_nic_shell
echo "编译open_nic_shell..."
vlog -64 -work reco -sv \
"${base_src_dir}/open_nic_shell.sv"

# 编译仿真源文件
echo "编译仿真源文件..."

# 编译包文件
vlog -64 -work reco -sv \
"${sim_src_dir}/rn_tb_pkg.sv"

# 编译基础仿真模块
vlog -64 -work reco -sv \
"${sim_src_dir}/init_mem.sv" \
"${sim_src_dir}/axi_read_verify.sv" \
"${sim_src_dir}/rn_tb_generator.sv" \
"${sim_src_dir}/rn_tb_driver.sv" \
"${sim_src_dir}/rn_tb_checker.sv"

# 编译互连模块（仿真中仍需要系统内存连接）
vlog -64 -work reco -sv \
"${sim_src_dir}/axi_5to2_interconnect_to_sys_mem.sv"

# 编译RDMA包装器（如果需要）
if {[file exists "${sim_src_dir}/rdma_rn_wrapper.sv"]} {
    echo "编译RDMA包装器..."
    vlog -64 -work reco -sv \
    "${sim_src_dir}/rdma_rn_wrapper.sv"
}

# 编译testbench文件
echo "编译testbench文件..."

# 编译HBM testbench
vlog -64 -work reco -sv \
"${sim_src_dir}/rn_tb_top_hbm.sv"

# 编译其他标准testbench（如果需要）
if {[file exists "${sim_src_dir}/rn_tb_top.sv"]} {
    vlog -64 -work reco -sv \
    "${sim_src_dir}/rn_tb_top.sv"
}

if {[file exists "${sim_src_dir}/rn_tb_2rdma_top.sv"]} {
    vlog -64 -work reco -sv \
    "${sim_src_dir}/rn_tb_2rdma_top.sv"
}

if {[file exists "${sim_src_dir}/cl_tb_top.sv"]} {
    vlog -64 -work reco -sv \
    "${sim_src_dir}/cl_tb_top.sv"
}

# 编译其他控制模块
if {[file exists "${sim_src_dir}/axil_reg_control.sv"]} {
    vlog -64 -work reco -sv \
    "${sim_src_dir}/axil_reg_control.sv"
}

if {[file exists "${sim_src_dir}/axil_reg_stimulus.sv"]} {
    vlog -64 -work reco -sv \
    "${sim_src_dir}/axil_reg_stimulus.sv"
}

# 编译glbl模块
vlog -64 -work reco \
"$env(VIVADO_DIR)/data/verilog/src/glbl.v"

echo "INFO: HBM Questasim编译完成"