#!/usr/bin/env python3
#==============================================================================
# Copyright (C) 2023, Advanced Micro Devices, Inc. All rights reserved.
# SPDX-License-Identifier: MIT
#
# HBM系统测试用例运行脚本
#==============================================================================

import os
import sys
import json
import argparse
import subprocess
import logging
from pathlib import Path

# 添加sim目录到Python路径
sim_dir = Path(__file__).parent
sys.path.append(str(sim_dir))

# 导入原始的packet_gen模块
import packet_gen
import config_logger

def setup_logging():
    """设置日志配置"""
    config_logger.setup_logger()

def parse_arguments():
    """解析命令行参数"""
    parser = argparse.ArgumentParser(
        description='RecoNIC HBM系统测试用例运行器',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
示例:
  # 使用xsim运行read_2rdma测试
  python run_testcase_hbm.py -roce -tc read_2rdma -gui
  
  # 使用questasim运行write_2rdma测试
  python run_testcase_hbm.py -roce -tc write_2rdma -questasim -gui
  
  # 运行回归测试
  python run_testcase_hbm.py regression
        """
    )
    
    parser.add_argument('-debug', action='store_true', help='Debug模式')
    parser.add_argument('-questasim', action='store_true', help='使用Questa Sim作为仿真器，默认是Vivado XSIM')
    parser.add_argument('-roce', action='store_true', help='生成RDMA仿真的配置文件')
    parser.add_argument('-no_pktgen', action='store_true', help='运行测试用例而不重新生成数据包')
    parser.add_argument('-no_sim', action='store_true', help='只对之前的仿真结果进行分析')
    parser.add_argument('-gui', action='store_true', help='使用仿真器的GUI模式')
    parser.add_argument('-tc', type=str, help='指定要运行的测试用例')
    parser.add_argument('mode', nargs='?', default='', help='运行模式：regression或空')
    
    return parser.parse_args()

def check_environment():
    """检查必要的环境变量"""
    vivado_dir = os.environ.get('VIVADO_DIR')
    if not vivado_dir:
        logging.error("VIVADO_DIR环境变量未设置")
        logging.error("示例: export VIVADO_DIR=/your/vivado/installation/path/Vivado/2021.2")
        sys.exit(1)
    
    if not os.path.exists(vivado_dir):
        logging.error(f"VIVADO_DIR路径不存在: {vivado_dir}")
        sys.exit(1)
    
    return vivado_dir

def check_hbm_setup():
    """检查HBM环境是否已设置"""
    build_dir = sim_dir / "build"
    hbm_bd_dir = build_dir / "ip" / "design_1"
    
    if not hbm_bd_dir.exists():
        logging.error("HBM块设计未生成，请先运行:")
        logging.error("  cd scripts && ./setup_hbm_simulation.sh")
        sys.exit(1)
    
    logging.info(f"HBM块设计已准备: {hbm_bd_dir}")

def generate_packets(testcase, roce_mode):
    """生成测试数据包"""
    testcase_dir = sim_dir / "testcases" / testcase
    if not testcase_dir.exists():
        logging.error(f"测试用例目录不存在: {testcase_dir}")
        sys.exit(1)
    
    config_file = testcase_dir / f"{testcase}.json"
    if not config_file.exists():
        logging.error(f"测试用例配置文件不存在: {config_file}")
        sys.exit(1)
    
    # 读取配置
    with open(config_file, 'r') as f:
        config = json.load(f)
    
    # 为HBM系统修改配置
    if "top_module" in config:
        # 将top_module更改为HBM版本
        if config["top_module"] == "rn_tb_top":
            config["top_module"] = "rn_tb_top_hbm"
        elif config["top_module"] == "rn_tb_2rdma_top":
            config["top_module"] = "rn_tb_2rdma_top_hbm"  # 如果需要的话
    
    logging.info(f"生成测试用例数据包: {testcase}")
    logging.info(f"使用配置: {config}")
    
    # 切换到构建目录
    build_dir = sim_dir / "build"
    build_dir.mkdir(exist_ok=True)
    os.chdir(build_dir)
    
    # 使用packet_gen生成数据包
    try:
        packet_gen.generate_test_data(config, roce_mode)
        logging.info("数据包生成成功")
    except Exception as e:
        logging.error(f"数据包生成失败: {e}")
        sys.exit(1)

def run_simulation(testcase, gui_mode, top_module):
    """运行Questasim仿真"""
    scripts_dir = sim_dir / "scripts"
    os.chdir(scripts_dir)
    
    gui_arg = "on" if gui_mode else "off"
    
    cmd = ["./simulate_hbm.sh", testcase, gui_arg, top_module]
    
    logging.info(f"运行HBM Questasim仿真命令: {' '.join(cmd)}")
    
    try:
        result = subprocess.run(cmd, check=True, capture_output=True, text=True)
        logging.info("HBM仿真完成")
        print(result.stdout)
    except subprocess.CalledProcessError as e:
        logging.error(f"HBM仿真失败: {e}")
        print(e.stderr)
        sys.exit(1)

def run_regression():
    """运行HBM回归测试"""
    testcases = ["read_2rdma_hbm", "write_2rdma_hbm"]
    
    logging.info("开始运行HBM回归测试（仅Questasim）")
    
    for tc in testcases:
        logging.info(f"运行测试用例: {tc}")
        try:
            # 生成数据包
            generate_packets(tc, True)
            
            # 运行仿真
            run_simulation(tc, False, "rn_tb_top_hbm")
            
            logging.info(f"测试用例 {tc} 完成")
        except Exception as e:
            logging.error(f"测试用例 {tc} 失败: {e}")
    
    logging.info("HBM回归测试完成")

def main():
    """主函数"""
    setup_logging()
    args = parse_arguments()
    
    # 检查环境
    vivado_dir = check_environment()
    check_hbm_setup()
    
    if args.mode == "regression":
        run_regression()
        return
    
    if not args.tc:
        logging.error("请指定测试用例名称 (-tc)")
        sys.exit(1)
    
    testcase = args.tc
    
    # HBM仅支持Questasim
    if args.questasim:
        logging.info("HBM仿真强制使用Questasim")
    else:
        logging.warning("注意：HBM仅支持Questasim仿真器")
    
    # 确定顶层模块
    testcase_config_file = sim_dir / "testcases" / testcase / f"{testcase}.json"
    if testcase_config_file.exists():
        with open(testcase_config_file, 'r') as f:
            config = json.load(f)
        top_module = config.get("top_module", "rn_tb_top_hbm")
        # 强制转换为HBM版本
        if top_module != "rn_tb_top_hbm":
            logging.info(f"将顶层模块从 {top_module} 转换为 rn_tb_top_hbm")
            top_module = "rn_tb_top_hbm"
    else:
        top_module = "rn_tb_top_hbm"
    
    logging.info(f"使用顶层模块: {top_module}")
    
    # 生成数据包（除非禁用）
    if not args.no_pktgen:
        generate_packets(testcase, args.roce)
    
    # 运行仿真（除非禁用）
    if not args.no_sim:
        run_simulation(testcase, args.gui, top_module)

if __name__ == "__main__":
    main()