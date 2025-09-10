#!/bin/bash
#==============================================================================
# Copyright (C) 2023, Advanced Micro Devices, Inc. All rights reserved.
# SPDX-License-Identifier: MIT
#
# RecoNIC HBM仿真演示脚本
#==============================================================================

set -e

echo "========================================"
echo "RecoNIC HBM仿真系统演示"
echo "========================================"

# 检查当前目录
if [[ ! -f "run_testcase_hbm.py" ]]; then
    echo "ERROR: 请在RecoNIC/sim目录下运行此脚本"
    exit 1
fi

# 检查环境变量
if [[ -z "${VIVADO_DIR:-}" ]]; then
    echo "ERROR: 请设置VIVADO_DIR环境变量"
    echo "示例: export VIVADO_DIR=/opt/Xilinx/Vivado/2021.2"
    exit 1
fi

echo "步骤1: 检查Python依赖..."
python3 -c "import scapy, numpy" 2>/dev/null || {
    echo "安装Python依赖..."
    pip install scapy numpy
}

echo "步骤2: 设置HBM仿真环境..."
cd scripts
if [[ ! -d "../build/ip/design_1" ]]; then
    echo "生成HBM IP和块设计..."
    ./setup_hbm_simulation.sh
else
    echo "HBM环境已设置"
fi

echo "步骤3: 运行HBM仿真演示..."
cd ..

echo "========================================"
echo "演示1: HBM RDMA读测试（无GUI）"
echo "========================================"
python3 run_testcase_hbm.py -roce -tc read_2rdma_hbm

echo ""
echo "========================================"
echo "演示2: HBM RDMA写测试（无GUI）"  
echo "========================================"
python3 run_testcase_hbm.py -roce -tc write_2rdma_hbm

echo ""
echo "========================================"
echo "演示3: 如需运行GUI模式，请执行："
echo "python3 run_testcase_hbm.py -roce -tc read_2rdma_hbm -gui"
echo "========================================"

echo ""
echo "演示完成！"
echo ""
echo "更多使用方法："
echo "1. 查看快速指南: cat README_HBM.md"
echo "2. 查看详细指南: cat HBM_Simulation_Guide.md"  
echo "3. 查看迁移总结: cat HBM_Migration_Summary.md"
echo ""
echo "常用命令："
echo "- HBM RDMA读测试: python3 run_testcase_hbm.py -roce -tc read_2rdma_hbm -gui"
echo "- HBM RDMA写测试: python3 run_testcase_hbm.py -roce -tc write_2rdma_hbm -gui"
echo "- 回归测试: python3 run_testcase_hbm.py regression"