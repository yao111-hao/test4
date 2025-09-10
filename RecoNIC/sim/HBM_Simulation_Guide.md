# RecoNIC HBM系统仿真指南

本指南介绍如何为基于HBM内存的RecoNIC网卡项目设置和运行仿真环境。

## 重要说明

**⚠️ HBM仿真仅支持Questasim，不支持Xsim**

HBM IP核的复杂性要求使用Questasim仿真器，且需要60us的复位时间。

## 系统概述

原项目使用DDR4作为设备内存，现在已升级为使用HBM (High Bandwidth Memory)。主要变化包括：

1. **内存系统**: DDR4 → HBM (使用`design_1`块设计)
2. **互连系统**: `axi_3to1_interconnect_to_dev_mem` → `design_1_wrapper`
3. **时钟系统**: 增加了100MHz差分时钟用于HBM  
4. **仿真架构**: 直接使用`design_1`块设计，内部包含smartconnect和时钟转换
5. **复位系统**: HBM需要60us复位时间

## 环境准备

### 1. 环境变量设置

```bash
# 设置Vivado路径（必需）
export VIVADO_DIR=/your/vivado/installation/path/Vivado/2021.2

# 设置Questasim编译库路径（HBM仿真必需）
export COMPILED_LIB_DIR=/your/vivado/compiled_lib_dir/for/questasim

# 如果遇到板级定义错误，设置板级仓库路径（可选）
export BOARD_REPO=/your/xilinx/board/repository/path
```

### 2. Python依赖安装

```bash
pip install scapy
pip install numpy
```

## HBM仿真环境设置

### 1. 生成HBM IP和块设计

```bash
cd RecoNIC/sim/scripts
./setup_hbm_simulation.sh
```

此脚本将：
- 生成HBM系统所需的所有IP核
- 创建design_1块设计及其仿真文件
- 生成HBM时钟生成器IP
- 设置仿真目录结构

### 2. 验证设置

检查以下目录是否已创建：
```bash
RecoNIC/sim/build/ip/design_1/          # HBM块设计
RecoNIC/sim/build/ip/design_1/sim/      # HBM仿真文件
RecoNIC/sim/build/ip/axi_mm_bram/       # BRAM IP
RecoNIC/sim/build/ip/axi_sys_mm/        # 系统内存模型
```

## 运行仿真

### 1. 使用新的HBM测试脚本

```bash
cd RecoNIC/sim

# 使用Questasim运行HBM仿真（仅支持的仿真器）
python run_testcase_hbm.py -roce -tc read_2rdma_hbm -gui

# 无GUI模式
python run_testcase_hbm.py -roce -tc read_2rdma_hbm

# 运行回归测试
python run_testcase_hbm.py regression
```

### 2. 支持的测试用例

当前支持的HBM测试用例：
- `read_2rdma`: RDMA读操作测试
- `write_2rdma`: RDMA写操作测试  
- `send_2rdma`: RDMA发送操作测试

### 3. 手动仿真方式

如果需要手动控制仿真过程：

```bash
cd RecoNIC/sim/scripts

# 1. 设置HBM环境（如果尚未完成）
./setup_hbm_simulation.sh

# 2. 手动运行仿真
./simulate_hbm.sh read_2rdma on rn_tb_top_hbm xsim
```

## 新增的HBM仿真文件

### 1. 构建脚本
- `scripts/gen_vivado_ip_hbm.tcl`: HBM IP和块设计生成脚本
- `scripts/sim_vivado_ip_hbm.tcl`: HBM仿真IP列表配置
- `scripts/setup_hbm_simulation.sh`: HBM环境设置脚本

### 2. 仿真源文件
- `src/hbm_clk_gen.sv`: HBM 100MHz差分时钟生成器
- `src/design_1_sim_wrapper.sv`: HBM系统仿真包装器
- `src/rn_tb_top_hbm.sv`: 支持HBM的主testbench

### 3. 编译脚本
- `scripts/questasim_compile_hbm.do`: Questasim HBM编译脚本
- `scripts/xsim_compile_hbm.do`: Xsim HBM编译脚本
- `scripts/simulate_hbm.sh`: HBM仿真运行脚本

### 4. Python脚本
- `run_testcase_hbm.py`: HBM测试用例运行器

## HBM系统架构

### 时钟域
- **主时钟域**: 250MHz (axis_aclk) - RDMA和网络接口
- **控制时钟域**: 125MHz (axil_aclk) - AXI-Lite控制接口  
- **HBM时钟域**: 450MHz - HBM内部操作
- **参考时钟**: 100MHz - HBM参考时钟

### 内存映射
HBM系统提供统一的内存空间：
- `0x00000000 - 0x0FFFFFFF`: HBM_MEM00 (256MB)
- `0x10000000 - 0x1FFFFFFF`: HBM_MEM01 (256MB)
- `0x20000000 - 0x2FFFFFFF`: HBM_MEM02 (256MB)
- ... (总共16个256MB分区)

### AXI接口
HBM系统通过design_1块设计提供3个AXI slave接口：
1. **s_axi_qdma_mm**: 来自QDMA的内存访问
2. **s_axi_compute_logic**: 来自计算逻辑的内存访问
3. **s_axi_from_sys_crossbar**: 来自系统交叉开关的内存访问

## 故障排除

### 1. 块设计生成失败
如果HBM块设计生成失败，检查：
- Vivado版本是否为2021.2
- 板级文件是否正确
- 是否有足够的磁盘空间

### 2. 仿真编译错误
如果编译失败，检查：
- 所有IP是否正确生成
- 路径是否正确
- 仿真库是否已预编译（Questasim）

### 3. 时钟问题
如果遇到时钟相关问题：
- 确认hbm_clk_gen模块正常工作
- 检查时钟锁定信号
- 验证复位序列

### 4. HBM接口问题
如果HBM接口出现问题：
- 检查AXI接口位宽匹配
- 验证地址映射配置
- 确认时钟域跨越正确处理

## 与原系统的差异

### 接口变化
1. **新增HBM时钟接口**:
   - `hbm_clk_p/hbm_clk_n`: 100MHz差分时钟输入
   - `hbm_clk_locked`: 时钟锁定指示

2. **内存接口更改**:
   - DDR4接口 → HBM块设计接口
   - 时钟: 125MHz → 450MHz（内部）
   - 位宽: 512bit → 256bit（内部转换）

### 仿真差异
1. **内存模型**: 使用BRAM模拟HBM行为
2. **时钟生成**: 软件生成HBM参考时钟
3. **初始化**: HBM需要更复杂的初始化序列

## 性能考虑

1. **仿真速度**: HBM块设计可能比纯BRAM模型慢
2. **内存容量**: HBM提供更大的内存空间
3. **带宽**: HBM提供更高的内存带宽

## 联系和支持

如果在使用过程中遇到问题，请检查：
1. 环境变量是否正确设置
2. Vivado版本是否兼容
3. 相关IP是否正确生成

更多信息请参考主README.md文件。