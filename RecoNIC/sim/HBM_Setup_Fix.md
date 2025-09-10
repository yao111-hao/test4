# HBM设置问题修复

## 问题分析

您遇到的错误是因为`export_simulation`命令中指定的目录不存在：

```
ERROR: [exportsim-Tcl-0] Directory path specified with the '-ip_user_files_dir' does not exist
```

## 已修复的问题

### 1. **目录创建问题**
- ✅ 在调用`export_simulation`前先创建所有必需的目录
- ✅ 修复了`ip_user_files`、`ipstatic`等目录不存在的问题

### 2. **Wrapper文件路径问题** 
- ✅ 正确处理wrapper文件在`.gen`目录而不是`.srcs`目录的情况
- ✅ 添加了多路径查找和验证机制

### 3. **简化的生成流程**
- ✅ 将基础IP生成和design_1生成分离为两个脚本
- ✅ `gen_vivado_ip_hbm.tcl`: 只生成基础IP
- ✅ `gen_design_1_simple.tcl`: 专门生成design_1块设计

## 新的使用方法

### 重新设置HBM环境

```bash
cd RecoNIC/sim/scripts

# 重新运行修复后的设置脚本
./setup_hbm_simulation.sh
```

### 验证设置

```bash
cd RecoNIC/sim

# 运行环境检查脚本
./test_hbm_setup.sh
```

应该看到如下输出：
```
✅ VIVADO_DIR: /your/vivado/path
✅ axi_mm_bram
✅ axi_sys_mm  
✅ axi_protocol_checker
✅ design_1目录存在
✅ design_1_wrapper.v存在
✅ design_1_wrapper.v内容正确
🎉 HBM仿真环境设置成功！
```

### 运行仿真

```bash
cd RecoNIC/sim

# 运行HBM仿真
python run_testcase_hbm.py -roce -tc read_2rdma_hbm -gui
```

## 关键修复点

### 1. gen_vivado_ip_hbm.tcl
- 只负责生成基础仿真IP（axi_mm_bram、axi_sys_mm、axi_protocol_checker）
- 不再处理复杂的design_1块设计

### 2. gen_design_1_simple.tcl
- 专门生成design_1块设计
- 使用简化的方法避免export_simulation问题
- 自动查找wrapper文件的正确路径

### 3. setup_hbm_simulation.sh
- 分步执行：先生成基础IP，再生成design_1
- 更好的错误处理和状态报告

### 4. questasim_compile_hbm.do
- 简化了design_1编译流程
- 只编译必需的wrapper文件
- 更好的错误检测

## 如果仍有问题

如果重新运行后仍有问题，请：

1. **清理旧文件**:
```bash
rm -rf RecoNIC/sim/build
```

2. **重新设置**:
```bash
cd RecoNIC/sim/scripts
./setup_hbm_simulation.sh
```

3. **检查环境**:
```bash
cd RecoNIC/sim
./test_hbm_setup.sh
```

4. **查看详细日志**:
```bash
# 检查Vivado日志文件（在scripts目录中）
cat vivado.log
```

修复后的环境应该能够成功生成design_1块设计并支持Questasim仿真。