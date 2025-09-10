#==============================================================================
# Copyright (C) 2023, Advanced Micro Devices, Inc. All rights reserved.
# SPDX-License-Identifier: MIT
#
# HBM仿真所需的IP列表配置文件
#==============================================================================

# HBM仿真所需的IP核列表
set ips {
    axi_mm_bram
    axi_sys_mm
    axi_protocol_checker
}

# 注意：design_1块设计将通过专门的脚本处理
# HBM系统相关的其他IP将在design_1块设计内部生成
