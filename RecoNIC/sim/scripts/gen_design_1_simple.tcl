#==============================================================================
# Copyright (C) 2023, Advanced Micro Devices, Inc. All rights reserved.
# SPDX-License-Identifier: MIT
#
# 简化的design_1 HBM块设计生成脚本（避免export_simulation问题）
#==============================================================================
array set build_options {
  -board_repo ""
}

# 处理命令行参数
for {set i 0} {$i < $argc} {incr i 2} {
    set arg [lindex $argv $i]
    set val [lindex $argv [expr $i+1]]
    if {[info exists build_options($arg)]} {
        set build_options($arg) $val
        puts "Set build option $arg to $val"
    } else {
        puts "Skip unknown argument $arg and its value $val"
    }
}

# 设置基础配置
foreach {key value} [array get build_options] {
    set [string range $key 1 end] $value
}

if {[string equal $board_repo ""]} {
  puts "INFO: 如果出现板级定义错误，请在命令行提供 -board_repo 参数"
} else {
  set_param board.repoPaths $board_repo
}

set vivado_version 2021.2
set board au50
set part xcu50-fsvh2104-2-e
set board_part xilinx.com:au50:part0:1.3

set root_dir [file normalize ../..]
set sim_dir $root_dir/sim
set build_dir $sim_dir/build
set ip_build_dir $build_dir/ip
set build_managed_ip_dir $build_dir/managed_ip
set hbm_subsystem_dir $root_dir/base_nics/open-nic-shell/src/hbm_subsystem

file mkdir $ip_build_dir
file mkdir $build_managed_ip_dir

puts "INFO: 简化生成design_1 HBM块设计"
create_project -force design_1_project $build_managed_ip_dir -part $part
set_property BOARD_PART $board_part [current_project]

# 生成design_1 HBM块设计
puts "INFO: 创建design_1块设计..."
set bd_name design_1
set bd_dir ${ip_build_dir}/${bd_name}

# 创建块设计
create_bd_design $bd_name

# 执行用户的design_1.tcl脚本
source ${hbm_subsystem_dir}/design_1.tcl

# 验证和生成
validate_bd_design
generate_target all [get_files ${bd_name}.bd]

# 创建wrapper文件
make_wrapper -files [get_files ${bd_name}.bd] -top

# 等待文件生成
after 2000

# 查找并复制wrapper文件
set project_dir [get_property directory [current_project]]
set wrapper_patterns [list \
    "$project_dir/design_1_project.gen/sources_1/bd/${bd_name}/hdl/${bd_name}_wrapper.v" \
    "$project_dir/design_1_project.srcs/sources_1/bd/${bd_name}/hdl/${bd_name}_wrapper.v"]

set wrapper_found 0
file mkdir ${bd_dir}
file mkdir ${bd_dir}/sim

foreach wrapper_pattern $wrapper_patterns {
    if {[file exists $wrapper_pattern]} {
        file copy -force $wrapper_pattern ${bd_dir}/sim/${bd_name}_wrapper.v
        puts "INFO: Wrapper文件已复制: $wrapper_pattern -> ${bd_dir}/sim/"
        set wrapper_found 1
        break
    }
}

if {!$wrapper_found} {
    puts "ERROR: 无法找到design_1_wrapper.v文件"
    puts "检查的路径："
    foreach pattern $wrapper_patterns {
        puts "  $pattern"
    }
    exit 1
}

# 生成简化的仿真文件
generate_target simulation [get_files ${bd_name}.bd]

puts "INFO: design_1块设计生成完成"
puts "INFO: Wrapper文件位置: ${bd_dir}/sim/design_1_wrapper.v"
puts "INFO: 现在可以运行Questasim仿真"
