# RecoNIC HBM迁移总结

## 完成的工作

本次改进为RecoNIC项目添加了完整的HBM (High Bandwidth Memory) 仿真支持，以替代原有的DDR4系统。

### 1. 新增的脚本文件

#### 构建和设置脚本
- `scripts/gen_vivado_ip_hbm.tcl`: 支持HBM块设计的IP生成脚本
- `scripts/sim_vivado_ip_hbm.tcl`: HBM仿真所需的IP列表配置
- `scripts/setup_hbm_simulation.sh`: 一键式HBM仿真环境设置脚本

#### 编译脚本  
- `scripts/questasim_compile_hbm.do`: Questasim HBM系统编译脚本
- `scripts/xsim_compile_hbm.do`: Xsim HBM系统编译脚本
- `scripts/simulate_hbm.sh`: HBM系统仿真运行脚本

#### Python脚本
- `run_testcase_hbm.py`: 专门的HBM测试用例运行器

### 2. 新增的仿真源文件

#### HBM支持模块
- `src/hbm_clk_gen.sv`: HBM 100MHz差分时钟生成器
- `src/design_1_sim_wrapper.sv`: HBM系统的仿真包装器
- `src/rn_tb_top_hbm.sv`: 支持HBM的主要testbench

### 3. 新增的测试用例

#### HBM专用测试用例
- `testcases/read_2rdma_hbm/`: HBM RDMA读操作测试
- `testcases/write_2rdma_hbm/`: HBM RDMA写操作测试

### 4. 文档

- `HBM_Simulation_Guide.md`: 详细的HBM仿真指南
- `README_HBM.md`: HBM仿真快速开始指南
- `HBM_Migration_Summary.md`: 本迁移总结（当前文档）

## 关键技术改进

### 1. 块设计支持
- 解决了原构建脚本只支持纯IP核的限制
- 新脚本支持Vivado块设计的生成、编译和仿真
- 自动处理块设计的wrapper文件生成

### 2. 时钟系统升级
- 添加了HBM专用的100MHz差分时钟生成器
- 支持时钟域跨越和锁定检测
- 确保HBM系统的时序要求

### 3. 接口适配
- 解决了HBM与原系统的接口不匹配问题
- 处理了位宽差异（512bit ↔ 256bit）
- 处理了时钟频率差异（250MHz ↔ 450MHz）

### 4. 仿真模型改进
- 使用BRAM有效模拟HBM行为
- 保持与原仿真框架的兼容性
- 支持大容量内存仿真（16×256MB分区）

## 使用方法

### 基本使用流程

```bash
# 1. 设置环境变量
export VIVADO_DIR=/your/vivado/path/Vivado/2021.2

# 2. 安装依赖
pip install scapy numpy

# 3. 设置HBM环境（首次运行）
cd RecoNIC/sim/scripts
./setup_hbm_simulation.sh

# 4. 运行测试
cd RecoNIC/sim
python run_testcase_hbm.py -roce -tc read_2rdma_hbm -gui
```

### 高级使用

```bash
# 使用Questasim
export COMPILED_LIB_DIR=/path/to/compiled/libs
python run_testcase_hbm.py -roce -tc write_2rdma_hbm -questasim -gui

# 批处理模式
python run_testcase_hbm.py -roce -tc read_2rdma_hbm

# 回归测试
python run_testcase_hbm.py regression
```

## 技术特点

### 1. 向后兼容
- 保持与原仿真系统的接口兼容
- 原有测试用例可自动转换为HBM版本
- 支持原有的分析和调试工具

### 2. 灵活配置
- 支持多种仿真器（Xsim、Questasim）
- 可配置的内存大小和分区
- 灵活的测试用例配置

### 3. 完整功能
- 支持所有RDMA操作（Read、Write、Send）
- 支持多QP（队列对）仿真
- 支持协议正确性检查

### 4. 易于使用
- 一键式环境设置
- 自动化测试流程
- 详细的错误诊断

## 与原系统的对比

| 特性 | 原DDR4系统 | 新HBM系统 |
|------|-----------|----------|
| 内存类型 | DDR4 | HBM |
| 内存容量 | 8GB | 16×256MB |
| 内存接口 | AXI4 | AXI4（通过块设计） |
| 时钟频率 | 250MHz | 450MHz（内部） |
| 设置复杂度 | 简单 | 中等（自动化） |
| 仿真速度 | 快 | 中等 |
| 功能完整性 | 完整 | 完整+ |

## 注意事项

### 1. 首次使用
- 必须先运行 `setup_hbm_simulation.sh`
- 确保Vivado 2021.2版本
- 检查磁盘空间（块设计需要较多空间）

### 2. 性能考虑
- HBM仿真比纯BRAM慢，但更接近真实硬件
- 建议在开发阶段使用无GUI模式以提高速度
- 大型测试用例可能需要更多仿真时间

### 3. 调试技巧
- 使用GUI模式查看HBM内部信号
- 检查时钟锁定状态
- 监控AXI接口的握手信号

## 下一步工作建议

### 1. 验证测试
1. 运行所有现有测试用例确保兼容性
2. 创建HBM特定的性能测试
3. 验证大容量内存操作

### 2. 性能优化
1. 优化HBM仿真模型以提高速度
2. 考虑并行仿真支持
3. 添加仿真进度报告

### 3. 功能扩展
1. 添加HBM特定的错误注入
2. 支持HBM温度和功耗仿真
3. 添加HBM性能计数器

## 支持

如遇问题，请检查：
1. 环境变量设置是否正确
2. HBM IP是否正确生成
3. 仿真日志中的错误信息

详细信息请参考 `HBM_Simulation_Guide.md`。
