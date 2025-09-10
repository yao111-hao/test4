#!/bin/bash
#==============================================================================
# Copyright (C) 2023, Advanced Micro Devices, Inc. All rights reserved.
# SPDX-License-Identifier: MIT
#
# 验证HBM脚本文件是否完整的脚本
#==============================================================================
set -Eeuo pipefail

echo "verify_hbm_scripts.sh - 验证HBM仿真脚本"

cur_dir=$(pwd)
sim_dir=$(dirname $cur_dir)
root_dir=$(dirname $sim_dir)

echo "检查HBM仿真脚本文件..."

# 检查脚本文件
scripts=(
    "gen_vivado_ip_hbm.tcl"
    "gen_design_1_simple.tcl"
    "setup_hbm_simulation.sh"
    "questasim_compile_hbm.do"
    "simulate_hbm.sh"
)

echo ""
echo "脚本文件检查:"
for script in "${scripts[@]}"; do
    if [[ -f "/workspace/RecoNIC/sim/scripts/$script" ]]; then
        echo "  ✓ $script"
        # 检查文件大小
        size=$(stat -c%s "/workspace/RecoNIC/sim/scripts/$script")
        echo "    大小: ${size} bytes"
    else
        echo "  ❌ $script (缺失)"
    fi
done

# 检查必需的源目录
echo ""
echo "源目录检查:"
dirs=(
    "${root_dir}/base_nics/open-nic-shell/src/hbm_subsystem"
    "${root_dir}/shell/plugs/rdma_onic_plugin/vivado_ip"
    "${sim_dir}/src"
)

for dir in "${dirs[@]}"; do
    if [[ -d "$dir" ]]; then
        echo "  ✓ $dir"
    else
        echo "  ❌ $dir (缺失)"
    fi
done

# 检查关键文件
echo ""
echo "关键文件检查:"
files=(
    "${root_dir}/base_nics/open-nic-shell/src/hbm_subsystem/design_1.tcl"
    "${root_dir}/shell/plugs/rdma_onic_plugin/vivado_ip/sim_vivado_ip_hbm.tcl"
    "${root_dir}/shell/plugs/rdma_onic_plugin/vivado_ip/axi_mm_bram.tcl"
    "${root_dir}/shell/plugs/rdma_onic_plugin/vivado_ip/axi_sys_mm.tcl"
    "${root_dir}/shell/plugs/rdma_onic_plugin/vivado_ip/axi_protocol_checker.tcl"
    "${sim_dir}/src/hbm_clk_gen.sv"
    "${sim_dir}/src/rn_tb_top_hbm.sv"
)

for file in "${files[@]}"; do
    if [[ -f "$file" ]]; then
        echo "  ✓ $(basename $file)"
    else
        echo "  ❌ $(basename $file) (缺失)"
        echo "    路径: $file"
    fi
done

# 检查环境变量
echo ""
echo "环境变量检查:"
if [[ -n "${VIVADO_DIR:-}" ]]; then
    echo "  ✓ VIVADO_DIR: $VIVADO_DIR"
    if [[ -f "$VIVADO_DIR/bin/vivado" ]]; then
        echo "    ✓ vivado可执行文件存在"
    else
        echo "    ❌ vivado可执行文件不存在"
    fi
else
    echo "  ❌ VIVADO_DIR 未设置"
fi

if [[ -n "${COMPILED_LIB_DIR:-}" ]]; then
    echo "  ✓ COMPILED_LIB_DIR: $COMPILED_LIB_DIR"
else
    echo "  ⚠️  COMPILED_LIB_DIR 未设置（运行仿真时需要）"
fi

echo ""
echo "验证完成。如果所有文件都存在，可以运行:"
echo "  ./setup_hbm_simulation.sh"