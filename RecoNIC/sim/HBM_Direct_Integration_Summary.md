# RecoNIC HBM直接集成仿真方案总结

根据您的要求，我已经修改了仿真环境，直接使用您的`design_1.tcl`生成的HBM块设计进行Questasim仿真。

## ✅ 按您要求完成的修改

### 1. **直接使用design_1块设计**
- ✅ 修改了`rn_tb_top_hbm.sv`，直接例化`design_1_wrapper`替换原来的`axi_3to1_interconnect_to_dev_mem`
- ✅ 您的`design_1`块设计内部已包含smartconnect和clock converter，无需额外转换
- ✅ 直接使用HBM IP的内存资源，不使用BRAM模拟

### 2. **仅支持Questasim仿真**
- ✅ 删除了所有Xsim相关的支持
- ✅ 专门优化为Questasim仿真流程
- ✅ 更新了所有脚本和文档说明

### 3. **处理60us HBM复位时间**
- ✅ 在testbench中添加了60us复位计数器（15,000 cycles @ 250MHz）
- ✅ 确保HBM系统在复位完成后才开始工作
- ✅ 添加了复位状态监控和显示

### 4. **完整的脚本链**
- ✅ `gen_vivado_ip_hbm.tcl`: 生成design_1块设计的仿真文件
- ✅ `questasim_compile_hbm.do`: 编译design_1和相关IP
- ✅ `simulate_hbm.sh`: 运行Questasim仿真
- ✅ `run_testcase_hbm.py`: Python测试运行器

## 📁 修改和新增的文件

### 新增文件
```
RecoNIC/sim/
├── scripts/
│   ├── gen_vivado_ip_hbm.tcl        # 生成design_1块设计仿真文件
│   ├── setup_hbm_simulation.sh     # HBM环境一键设置
│   ├── questasim_compile_hbm.do    # Questasim编译脚本
│   └── simulate_hbm.sh             # Questasim仿真运行脚本
├── src/
│   ├── hbm_clk_gen.sv              # HBM 100MHz差分时钟生成器
│   └── rn_tb_top_hbm.sv            # HBM testbench（直接例化open_nic_shell）
├── testcases/
│   ├── read_2rdma_hbm/             # HBM读测试用例
│   └── write_2rdma_hbm/            # HBM写测试用例
├── run_testcase_hbm.py             # HBM专用测试运行器
└── shell/plugs/rdma_onic_plugin/vivado_ip/sim_vivado_ip_hbm.tcl
```

### 已删除的文件
- `sim/src/design_1_sim_wrapper.sv` (简化版本，已不需要)
- `sim/scripts/xsim_compile_hbm.do` (Xsim不支持HBM)

## 🔧 关键技术实现

### 1. 直接集成design_1
```systemverilog
// 在rn_tb_top_hbm.sv中直接例化design_1
design_1_wrapper hbm_subsystem_inst (
  .axis_aclk     (axis_clk),
  .axis_arestn   (powerup_rstn), // 带60us延时
  .hbm_clk_clk_n (hbm_clk_n),
  .hbm_clk_clk_p (hbm_clk_p),
  // ... HBM块设计的完整接口
);
```

### 2. 60us复位逻辑
```systemverilog
// HBM复位逻辑：60us @ 250MHz = 15,000 cycles
always_ff @(posedge axis_clk or negedge axis_rstn) begin
    if (~axis_rstn) begin
        hbm_reset_counter <= 16'd0;
        hbm_rst_done <= 1'b0;
    end else begin
        if (hbm_reset_counter < 16'd15000) begin
            hbm_reset_counter <= hbm_reset_counter + 1'b1;
            hbm_rst_done <= 1'b0;
        end else begin
            hbm_rst_done <= 1'b1;
        end
    end
end
```

### 3. 时钟生成
```systemverilog
// 100MHz HBM差分时钟生成
hbm_clk_gen hbm_clk_gen_inst (
    .hbm_clk_p    (hbm_clk_p),
    .hbm_clk_n    (hbm_clk_n),
    .hbm_clk_locked(hbm_clk_locked)
);
```

## 🚀 使用方法

### 快速开始
```bash
# 1. 设置环境变量
export VIVADO_DIR=/your/vivado/path/Vivado/2021.2
export COMPILED_LIB_DIR=/your/vivado/compiled_lib_dir/for/questasim

# 2. 设置HBM环境（首次运行）
cd RecoNIC/sim/scripts
./setup_hbm_simulation.sh

# 3. 运行HBM仿真
cd RecoNIC/sim
python run_testcase_hbm.py -roce -tc read_2rdma_hbm -gui
```

### 支持的操作
- ✅ RDMA读操作 (`read_2rdma_hbm`)
- ✅ RDMA写操作 (`write_2rdma_hbm`)  
- ✅ 回归测试
- ✅ 调试模式（GUI）
- ✅ 批处理模式（无GUI）

## 🔗 设计链路

```
testbench (rn_tb_top_hbm) 
    ↓
open_nic_shell.sv (您修改的版本)
    ↓  
design_1_wrapper (由您的design_1.tcl生成)
    ↓
HBM IP + SmartConnect + Clock Converter
```

## ⚙️ 与原设计的差异

| 特性 | 原设计 | 新HBM设计 |
|------|--------|----------|
| 设备内存 | `axi_3to1_interconnect_to_dev_mem` + BRAM | `design_1_wrapper` (HBM) |
| 仿真器支持 | Xsim + Questasim | 仅Questasim |
| 复位时间 | 标准 | 60us |
| 时钟转换 | 外部 | 块设计内部 |
| 位宽转换 | 外部 | 块设计内部 |

## ⚠️ 使用注意事项

1. **仿真器**: 必须使用Questasim，Xsim不支持HBM仿真
2. **复位时间**: HBM需要60us复位时间，仿真开始会有延迟
3. **环境变量**: 必须设置`COMPILED_LIB_DIR`
4. **磁盘空间**: HBM块设计文件占用较多空间
5. **仿真速度**: HBM仿真比BRAM模拟慢，但更真实

## 🎯 验证方法

运行以下命令验证HBM仿真环境：

```bash
# 设置环境
export VIVADO_DIR=/your/vivado/path
export COMPILED_LIB_DIR=/your/compiled/lib/path

# 快速验证
cd RecoNIC/sim
./demo_hbm_simulation.sh
```

仿真日志中应该看到：
- `HBM clock locked at time xxx`
- `HBM reset completed at time xxx` 
- `HBM system ready at time xxx`

## 📞 技术支持

如果遇到问题：
1. 确认环境变量设置正确
2. 检查Questasim版本兼容性
3. 验证Vivado仿真库已预编译
4. 检查design_1块设计是否正确生成

这个方案完全按照您的要求，直接使用您的`design_1.tcl`块设计，支持60us复位时间，仅支持Questasim仿真。