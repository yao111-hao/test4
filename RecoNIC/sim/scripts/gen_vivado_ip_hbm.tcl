#==============================================================================
# Copyright (C) 2023, Advanced Micro Devices, Inc. All rights reserved.
# SPDX-License-Identifier: MIT
#
# HBM仿真基础IP生成脚本（修复版 - 正确的Vivado命令语法）
#==============================================================================

puts ""
puts "========================================="
puts "RecoNIC HBM仿真基础IP生成脚本"
puts "版本: 2023.09.10 - 命令语法修复版"
puts "========================================="

# 命令行参数处理
array set build_options {
  -board_repo ""
}

for {set i 0} {$i < $argc} {incr i 2} {
    set arg [lindex $argv $i]
    set val [lindex $argv [expr $i+1]]
    if {[info exists build_options($arg)]} {
        set build_options($arg) $val
        puts "设置构建选项 $arg = $val"
    }
}

foreach {key value} [array get build_options] {
    set [string range $key 1 end] $value
}

# 板级仓库配置
if {![string equal $board_repo ""]} {
  set_param board.repoPaths $board_repo
  puts "INFO: 使用板级仓库: $board_repo"
}

# 基本配置
set vivado_version 2021.2
set part xcu50-fsvh2104-2-e
set board_part xilinx.com:au50:part0:1.3

puts "INFO: 目标器件: $part"
puts "INFO: 板卡: $board_part"

# 路径配置
set root_dir [file normalize ../..]
set sim_dir $root_dir/sim
set build_dir $sim_dir/build
set ip_build_dir $build_dir/ip
set build_managed_ip_dir $build_dir/managed_ip

# 创建必要目录
file mkdir $ip_build_dir
file mkdir $build_managed_ip_dir

puts ""
puts "创建Vivado项目..."
create_project -force managed_ip_project $build_managed_ip_dir -part $part
set_property BOARD_PART $board_part [current_project]
puts "✓ 项目创建完成"

puts ""
puts "开始生成基础仿真IP..."
puts "========================================="

# 1. axi_mm_bram
puts ""
puts "[1/3] 生成 axi_mm_bram..."

create_ip -name axi_bram_ctrl -vendor xilinx.com -library ip -version 4.1 \
    -module_name axi_mm_bram -dir $ip_build_dir

set_property -dict [list \
    CONFIG.DATA_WIDTH {512} \
    CONFIG.SUPPORTS_NARROW_BURST {1} \
    CONFIG.SINGLE_PORT_BRAM {0} \
    CONFIG.ECC_TYPE {0} \
    CONFIG.BMG_INSTANCE {INTERNAL} \
    CONFIG.MEM_DEPTH {8192} \
    CONFIG.ID_WIDTH {5} \
    CONFIG.RD_CMD_OPTIMIZATION {0} \
] [get_ips axi_mm_bram]

generate_target all [get_files ${ip_build_dir}/axi_mm_bram/axi_mm_bram.xci]
create_ip_run [get_files -of_objects [get_fileset sources_1] ${ip_build_dir}/axi_mm_bram/axi_mm_bram.xci]
launch_runs axi_mm_bram_synth_1 -jobs 8
wait_on_run axi_mm_bram_synth_1

# 检查综合状态
set synth_status [get_property STATUS [get_runs axi_mm_bram_synth_1]]
if {[string match "*Complete*" $synth_status]} {
    puts "✓ axi_mm_bram 生成和综合成功"
} else {
    puts "ERROR: axi_mm_bram 综合失败: $synth_status"
    exit 1
}

# 2. axi_sys_mm
puts ""
puts "[2/3] 生成 axi_sys_mm..."

create_ip -name axi_bram_ctrl -vendor xilinx.com -library ip -version 4.1 \
    -module_name axi_sys_mm -dir $ip_build_dir

