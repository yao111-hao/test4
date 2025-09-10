#!/bin/bash
#==============================================================================
# Copyright (C) 2023, Advanced Micro Devices, Inc. All rights reserved.
# SPDX-License-Identifier: MIT
#
# 测试HBM设置是否成功的脚本
#==============================================================================
set -Eeuo pipefail

echo "test_hbm_setup.sh - 测试HBM仿真环境设置"

cur_dir=$(pwd)
sim_dir=$(dirname $cur_dir)
build_dir=${sim_dir}/build

echo "检查HBM仿真环境..."

# 检查环境变量
if [[ -z "${VIVADO_DIR:-}" ]]; then
    echo "❌ VIVADO_DIR未设置"
    exit 1
else
    echo "✅ VIVADO_DIR: $VIVADO_DIR"
fi

if [[ -z "${COMPILED_LIB_DIR:-}" ]]; then
    echo "⚠️  COMPILED_LIB_DIR未设置（运行仿真时需要）"
else
    echo "✅ COMPILED_LIB_DIR: $COMPILED_LIB_DIR"
fi

# 检查基础IP是否生成
echo ""
echo "检查基础IP..."
required_ips=("axi_mm_bram" "axi_sys_mm" "axi_protocol_checker")
for ip in "${required_ips[@]}"; do
    if [[ -d "${build_dir}/ip/${ip}" ]]; then
        echo "✅ $ip"
    else
        echo "❌ $ip (缺失)"
    fi
done

# 检查design_1是否生成
echo ""
echo "检查design_1块设计..."
if [[ -d "${build_dir}/ip/design_1" ]]; then
    echo "✅ design_1目录存在"
    
    if [[ -f "${build_dir}/ip/design_1/sim/design_1_wrapper.v" ]]; then
        echo "✅ design_1_wrapper.v存在"
    else
        echo "❌ design_1_wrapper.v缺失"
    fi
    
    # 检查wrapper文件内容
    wrapper_file="${build_dir}/ip/design_1/sim/design_1_wrapper.v"
    if [[ -f "$wrapper_file" ]]; then
        if grep -q "design_1" "$wrapper_file"; then
            echo "✅ design_1_wrapper.v内容正确"
        else
            echo "⚠️  design_1_wrapper.v内容异常"
        fi
    fi
else
    echo "❌ design_1目录不存在"
fi

# 检查仿真源文件
echo ""
echo "检查仿真源文件..."
sim_files=("hbm_clk_gen.sv" "rn_tb_top_hbm.sv")
for file in "${sim_files[@]}"; do
    if [[ -f "${sim_dir}/src/${file}" ]]; then
        echo "✅ $file"
    else
        echo "❌ $file (缺失)"
    fi
done

# 检查测试用例
echo ""
echo "检查HBM测试用例..."
hbm_testcases=("read_2rdma_hbm" "write_2rdma_hbm")
for tc in "${hbm_testcases[@]}"; do
    if [[ -d "${sim_dir}/testcases/${tc}" ]]; then
        echo "✅ $tc"
    else
        echo "❌ $tc (缺失)"
    fi
done

echo ""
echo "环境检查完成。"
echo ""

# 生成使用建议
all_ok=true
if [[ ! -d "${build_dir}/ip/design_1" ]] || [[ ! -f "${build_dir}/ip/design_1/sim/design_1_wrapper.v" ]]; then
    all_ok=false
fi

if $all_ok; then
    echo "🎉 HBM仿真环境设置成功！"
    echo ""
    echo "可以运行以下命令开始仿真："
    echo "  cd RecoNIC/sim"  
    echo "  python run_testcase_hbm.py -roce -tc read_2rdma_hbm -gui"
else
    echo "❌ HBM仿真环境设置不完整"
    echo ""
    echo "建议运行以下命令重新设置："
    echo "  cd RecoNIC/sim/scripts"
    echo "  ./setup_hbm_simulation.sh"
fi
