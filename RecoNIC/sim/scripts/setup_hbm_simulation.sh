#!/bin/bash
#==============================================================================
# Copyright (C) 2023, Advanced Micro Devices, Inc. All rights reserved.
# SPDX-License-Identifier: MIT
#
# 设置HBM仿真环境的脚本
#==============================================================================
set -Eeuo pipefail

echo "setup_hbm_simulation.sh - 设置RecoNIC HBM仿真环境"

VIVADO_VERSION=2021.2

# 检查环境变量
if [[ -z "${VIVADO_DIR:-}" ]]; then
    echo "ERROR: Please set VIVADO_DIR environment variable"
    echo "Example: export VIVADO_DIR=/your/vivado/installation/path/Vivado/2021.2"
    exit 1
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

echo "INFO: 正在生成HBM系统和相关IP..."

# 生成HBM相关的IP和块设计
cd $sim_script_dir
$VIVADO_DIR/bin/vivado -mode batch -source gen_vivado_ip_hbm.tcl -tclargs $board_repo_arg

if [[ $? -eq 0 ]]; then
    echo "INFO: HBM IP和块设计生成成功"
    echo "INFO: 生成的文件位置:"
    echo "  - IP文件: ${build_dir}/ip/"
    echo "  - 块设计: ${build_dir}/ip/design_1/"
    echo "  - 仿真文件: ${build_dir}/ip/design_1/sim/"
else
    echo "ERROR: HBM IP和块设计生成失败"
    exit 1
fi

echo "INFO: HBM仿真环境设置完成"
echo "INFO: 现在可以运行仿真了"
echo "示例: python ../run_testcase.py -roce -tc read_2rdma -gui"