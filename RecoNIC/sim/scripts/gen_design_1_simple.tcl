#==============================================================================
# Copyright (C) 2023, Advanced Micro Devices, Inc. All rights reserved.
# SPDX-License-Identifier: MIT
#
# design_1 HBM块设计生成脚本
#==============================================================================

puts "========================================="
puts "RecoNIC design_1 HBM块设计生成脚本"
puts "========================================="

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
  puts "INFO: 如果出现板级定义错误，请提供 -board_repo 参数"
} else {
  set_param board.repoPaths $board_repo
  puts "INFO: 使用板级仓库: $board_repo"
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

puts "INFO: 路径配置:"
puts "  Root目录: $root_dir"
puts "  HBM子系统目录: $hbm_subsystem_dir"
puts "  构建目录: $build_dir"

# 检查design_1.tcl文件是否存在
set design_1_tcl "${hbm_subsystem_dir}/design_1.tcl"
if {![file exists $design_1_tcl]} {
    puts "ERROR: design_1.tcl文件不存在: $design_1_tcl"
    exit 1
}
puts "INFO: 找到design_1.tcl文件: $design_1_tcl"

# 创建目录
file mkdir $ip_build_dir
file mkdir $build_managed_ip_dir

puts "INFO: 创建design_1项目..."
create_project -force design_1_project $build_managed_ip_dir -part $part
set_property BOARD_PART $board_part [current_project]

# 生成design_1 HBM块设计
puts "INFO: 创建design_1块设计..."
set bd_name design_1
set bd_dir ${ip_build_dir}/${bd_name}

# 创建块设计
create_bd_design $bd_name
puts "INFO: 块设计 $bd_name 创建成功"

# 执行用户的design_1.tcl脚本
puts "INFO: 执行用户的design_1.tcl脚本..."
source $design_1_tcl
puts "INFO: design_1.tcl执行完成"

# 验证块设计
puts "INFO: 验证块设计..."
validate_bd_design
puts "INFO: 块设计验证通过"

# 生成所有输出产品
puts "INFO: 生成块设计输出产品..."
generate_target all [get_files ${bd_name}.bd]
puts "INFO: 输出产品生成完成"

# 创建HDL wrapper
puts "INFO: 创建HDL wrapper..."
make_wrapper -files [get_files ${bd_name}.bd] -top

# 等待wrapper文件生成
after 3000
puts "INFO: 等待wrapper文件生成完成"

# 查找wrapper文件
set project_dir [get_property directory [current_project]]
set wrapper_patterns [list \
    "$project_dir/design_1_project.gen/sources_1/bd/${bd_name}/hdl/${bd_name}_wrapper.v" \
    "$project_dir/design_1_project.srcs/sources_1/bd/${bd_name}/hdl/${bd_name}_wrapper.v"]

puts "INFO: 查找wrapper文件..."
set wrapper_found 0
set wrapper_file ""

foreach wrapper_pattern $wrapper_patterns {
    puts "  检查: $wrapper_pattern"
    if {[file exists $wrapper_pattern]} {
        set wrapper_file $wrapper_pattern
        set wrapper_found 1
        puts "INFO: 找到wrapper文件: $wrapper_pattern"
        break
    }
}

if {!$wrapper_found} {
    puts "ERROR: 无法找到design_1_wrapper.v文件"
    puts "检查的路径："
    foreach pattern $wrapper_patterns {
        puts "  $pattern"
    }
    
    # 列出实际存在的文件
    puts "实际项目目录内容:"
    set gen_dir "$project_dir/design_1_project.gen"
    if {[file exists $gen_dir]} {
        puts "  gen目录存在: $gen_dir"
        set gen_bd_dir "$gen_dir/sources_1/bd"
        if {[file exists $gen_bd_dir]} {
            puts "  bd目录存在: $gen_bd_dir"
            set contents [glob -nocomplain "$gen_bd_dir/*"]
            foreach item $contents {
                puts "    $item"
            }
        }
    }
    exit 1
}

# 创建仿真目录并复制wrapper
file mkdir ${bd_dir}
file mkdir ${bd_dir}/sim
file copy -force $wrapper_file ${bd_dir}/sim/${bd_name}_wrapper.v
puts "INFO: Wrapper文件已复制到: ${bd_dir}/sim/${bd_name}_wrapper.v"

# 生成仿真目标
puts "INFO: 生成仿真目标..."
generate_target simulation [get_files ${bd_name}.bd]
puts "INFO: 仿真目标生成完成"

puts ""
puts "========================================="
puts "design_1块设计生成完成"
puts "========================================="
puts "块设计位置: ${bd_dir}"
puts "Wrapper文件: ${bd_dir}/sim/design_1_wrapper.v"
puts "状态: 准备就绪，可以运行Questasim仿真"
puts "========================================="