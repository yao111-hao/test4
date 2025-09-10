#!/bin/bash
#==============================================================================
# Copyright (C) 2023, Advanced Micro Devices, Inc. All rights reserved.
# SPDX-License-Identifier: MIT
#
# 设置HBM仿真环境的脚本
#==============================================================================
set -Eeuo pipefail

echo "setup_hbm_simulation.sh - 设置RecoNIC HBM仿真环境（仅支持Questasim）"

VIVADO_VERSION=2021.2

# 检查环境变量
if [[ -z "${VIVADO_DIR:-}" ]]; then
    echo "ERROR: Please set VIVADO_DIR environment variable"
    echo "Example: export VIVADO_DIR=/your/vivado/installation/path/Vivado/2021.2"
    exit 1
fi

if [[ -z "${COMPILED_LIB_DIR:-}" ]]; then
    echo "WARNING: COMPILED_LIB_DIR未设置，运行仿真时需要此环境变量"
    echo "Example: export COMPILED_LIB_DIR=/your/vivado/compiled_lib_dir/for/questasim"
fi

cur_dir=$(pwd)
sim_dir=$(dirname $cur_dir)
build_dir=${sim_dir}/build
root_dir=$(dirname $sim_dir)
sim_src_dir=${sim_dir}/src
sim_script_dir=${sim_dir}/scripts

echo "当前目录: $(pwd)"
echo "仿真目录: $sim_dir"
echo "构建目录: $build_dir" 
echo "根目录: $root_dir"

# 创建构建目录
mkdir -p $build_dir
mkdir -p ${build_dir}/ip
mkdir -p ${build_dir}/managed_ip

# 检查是否需要板级文件仓库
if [[ -n "${BOARD_REPO:-}" ]]; then
    echo "INFO: 使用板级仓库: $BOARD_REPO"
    board_repo_arg="-board_repo $BOARD_REPO"
else
    echo "INFO: 未设置BOARD_REPO，如果出现板级定义错误，请设置此环境变量"
    board_repo_arg=""
fi

echo "INFO: 正在生成HBM仿真环境..."

# 第一步：生成基础仿真IP
echo "============================================"
echo "步骤1: 生成基础仿真IP"
echo "============================================"
$VIVADO_DIR/bin/vivado -mode batch -source gen_vivado_ip_hbm.tcl -tclargs $board_repo_arg

if [[ $? -ne 0 ]]; then
    echo "ERROR: 基础IP生成失败"
    exit 1
fi

echo "INFO: 基础IP生成成功"

# 第二步：生成design_1 HBM块设计
echo ""
echo "============================================"  
echo "步骤2: 生成design_1 HBM块设计"
echo "============================================"
$VIVADO_DIR/bin/vivado -mode batch -source gen_design_1_simple.tcl -tclargs $board_repo_arg

if [[ $? -eq 0 ]]; then
    echo ""
    echo "============================================"
    echo "HBM仿真环境生成成功！"
    echo "============================================"
    echo "生成的文件:"
    echo "  ✓ 基础IP: ${build_dir}/ip/"
    echo "  ✓ design_1块设计: ${build_dir}/ip/design_1/"
    echo "  ✓ design_1 wrapper: ${build_dir}/ip/design_1/sim/design_1_wrapper.v"
    echo ""
    
    # 验证关键文件
    if [[ -f "${build_dir}/ip/design_1/sim/design_1_wrapper.v" ]]; then
        echo "  ✓ design_1_wrapper.v 验证通过"
    else
        echo "  ❌ design_1_wrapper.v 验证失败"
    fi
    
else
    echo "ERROR: design_1块设计生成失败"
    echo "请检查:"
    echo "  1. design_1.tcl文件是否存在"
    echo "  2. 板级定义是否正确" 
    echo "  3. Vivado版本是否为2021.2"
    exit 1
fi

echo "INFO: HBM仿真环境设置完成"
echo "INFO: 现在可以运行HBM仿真了（仅支持Questasim）"
echo "示例: python ../run_testcase_hbm.py -roce -tc read_2rdma_hbm -gui"