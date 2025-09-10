# RecoNIC HBM仿真快速开始指南

本文档提供RecoNIC HBM系统仿真的快速开始指南。

## 快速开始

### 1. 环境设置（必需）

```bash
# 设置Vivado路径
export VIVADO_DIR=/your/vivado/installation/path/Vivado/2021.2

# 可选：设置板级仓库路径（如果遇到板级定义错误）
export BOARD_REPO=/your/xilinx/board/repository/path

# 可选：设置Questasim编译库路径（仅使用Questasim时需要）
export COMPILED_LIB_DIR=/your/vivado/compiled_lib_dir/for/questasim
```

### 2. 安装Python依赖

```bash
pip install scapy numpy
```

### 3. 设置HBM仿真环境

```bash
cd RecoNIC/sim/scripts
./setup_hbm_simulation.sh
```

### 4. 运行测试

```bash
cd RecoNIC/sim

# 基本RDMA读测试（推荐开始）
python run_testcase_hbm.py -roce -tc read_2rdma_hbm -gui

# RDMA写测试
python run_testcase_hbm.py -roce -tc write_2rdma_hbm -gui

# 运行所有回归测试
python run_testcase_hbm.py regression
```

## 常用命令

```bash
# GUI模式运行HBM仿真（仅支持Questasim）
python run_testcase_hbm.py -roce -tc read_2rdma_hbm -gui

# 无GUI模式（批处理）
python run_testcase_hbm.py -roce -tc read_2rdma_hbm

# 只生成数据包，不运行仿真
python run_testcase_hbm.py -roce -tc read_2rdma_hbm -no_sim

# 只分析之前的仿真结果
python run_testcase_hbm.py -roce -tc read_2rdma_hbm -no_pktgen -no_sim
```

## 支持的测试用例

### HBM专用测试用例
- `read_2rdma_hbm`: RDMA读操作（使用HBM作为设备内存）
- `write_2rdma_hbm`: RDMA写操作（使用HBM作为设备内存）

### 兼容的原测试用例
原有的测试用例也可以运行，但会自动使用HBM testbench：
- `read_2rdma`: 自动转换为 `rn_tb_top_hbm`
- `write_2rdma`: 自动转换为 `rn_tb_top_hbm`
- `send_2rdma`: 自动转换为 `rn_tb_top_hbm`

## 目录结构

```
RecoNIC/sim/
├── scripts/
│   ├── setup_hbm_simulation.sh    # HBM环境设置
│   ├── simulate_hbm.sh           # HBM仿真脚本
│   ├── gen_vivado_ip_hbm.tcl     # HBM IP生成
│   ├── questasim_compile_hbm.do  # Questasim编译
│   └── xsim_compile_hbm.do       # Xsim编译
├── src/
│   ├── hbm_clk_gen.sv            # HBM时钟生成器
│   ├── design_1_sim_wrapper.sv   # HBM仿真包装器
│   └── rn_tb_top_hbm.sv          # HBM testbench
├── testcases/
│   ├── read_2rdma_hbm/           # HBM读测试
│   └── write_2rdma_hbm/          # HBM写测试
├── run_testcase_hbm.py           # HBM测试运行器
├── HBM_Simulation_Guide.md       # 详细指南
└── README_HBM.md                 # 本文档
```

## 故障排除

### 环境问题
1. **VIVADO_DIR未设置**: 设置正确的Vivado路径
2. **板级定义错误**: 设置BOARD_REPO环境变量
3. **编译库缺失**: 预编译Vivado仿真库（Questasim）

### 仿真问题
1. **HBM块设计缺失**: 运行 `setup_hbm_simulation.sh`
2. **编译错误**: 检查所有IP是否正确生成
3. **时钟问题**: 确认HBM时钟生成器工作正常

### 性能问题
1. **仿真慢**: HBM仿真比BRAM模型慢，这是正常的
2. **内存不足**: HBM系统需要更多仿真内存

## 注意事项

1. **向后兼容性**: 新系统保持与原仿真框架的兼容性
2. **测试覆盖**: HBM系统支持所有原有的RDMA功能测试
3. **调试支持**: HBM仿真支持波形查看和调试
4. **自动化**: 支持回归测试和批处理模式

更多详细信息，请参考 `HBM_Simulation_Guide.md`。