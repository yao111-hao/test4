#==============================================================================
# Copyright (C) 2023, Advanced Micro Devices, Inc. All rights reserved.
# SPDX-License-Identifier: MIT
#
# HBM仿真基础IP生成脚本（重新生成版本）
#==============================================================================

puts ""
puts "========================================="
puts "RecoNIC HBM仿真基础IP生成脚本"
puts "版本: 2023.09.10 - 修复版"
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
    } else {
        puts "忽略未知参数 $arg = $val"
    }
}

foreach {key value} [array get build_options] {
    set [string range $key 1 end] $value
}

# 板级仓库配置
if {[string equal $board_repo ""]} {
  puts "INFO: 未指定板级仓库路径"
} else {
  set_param board.repoPaths $board_repo
  puts "INFO: 使用板级仓库: $board_repo"
}

# 基本配置
set vivado_version 2021.2
set board au50
set part xcu50-fsvh2104-2-e
set board_part xilinx.com:au50:part0:1.3

puts "INFO: Vivado版本: $vivado_version"
puts "INFO: 目标板卡: $board ($board_part)"
puts "INFO: FPGA器件: $part"

# 路径配置
set root_dir [file normalize ../..]
set ip_src_dir $root_dir/shell/plugs/rdma_onic_plugin
set sim_dir $root_dir/sim
set build_dir $sim_dir/build
set ip_build_dir $build_dir/ip
set build_managed_ip_dir $build_dir/managed_ip

puts ""
puts "路径配置:"
puts "  根目录: $root_dir"
puts "  IP源目录: $ip_src_dir"  
puts "  构建目录: $build_dir"
puts "  IP构建目录: $ip_build_dir"

# 创建必要目录
puts ""
puts "创建目录结构..."
file mkdir $ip_build_dir
file mkdir $build_managed_ip_dir
puts "✓ 目录结构创建完成"

# 创建Vivado项目
puts ""
puts "创建Vivado项目..."
create_project -force managed_ip_project $build_managed_ip_dir -part $part
set_property BOARD_PART $board_part [current_project]
puts "✓ 项目创建完成: [get_property NAME [current_project]]"

# 加载IP列表
puts ""
puts "加载IP列表..."
set sim_ip_list_file "${ip_src_dir}/vivado_ip/sim_vivado_ip_hbm.tcl"
puts "IP列表文件: $sim_ip_list_file"

if {[file exists $sim_ip_list_file]} {
    source $sim_ip_list_file
    puts "✓ IP列表加载成功"
    puts "IP列表: $ips"
} else {
    puts "ERROR: IP列表文件不存在: $sim_ip_list_file"
    puts "请确保以下文件存在并包含IP列表:"
    puts "  $sim_ip_list_file"
    exit 1
}

# 生成每个IP
puts ""
puts "开始生成基础仿真IP..."
puts "========================================="

set ip_count 0
foreach ip $ips {
    incr ip_count
    puts ""
    puts "[$ip_count/[llength $ips]] 生成IP: $ip"
    puts "-----------------------------------------"
    
    set ip_dir ${ip_build_dir}/$ip
    set xci_file ${ip_dir}/$ip.xci
    set ip_tcl_file ${ip_src_dir}/vivado_ip/${ip}.tcl
    
    puts "  IP目录: $ip_dir"
    puts "  XCI文件: $xci_file"
    puts "  TCL脚本: $ip_tcl_file"
    
    # 检查TCL文件
    if {![file exists $ip_tcl_file]} {
        puts "  ERROR: IP TCL文件不存在: $ip_tcl_file"
        exit 1
    }
    
    # 创建IP目录
    file mkdir $ip_dir
    
    # 执行IP生成TCL
    puts "  执行IP生成脚本..."
    if {[catch {source $ip_tcl_file} error]} {
        puts "  ERROR: IP TCL脚本执行失败: $error"
        exit 1
    }
    
    # 验证XCI文件生成
    if {![file exists $xci_file]} {
        puts "  ERROR: IP生成失败，XCI文件不存在: $xci_file"
        exit 1
    }
    puts "  ✓ XCI文件生成成功"
    
    # 生成IP输出产品
    puts "  生成IP输出产品..."
    generate_target all [get_files $xci_file]
    puts "  ✓ 输出产品生成完成"
    
    # 创建综合运行
    puts "  启动IP综合..."
    create_ip_run [get_files -of_objects [get_fileset sources_1] $xci_file]
    launch_runs ${ip}_synth_1 -jobs 8
    wait_on_run ${ip}_synth_1
    
    # 检查综合状态
    set run_state [get_property STATE [get_runs ${ip}_synth_1]]
    set run_status [get_property STATUS [get_runs ${ip}_synth_1]]
    
    puts "  综合状态: $run_state"
    puts "  综合结果: $run_status" 
    
    if {$run_state eq "FINISHED"} {
        puts "  ✓ $ip 综合成功"
    } else {
        puts "  ERROR: $ip 综合失败"
        puts "  状态: $run_state"
        puts "  结果: $run_status"
        exit 1
    }
    
    puts "  ✓ $ip 生成完成"
}

puts ""
puts "========================================="
puts "所有基础仿真IP生成成功！"
puts "========================================="
puts ""
puts "生成的IP列表:"
foreach ip $ips {
    puts "  ✓ $ip -> $ip_build_dir/$ip"
}
puts ""
puts "下一步: 运行以下命令生成design_1块设计:"
puts "  vivado -mode batch -source gen_design_1_simple.tcl"
puts "========================================="
