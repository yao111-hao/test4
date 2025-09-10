#!/usr/bin/env python3
#==============================================================================
# Copyright (C) 2023, Advanced Micro Devices, Inc. All rights reserved.
# SPDX-License-Identifier: MIT
#
# 测试HBM Python脚本的基本功能
#==============================================================================

import os
import sys
import logging
from pathlib import Path

# 添加sim目录到Python路径
sim_dir = Path(__file__).parent
sys.path.append(str(sim_dir))

print("测试HBM Python脚本...")

# 测试日志设置
try:
    logging.basicConfig(
        level=logging.INFO,
        format='%(levelname)s:%(name)s:%(message)s'
    )
    print("✅ 日志设置成功")
except Exception as e:
    print(f"❌ 日志设置失败: {e}")
    sys.exit(1)

# 测试packet_gen模块导入
try:
    import packet_gen
    print("✅ packet_gen模块导入成功")
except Exception as e:
    print(f"❌ packet_gen模块导入失败: {e}")
    sys.exit(1)

# 测试pktGenClass
try:
    # 使用现有的测试用例配置
    test_config = sim_dir / "testcases" / "read_2rdma" / "read_2rdma.json"
    if test_config.exists():
        pkt_gen = packet_gen.pktGenClass(str(test_config))
        print("✅ pktGenClass创建成功")
    else:
        print(f"⚠️  测试配置文件不存在: {test_config}")
        print("使用默认配置测试...")
        # 创建临时配置文件
        temp_config = {
            "top_module": "rn_tb_top_hbm",
            "pkt_type": "rocev2",
            "pkt_op": "read"
        }
        temp_file = sim_dir / "temp_config.json"
        import json
        with open(temp_file, 'w') as f:
            json.dump(temp_config, f)
        
        pkt_gen = packet_gen.pktGenClass(str(temp_file))
        print("✅ pktGenClass创建成功（使用临时配置）")
        
        # 清理临时文件
        temp_file.unlink()
        
except Exception as e:
    print(f"❌ pktGenClass创建失败: {e}")
    import traceback
    print(f"详细错误: {traceback.format_exc()}")
    sys.exit(1)

# 检查环境变量
print("\n检查环境变量:")
vivado_dir = os.environ.get('VIVADO_DIR')
if vivado_dir:
    print(f"✅ VIVADO_DIR: {vivado_dir}")
else:
    print("❌ VIVADO_DIR未设置")

compiled_lib_dir = os.environ.get('COMPILED_LIB_DIR')  
if compiled_lib_dir:
    print(f"✅ COMPILED_LIB_DIR: {compiled_lib_dir}")
else:
    print("⚠️  COMPILED_LIB_DIR未设置")

# 检查HBM测试用例
print("\n检查HBM测试用例:")
hbm_testcases = ["read_2rdma_hbm", "write_2rdma_hbm"]
for tc in hbm_testcases:
    tc_dir = sim_dir / "testcases" / tc
    if tc_dir.exists():
        print(f"✅ {tc}")
    else:
        print(f"❌ {tc} (目录不存在)")

# 检查HBM环境设置
print("\n检查HBM环境:")
build_dir = sim_dir / "build"
if build_dir.exists():
    print("✅ build目录存在")
    
    # 检查基础IP
    ip_dir = build_dir / "ip"
    if ip_dir.exists():
        print("✅ IP目录存在")
        required_ips = ["axi_mm_bram", "axi_sys_mm", "axi_protocol_checker"]
        for ip in required_ips:
            xci_file = ip_dir / ip / f"{ip}.xci"
            if xci_file.exists():
                print(f"  ✅ {ip}")
            else:
                print(f"  ❌ {ip}")
    else:
        print("❌ IP目录不存在")
    
    # 检查design_1
    design_1_dir = build_dir / "ip" / "design_1"
    if design_1_dir.exists():
        print("✅ design_1目录存在")
        wrapper_file = design_1_dir / "sim" / "design_1_wrapper.v"
        if wrapper_file.exists():
            print("✅ design_1_wrapper.v存在")
        else:
            print("❌ design_1_wrapper.v不存在")
    else:
        print("❌ design_1目录不存在")
else:
    print("❌ build目录不存在，请先运行 setup_hbm_simulation.sh")

print("\n🎉 Python脚本基本功能测试完成")
print("如果所有项目都显示✅，说明Python脚本功能正常")
print("可以尝试运行: python run_testcase_hbm.py -roce -tc read_2rdma_hbm")