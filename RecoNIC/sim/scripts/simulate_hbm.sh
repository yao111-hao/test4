#!/bin/bash
#==============================================================================
# Copyright (C) 2023, Advanced Micro Devices, Inc. All rights reserved.
# SPDX-License-Identifier: MIT
#
# HBM系统Questasim仿真脚本（仅支持Questasim）
#==============================================================================
set -Eeuo pipefail

echo -e "simulate_hbm.sh - RecoNIC HBM系统仿真（仅支持Questasim）"

VIVADO_VERSION=2021.2
QUESTA_VERSION=2020.4

cur_dir=$(pwd)
sim_dir=$(dirname $cur_dir)
build_dir=${sim_dir}/build
root_dir=$(dirname $sim_dir)
sim_src_dir=${sim_dir}/src
sim_script_dir=${sim_dir}/scripts

# 检查环境变量
if [[ -z "${VIVADO_DIR:-}" ]]; then
    echo "ERROR: Please set VIVADO_DIR environment variable"
    echo "Example: export VIVADO_DIR=/your/vivado/installation/path/Vivado/2021.2"
    exit 1
fi

if [[ -z "${COMPILED_LIB_DIR:-}" ]]; then
    echo "ERROR: Please set COMPILED_LIB_DIR environment variable for Questasim"
    echo "Example: export COMPILED_LIB_DIR=/your/vivado/compiled_lib_dir/for/questasim"
    exit 1
fi

# 检查HBM IP是否已生成
if [[ ! -d "${build_dir}/ip/design_1" ]]; then
    echo "ERROR: design_1 HBM块设计未生成，请先运行:"
    echo "  ./setup_hbm_simulation.sh"
    exit 1
fi

copy_test_data()
{
  testcase_name=$1
  testcase_dir=${sim_dir}/testcases/${testcase_name}
  
  if [[ ! -d "$testcase_dir" ]]; then
    echo "ERROR: Testcase directory $testcase_dir does not exist"
    exit 1
  fi

  # 复制测试数据到当前目录
  find ${sim_dir}/build -name "*.txt" -type f -delete  
  find ${sim_dir}/build -name "*.cfg" -type f -delete
  
  cp ${sim_dir}/build/*.txt . 2>/dev/null || true
  cp ${sim_dir}/build/*.cfg . 2>/dev/null || true
  
  echo "INFO: 测试数据已复制到 $(pwd)"
}

# Questasim HBM仿真主函数
run_questasim_hbm()
{
  echo "当前目录: $(pwd)"

  if [[ ! -d "${build_dir}/questa_lib" ]]; then
    mkdir -p ${build_dir}/questa_lib
  fi

  # 复制modelsim.ini到sim/scripts
  cp ${COMPILED_LIB_DIR}/modelsim.ini ${sim_dir}/scripts

  copy_test_data $1
  
  top_module_name="$3"
  top_module_opt="${top_module_name}_opt"

  echo "INFO: 编译HBM仿真..."
  # 编译
  source questasim_compile_hbm.do 2>&1 | tee -a questasim_compile_hbm.log

  if [[ $? -ne 0 ]]; then
    echo "ERROR: 编译失败，请检查 questasim_compile_hbm.log"
    exit 1
  fi

  echo "INFO: 详细设计HBM仿真..."
  # 详细设计, reco - RecoNIC工作库 
  vopt -64 +acc=npr \
    -L reco \
    -L xilinx_vip \
    -L xpm \
    -L axi_crossbar_v2_1_26 \
    -L axi_protocol_checker_v2_0_11 \
    -L axi_clock_converter_v2_1_24 \
    -L smartconnect_v1_0 \
    -L proc_sys_reset_v5_0_13 \
    -L clk_wiz_v6_0_5 \
    -L xlconstant_v1_1_7 \
    -L hbm_v1_0_13 \
    -L cam_v2_2_2 \
    -L blk_mem_gen_v8_4_5 \
    -L lib_bmg_v1_0_14 \
    -L fifo_generator_v13_2_6 \
    -L lib_fifo_v1_0_15 \
    -L ernic_v3_1_1 \
    -L unisims_ver \
    -L unimacro_ver \
    -L secureip \
    -work reco \
    reco.$top_module_name reco.glbl \
    -o $top_module_opt \
    -l questasim_elaborate_hbm.log

  if [[ $? -ne 0 ]]; then
    echo "ERROR: 详细设计失败，请检查 questasim_elaborate_hbm.log"
    exit 1
  fi

  echo "INFO: 运行HBM仿真..."
  # 仿真
  if [[ $2 == "off" ]]; then
    vsim -64 -c -work reco $top_module_opt \
      -do 'add wave -r /*; run -all' \
      -l questasim_simulate_hbm.log
  else
    vsim -64 -work reco $top_module_opt \
      -do 'add wave -r /*; run -all' \
      -l questasim_simulate_hbm.log
  fi
}

# 主程序
if [[ $# -lt 3 ]]; then
    echo "Usage: $0 <testcase> <gui_mode> <top_module>"
    echo "  testcase:   测试用例名 (如: read_2rdma_hbm)"
    echo "  gui_mode:   GUI模式 (on/off)"  
    echo "  top_module: 顶层模块 (如: rn_tb_top_hbm)"
    echo ""
    echo "示例:"
    echo "  $0 read_2rdma_hbm on rn_tb_top_hbm"
    echo "  $0 write_2rdma_hbm off rn_tb_top_hbm"
    exit 1
fi

testcase_name=$1
gui_mode=$2
top_module_name=$3

echo "INFO: 运行HBM Questasim仿真"
echo "  测试用例: $testcase_name"
echo "  GUI模式: $gui_mode"
echo "  顶层模块: $top_module_name"
echo "  仿真器: Questasim (HBM仅支持Questasim)"

# 切换到构建目录
cd $build_dir

run_questasim_hbm $testcase_name $gui_mode $top_module_name

echo "INFO: HBM Questasim仿真完成"