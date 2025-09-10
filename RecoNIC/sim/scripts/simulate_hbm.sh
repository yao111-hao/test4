#!/bin/bash
#==============================================================================
# Copyright (C) 2023, Advanced Micro Devices, Inc. All rights reserved.
# SPDX-License-Identifier: MIT
#
# HBM系统仿真脚本
#==============================================================================
set -Eeuo pipefail

echo -e "simulate_hbm.sh - RecoNIC HBM系统仿真"

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

# 检查HBM IP是否已生成
if [[ ! -d "${build_dir}/ip/design_1" ]]; then
    echo "ERROR: HBM块设计未生成，请先运行:"
    echo "  ./setup_hbm_simulation.sh"
    exit 1
fi

# Questasim主函数
run_questasim_hbm()
{
  echo "current directory: $(pwd)"

  if [[ ! -d "${build_dir}/questa_lib" ]]; then
    mkdir -p ${build_dir}/questa_lib
  fi

  # 检查COMPILED_LIB_DIR环境变量（仅Questasim需要）
  if [[ -z "${COMPILED_LIB_DIR:-}" ]]; then
    echo "ERROR: Please set COMPILED_LIB_DIR environment variable for Questasim"
    echo "Example: export COMPILED_LIB_DIR=/your/vivado/compiled_lib_dir/for/questasim"
    exit 1
  fi

  # 复制modelsim.ini到sim/scripts
  cp ${COMPILED_LIB_DIR}/modelsim.ini ${sim_dir}/scripts

  copy_test_data $1
  
  top_module_name="$3"
  top_module_opt="${top_module_name}_opt"

  # 编译
  source questasim_compile_hbm.do 2>&1 | tee -a questasim_compile_hbm.log

  # 详细设计, reco - RecoNIC工作库 
  vopt -64 +acc=npr -L reco -L xilinx_vip -L xpm -L axi_crossbar_v2_1_26 -L axi_protocol_checker_v2_0_11 -L cam_v2_2_2 -L blk_mem_gen_v8_4_5 -L lib_bmg_v1_0_14 -L fifo_generator_v13_2_6 -L lib_fifo_v1_0_15 -L ernic_v3_1_1 -L unisims_ver -L unimacro_ver -L secureip -work reco reco.$top_module_name reco.glbl -o $top_module_opt -l questasim_elaborate_hbm.log

  # 仿真
  if [[ $2 == "off" ]]; then
    vsim -64 -c -work reco $top_module_opt -do 'add wave -r /*; run -all' -l questasim_simulate_hbm.log
  else
    vsim -64 -work reco $top_module_opt -do 'add wave -r /*; run -all' -l questasim_simulate_hbm.log
  fi
}

# Xsim主函数
run_xsim_hbm()
{
  echo "current directory: $(pwd)"

  copy_test_data $1
  
  top_module_name="$3"

  # 编译
  $VIVADO_DIR/bin/xvlog --incr --relax -work xil_defaultlib -L ernic_v3_1_1 --file xsim_compile_hbm.do 2>&1 | tee xsim_compile_hbm.log
  
  # 详细设计
  $VIVADO_DIR/bin/xelab -debug typical -top $top_module_name -snapshot ${top_module_name}_snapshot xil_defaultlib.$top_module_name xil_defaultlib.glbl -log xsim_elaborate_hbm.log

  # 仿真
  if [[ $2 == "off" ]]; then
    $VIVADO_DIR/bin/xsim ${top_module_name}_snapshot -R -log xsim_simulate_hbm.log
  else
    $VIVADO_DIR/bin/xsim ${top_module_name}_snapshot --gui --log xsim_simulate_hbm.log
  fi
}

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

# 主程序
if [[ $# -lt 3 ]]; then
    echo "Usage: $0 <testcase> <gui_mode> <top_module> [simulator]"
    echo "  testcase:   测试用例名 (如: read_2rdma)"
    echo "  gui_mode:   GUI模式 (on/off)"  
    echo "  top_module: 顶层模块 (如: rn_tb_top_hbm)"
    echo "  simulator:  仿真器 (questasim/xsim, 默认xsim)"
    echo ""
    echo "示例:"
    echo "  $0 read_2rdma on rn_tb_top_hbm xsim"
    echo "  $0 read_2rdma off rn_tb_top_hbm questasim"
    exit 1
fi

testcase_name=$1
gui_mode=$2
top_module_name=$3
simulator=${4:-xsim}

echo "INFO: 运行HBM仿真"
echo "  测试用例: $testcase_name"
echo "  GUI模式: $gui_mode"
echo "  顶层模块: $top_module_name"
echo "  仿真器: $simulator"

# 切换到构建目录
cd $build_dir

case $simulator in
  "questasim")
    run_questasim_hbm $testcase_name $gui_mode $top_module_name
    ;;
  "xsim")
    run_xsim_hbm $testcase_name $gui_mode $top_module_name
    ;;
  *)
    echo "ERROR: 不支持的仿真器: $simulator"
    echo "支持的仿真器: questasim, xsim"
    exit 1
    ;;
esac

echo "INFO: HBM仿真完成"