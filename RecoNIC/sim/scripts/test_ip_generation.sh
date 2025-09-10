#!/bin/bash
#==============================================================================
# Copyright (C) 2023, Advanced Micro Devices, Inc. All rights reserved.
# SPDX-License-Identifier: MIT
#
# 测试IP生成是否成功的脚本
#==============================================================================
set -Eeuo pipefail

echo "test_ip_generation.sh - 测试基础IP生成"

cur_dir=$(pwd)
sim_dir=$(dirname $cur_dir)
build_dir=${sim_dir}/build

echo "检查基础IP生成结果..."

# 检查IP目录
ip_build_dir="${build_dir}/ip"
if [[ ! -d "$ip_build_dir" ]]; then
    echo "❌ IP构建目录不存在: $ip_build_dir"
    echo "请先运行: ./setup_hbm_simulation.sh"
    exit 1
fi

echo "✅ IP构建目录存在: $ip_build_dir"

# 检查每个IP
required_ips=("axi_mm_bram" "axi_sys_mm" "axi_protocol_checker")
all_ok=true

echo ""
echo "检查基础IP:"
for ip in "${required_ips[@]}"; do
    ip_dir="${ip_build_dir}/${ip}"
    xci_file="${ip_dir}/${ip}.xci"
    
    if [[ -d "$ip_dir" ]]; then
        if [[ -f "$xci_file" ]]; then
            size=$(stat -c%s "$xci_file")
            echo "  ✅ $ip: $size bytes"
        else
            echo "  ❌ $ip: XCI文件不存在"
            echo "      路径: $xci_file"
            all_ok=false
        fi
    else
        echo "  ❌ $ip: 目录不存在"
        echo "      路径: $ip_dir"
        all_ok=false
    fi
done

echo ""
if $all_ok; then
    echo "🎉 所有基础IP生成成功！"
    echo ""
    echo "下一步可以运行:"
    echo "  cd scripts && vivado -mode batch -source gen_design_1_simple.tcl"
    echo "  或者直接运行: ./setup_hbm_simulation.sh"
else
    echo "❌ 部分IP生成失败"
    echo ""
    echo "建议:"
    echo "  1. 检查Vivado版本是否为2021.2"
    echo "  2. 检查VIVADO_DIR环境变量"
    echo "  3. 重新运行: ./setup_hbm_simulation.sh"
fi

# 检查design_1是否存在
echo ""
echo "检查design_1块设计:"
design_1_dir="${build_dir}/ip/design_1"
if [[ -d "$design_1_dir" ]]; then
    echo "  ✅ design_1目录存在"
    if [[ -f "${design_1_dir}/sim/design_1_wrapper.v" ]]; then
        echo "  ✅ design_1_wrapper.v存在"
        echo ""
        echo "🎉 完整的HBM仿真环境已准备就绪！"
        echo "可以运行HBM仿真了"
    else
        echo "  ❌ design_1_wrapper.v不存在"
        echo "  需要运行: vivado -mode batch -source gen_design_1_simple.tcl"
    fi
else
    echo "  ❌ design_1目录不存在"
    echo "  需要运行: vivado -mode batch -source gen_design_1_simple.tcl"
fi