set_property -dict [list \
    CONFIG.DATA_WIDTH {512} \
    CONFIG.SUPPORTS_NARROW_BURST {1} \
    CONFIG.SINGLE_PORT_BRAM {0} \
    CONFIG.ECC_TYPE {0} \
    CONFIG.BMG_INSTANCE {INTERNAL} \
    CONFIG.MEM_DEPTH {16384} \
    CONFIG.ID_WIDTH {5} \
    CONFIG.RD_CMD_OPTIMIZATION {0} \
] [get_ips axi_sys_mm]

generate_target all [get_files ${ip_build_dir}/axi_sys_mm/axi_sys_mm.xci]
create_ip_run [get_files -of_objects [get_fileset sources_1] ${ip_build_dir}/axi_sys_mm/axi_sys_mm.xci]
launch_runs axi_sys_mm_synth_1 -jobs 8
wait_on_run axi_sys_mm_synth_1

# 检查综合状态
set synth_status [get_property STATUS [get_runs axi_sys_mm_synth_1]]
if {[string match "*Complete*" $synth_status]} {
    puts "✓ axi_sys_mm 生成和综合成功"
} else {
    puts "ERROR: axi_sys_mm 综合失败: $synth_status"
    exit 1
}

# 3. axi_protocol_checker  
puts ""
puts "[3/3] 生成 axi_protocol_checker..."

create_ip -name axi_protocol_checker -vendor xilinx.com -library ip -version 2.0 \
    -module_name axi_protocol_checker -dir $ip_build_dir

set_property -dict [list \
    CONFIG.ADDR_WIDTH {64} \
    CONFIG.DATA_WIDTH {512} \
    CONFIG.READ_WRITE_MODE {read_write} \
    CONFIG.MAX_RD_BURSTS {16} \
    CONFIG.MAX_WR_BURSTS {16} \
    CONFIG.HAS_SYSTEM_RESET {0} \
    CONFIG.ENABLE_MARK_DEBUG {1} \
    CONFIG.CHK_ERR_RESP {0} \
    CONFIG.HAS_WSTRB {1} \
] [get_ips axi_protocol_checker]

generate_target all [get_files ${ip_build_dir}/axi_protocol_checker/axi_protocol_checker.xci]
create_ip_run [get_files -of_objects [get_fileset sources_1] ${ip_build_dir}/axi_protocol_checker/axi_protocol_checker.xci]
launch_runs axi_protocol_checker_synth_1 -jobs 8
wait_on_run axi_protocol_checker_synth_1

# 检查综合状态
set synth_status [get_property STATUS [get_runs axi_protocol_checker_synth_1]]
if {[string match "*Complete*" $synth_status]} {
    puts "✓ axi_protocol_checker 生成和综合成功"
} else {
    puts "ERROR: axi_protocol_checker 综合失败: $synth_status"
    exit 1
}

puts ""
puts "验证所有IP生成结果..."

# 验证文件存在性
set required_ips [list axi_mm_bram axi_sys_mm axi_protocol_checker]
set all_ok 1

foreach ip $required_ips {
    set xci_file ${ip_build_dir}/$ip/$ip.xci
    if {[file exists $xci_file]} {
        set file_size [file size $xci_file]
        puts "  ✓ $ip: $file_size bytes"
    } else {
        puts "  ❌ $ip: XCI文件不存在 - $xci_file"
        set all_ok 0
    }
}

if {$all_ok} {
    puts ""
    puts "========================================="
    puts "🎉 所有基础仿真IP生成成功！"
    puts "========================================="
    
    puts ""
    puts "生成的IP列表:"
    foreach ip $required_ips {
        puts "  ✓ $ip -> ${ip_build_dir}/$ip"
    }
    
    puts ""
    puts "下一步: 生成design_1 HBM块设计"
    puts "命令: vivado -mode batch -source gen_design_1_simple.tcl"
    puts "========================================="
} else {
    puts ""
    puts "❌ 部分IP生成失败，请检查上述错误"
    exit 1
}

# 项目清理 - 使用正确的命令
puts ""
puts "清理项目..."
close_project -quiet
puts "✓ 项目清理完成"

puts ""
puts "基础IP生成脚本执行完成！"
puts "所有IP已成功生成在: $ip_build_dir"