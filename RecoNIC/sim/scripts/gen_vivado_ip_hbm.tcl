#==============================================================================
# Copyright (C) 2023, Advanced Micro Devices, Inc. All rights reserved.
# SPDX-License-Identifier: MIT
#
# 为HBM块设计生成仿真支持文件的脚本
#==============================================================================
array set build_options {
  -board_repo ""
}

# Expect arguments in the form of `-argument value`
for {set i 0} {$i < $argc} {incr i 2} {
    set arg [lindex $argv $i]
    set val [lindex $argv [expr $i+1]]
    if {[info exists build_options($arg)]} {
        set build_options($arg) $val
        puts "Set build option $arg to $val"
    } elseif {[info exists design_params($arg)]} {
        set design_params($arg) $val
        puts "Set design parameter $arg to $val"
    } else {
        puts "Skip unknown argument $arg and its value $val"
    }
}

# Settings based on defaults or passed in values
foreach {key value} [array get build_options] {
    set [string range $key 1 end] $value
}

if {[string equal $board_repo ""]} {
  puts "INFO: if showing board_part definition error, please provide \"board_repo\" in the command line to indicate Xilinx board repo path"
} else {
  set_param board.repoPaths $board_repo
}

set vivado_version 2021.2
set board au50
set part xcu50-fsvh2104-2-e
set board_part xilinx.com:au50:part0:1.3

set root_dir [file normalize ../..]
set ip_src_dir $root_dir/shell/plugs/rdma_onic_plugin
set sim_dir $root_dir/sim
set build_dir $sim_dir/build
set ip_build_dir $build_dir/ip
set build_managed_ip_dir $build_dir/managed_ip
set hbm_subsystem_dir $root_dir/base_nics/open-nic-shell/src/hbm_subsystem

file mkdir $ip_build_dir
file mkdir $build_managed_ip_dir

puts "INFO: Building design_1 HBM block design and required IPs for Questasim simulation"
create_project -force managed_ip_project $build_managed_ip_dir -part $part
set_property BOARD_PART $board_part [current_project]

# 1. 生成仿真所需的基础IP核
puts "INFO: Generating basic simulation IP cores..."
source ${ip_src_dir}/vivado_ip/sim_vivado_ip_hbm.tcl
foreach ip $ips {
  set xci_file ${ip_build_dir}/$ip/$ip.xci
  source ${ip_src_dir}/vivado_ip/${ip}.tcl

  generate_target all [get_files  $xci_file]
  create_ip_run [get_files -of_objects [get_fileset sources_1] $xci_file]
  launch_runs ${ip}_synth_1 -jobs 8
  wait_on_run ${ip}_synth_1
  puts "INFO: $ip is generated"
}

# 2. 生成design_1 HBM块设计
puts "INFO: Generating design_1 HBM block design for simulation..."
set bd_name design_1
set bd_dir ${ip_build_dir}/${bd_name}
file mkdir $bd_dir

# 创建块设计项目
create_bd_design $bd_name

# 执行用户的design_1.tcl脚本
source ${hbm_subsystem_dir}/design_1.tcl

# 验证块设计
validate_bd_design

# 生成所有输出产品
generate_target all [get_files ${bd_name}.bd]

# 创建HDL wrapper用于仿真
make_wrapper -files [get_files ${bd_name}.bd] -top
set wrapper_file [get_property directory [current_project]]/managed_ip_project.srcs/sources_1/bd/${bd_name}/hdl/${bd_name}_wrapper.v
add_files -norecurse $wrapper_file

# 生成仿真文件 - 专门为Questasim优化
puts "INFO: Generating simulation files for Questasim..."
generate_target simulation [get_files ${bd_name}.bd]

# 导出仿真文件到指定目录，专门支持Questasim
export_simulation -of_objects [get_files ${bd_name}.bd] -directory ${bd_dir}/sim \
  -simulator questa \
  -ip_user_files_dir ${bd_dir}/sim/ip_user_files \
  -ipstatic_source_dir ${bd_dir}/sim/ipstatic \
  -lib_map_path [list {questa=${bd_dir}/sim/lib/questa}] \
  -use_ip_compiled_libs -force

puts "INFO: design_1 HBM block design for Questasim simulation is generated"

# 复制wrapper文件到仿真目录
file copy -force $wrapper_file ${bd_dir}/sim/${bd_name}_wrapper.v

puts "INFO: design_1 HBM block design generation completed"
puts "INFO: Block design files are located at: ${bd_dir}"
puts "INFO: Questasim simulation files are located at: ${bd_dir}/sim"
puts "INFO: Wrapper file: ${bd_dir}/sim/${bd_name}_wrapper.v"