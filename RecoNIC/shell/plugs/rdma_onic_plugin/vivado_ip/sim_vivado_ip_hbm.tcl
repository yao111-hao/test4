#==============================================================================
# Copyright (C) 2023, Advanced Micro Devices, Inc. All rights reserved.
# SPDX-License-Identifier: MIT
#
# HBM仿真所需的IP核列表
#==============================================================================

# HBM仿真环境所需的IP核
set ips {
    axi_mm_bram
    axi_sys_mm  
    axi_protocol_checker
}

# 注意事项:
# 1. design_1 (HBM块设计) 将通过专门的脚本单独处理
# 2. HBM相关的其他IP（clk_wiz、smartconnect等）包含在design_1内部
# 3. 这个列表只包含仿真testbench直接使用的IP核