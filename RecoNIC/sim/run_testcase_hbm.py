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

# 全局logger对象
logger = None

def setup_logging():
    """设置日志配置"""
    logging.basicConfig(
        level=logging.INFO,
        format='%(levelname)s:%(name)s:%(message)s'
    )
    # 创建与原始脚本兼容的logger对象
    global logger
    logger = logging.getLogger('run_testcase_hbm')

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
    """生成测试数据包（使用原始的packet_gen模式）"""
    testcase_dir = sim_dir / "testcases" / testcase
    if not testcase_dir.exists():
        logging.error(f"测试用例目录不存在: {testcase_dir}")
        sys.exit(1)
    
    config_files = list(testcase_dir.glob("*.json"))
    if len(config_files) == 0:
        logging.error(f"测试用例配置文件不存在: {testcase_dir}")
        sys.exit(1)
    elif len(config_files) > 1:
        logging.error(f"测试用例目录包含多个配置文件: {config_files}")
        sys.exit(1)
    
    config_file = str(config_files[0])
    logging.info(f"使用配置文件: {config_file}")
    
    # 读取配置
    with open(config_file, 'r') as f:
        config = json.load(f)
    
    # 为HBM系统修改配置
    if "top_module" in config:
        original_top = config["top_module"]
        # 强制使用HBM testbench
        config["top_module"] = "rn_tb_top_hbm"
        logging.info(f"顶层模块: {original_top} -> {config['top_module']}")
    
    logging.info(f"生成测试用例数据包: {testcase}")
    
    # 切换到构建目录
    build_dir = sim_dir / "build"
    build_dir.mkdir(exist_ok=True)
    os.chdir(build_dir)
    
    # 使用原始的packet_gen.pktGenClass生成数据包
    try:
        logging.info("创建数据包生成器...")
        pkt_gen = packet_gen.pktGenClass(config_file)
        
        # 根据配置文件中的top_module决定生成类型
        top_module = config.get("top_module", "rn_tb_top_hbm")
        
        if top_module == "cl_tb_top":
            # Compute Logic仿真
            logging.info("生成Compute Logic仿真文件...")
            pkt_gen.gen_cl_stimulus()
            
            # 写入CL相关文件
            cl_init_mem_file = "cl_init_mem.txt"
            cl_ctl_cmd_file = "cl_ctl_cmd.txt" 
            cl_golden_data_file = "cl_golden_data.txt"
            
            pkt_gen.write2file(cl_init_mem_file, '', pkt_gen.cl_init_mem)
            pkt_gen.write2file(cl_ctl_cmd_file, '', pkt_gen.ctl_cmd_lst)
            pkt_gen.write2file(cl_golden_data_file, '', pkt_gen.cl_golden_mem)
            
        else:
            # 网络/RDMA仿真
            if roce_mode:
                logging.info("生成RDMA配置和数据包文件...")
                # 生成RDMA相关文件
                pkt_gen.gen_rdma_stimulus()
                # 生成数据包文件
                pkt_gen.gen_pkt()
            else:
                logging.info("生成网络数据包文件...")
                # 仅生成数据包
                pkt_gen.gen_pkt()
        
        logging.info("数据包生成成功")
    except Exception as e:
        logging.error(f"数据包生成失败: {e}")
        import traceback
        logging.error(f"详细错误: {traceback.format_exc()}")
        sys.exit(1)

def run_simulation(testcase, gui_mode, top_module):
    """运行Questasim仿真（使用原始的simulate.sh命令格式）"""
    scripts_dir = sim_dir / "scripts"
    orig_dir = os.getcwd()
    
    try:
        os.chdir(scripts_dir)
        
        gui_flag = "on" if gui_mode else "off"
        sim_tool = "questasim"  # HBM仅支持questasim
        
        # 使用原始simulate.sh的标准命令行参数格式
        sim_cmd = f"./simulate.sh -top {top_module} -g {gui_flag} -t {testcase} -s {sim_tool}"
        
        logging.info(f"运行HBM仿真命令: {sim_cmd}")
        logging.info("注意: 使用原始的simulate.sh，它应该能处理HBM testbench")
        
        # 使用os.system与原始脚本保持一致
        result = os.system(sim_cmd)
        
        if result == 0:
            logging.info(f"HBM仿真完成: {testcase}")
        else:
            logging.error(f"HBM仿真失败，退出码: {result}")
            sys.exit(1)
            
    finally:
        os.chdir(orig_dir)

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