#!/bin/bash
#==============================================================================
# Copyright (C) 2023, Advanced Micro Devices, Inc. All rights reserved.
# SPDX-License-Identifier: MIT
#
# HBM仿真快速测试脚本
#==============================================================================
set -e

echo "========================================="
echo "HBM仿真快速测试"
echo "========================================="

# 检查当前目录
if [[ ! -f "run_testcase_hbm.py" ]]; then
    echo "ERROR: 请在RecoNIC/sim目录下运行此脚本"
    exit 1
fi

echo "步骤1: 检查环境变量..."
if [[ -z "${VIVADO_DIR:-}" ]]; then
    echo "❌ VIVADO_DIR未设置"
    echo "请运行: export VIVADO_DIR=/your/vivado/path/Vivado/2021.2"
    exit 1
else
    echo "✅ VIVADO_DIR: $VIVADO_DIR"
fi

echo ""
echo "步骤2: 测试Python脚本基本功能..."
python test_python_hbm.py

if [[ $? -ne 0 ]]; then
    echo "❌ Python脚本测试失败"
    exit 1
fi

echo ""
echo "步骤3: 检查HBM环境..."
./test_hbm_setup.sh

if [[ $? -ne 0 ]]; then
    echo "❌ HBM环境检查失败，请运行: cd scripts && ./setup_hbm_simulation.sh"
    exit 1
fi

echo ""
echo "步骤4: 测试Python脚本参数解析..."
python run_testcase_hbm.py --help

echo ""
echo "========================================="
echo "🎉 HBM仿真环境测试通过！"
echo "========================================="
echo ""
echo "现在可以运行HBM仿真："
echo ""
echo "# 使用原始测试用例（自动转换为HBM）："
echo "python run_testcase_hbm.py -roce -tc read_2rdma -gui"
echo ""
echo "# 使用专门的HBM测试用例："  
echo "python run_testcase_hbm.py -roce -tc read_2rdma_hbm -gui"
echo ""
echo "# 无GUI模式："
echo "python run_testcase_hbm.py -roce -tc read_2rdma_hbm"
echo ""
echo "========================================="