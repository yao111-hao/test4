#==============================================================================
# Copyright (C) 2023, Advanced Micro Devices, Inc. All rights reserved.
# SPDX-License-Identifier: MIT
#
# HBM仿真基础IP生成脚本（直接内联创建IP）
#==============================================================================

puts ""
puts "========================================="
puts "RecoNIC HBM仿真基础IP生成脚本"
puts "版本: 2023.09.10 - 直接创建版"
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
set sim_dir $root_dir/sim
set build_dir $sim_dir/build
set ip_build_dir $build_dir/ip
set build_managed_ip_dir $build_dir/managed_ip

puts ""
puts "路径配置:"
puts "  根目录: $root_dir"
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

# 直接创建需要的IP
puts ""
puts "开始生成仿真IP..."
puts "========================================="

# 1. 创建 axi_mm_bram
puts ""
puts "[1/3] 创建 axi_mm_bram..."
if {[file exists ${ip_build_dir}/axi_mm_bram]} {
    file delete -force ${ip_build_dir}/axi_mm_bram
}

create_ip -name axi_bram_ctrl -vendor xilinx.com -library ip -version 4.1 -module_name axi_mm_bram -dir $ip_build_dir

set_property -dict {
    CONFIG.DATA_WIDTH {512}
    CONFIG.SUPPORTS_NARROW_BURST {1}
    CONFIG.SINGLE_PORT_BRAM {0}
    CONFIG.ECC_TYPE {0}
    CONFIG.BMG_INSTANCE {INTERNAL}
    CONFIG.MEM_DEPTH {8192}
    CONFIG.ID_WIDTH {5}
    CONFIG.RD_CMD_OPTIMIZATION {0}
} [get_ips axi_mm_bram]

generate_target all [get_files ${ip_build_dir}/axi_mm_bram/axi_mm_bram.xci]
create_ip_run [get_files -of_objects [get_fileset sources_1] ${ip_build_dir}/axi_mm_bram/axi_mm_bram.xci]
launch_runs axi_mm_bram_synth_1 -jobs 8
wait_on_run axi_mm_bram_synth_1
puts "✓ axi_mm_bram 生成成功"

# 2. 创建 axi_sys_mm  
puts ""
puts "[2/3] 创建 axi_sys_mm..."
if {[file exists ${ip_build_dir}/axi_sys_mm]} {
    file delete -force ${ip_build_dir}/axi_sys_mm
}

create_ip -name axi_bram_ctrl -vendor xilinx.com -library ip -version 4.1 -module_name axi_sys_mm -dir $ip_build_dir

set_property -dict {
    CONFIG.DATA_WIDTH {512}
    CONFIG.SUPPORTS_NARROW_BURST {1}
    CONFIG.SINGLE_PORT_BRAM {0}
    CONFIG.ECC_TYPE {0}
    CONFIG.BMG_INSTANCE {INTERNAL}
    CONFIG.MEM_DEPTH {16384}
    CONFIG.ID_WIDTH {5}
    CONFIG.RD_CMD_OPTIMIZATION {0}
} [get_ips axi_sys_mm]

generate_target all [get_files ${ip_build_dir}/axi_sys_mm/axi_sys_mm.xci]
create_ip_run [get_files -of_objects [get_fileset sources_1] ${ip_build_dir}/axi_sys_mm/axi_sys_mm.xci]
launch_runs axi_sys_mm_synth_1 -jobs 8
wait_on_run axi_sys_mm_synth_1
puts "✓ axi_sys_mm 生成成功"

# 3. 创建 axi_protocol_checker
puts ""
puts "[3/3] 创建 axi_protocol_checker..."
if {[file exists ${ip_build_dir}/axi_protocol_checker]} {
    file delete -force ${ip_build_dir}/axi_protocol_checker
}

create_ip -name axi_protocol_checker -vendor xilinx.com -library ip -version 2.0 -module_name axi_protocol_checker -dir $ip_build_dir

set_property -dict {
    CONFIG.PROTOCOL {AXI4}
    CONFIG.DATA_WIDTH {512}
    CONFIG.ID_WIDTH {4}
    CONFIG.AWUSER_WIDTH {32}
    CONFIG.ARUSER_WIDTH {32}
    CONFIG.WUSER_WIDTH {64}
    CONFIG.RUSER_WIDTH {64}
    CONFIG.BUSER_WIDTH {0}
    CONFIG.CHK_PARAMS {1}
    CONFIG.HAS_WSTRB {1}
    CONFIG.MAX_WR_OUTSTANDING_TRANSACTIONS {8}
    CONFIG.MAX_RD_OUTSTANDING_TRANSACTIONS {8}
    CONFIG.MAX_RD_BURST_LENGTH {16}
    CONFIG.MAX_WR_BURST_LENGTH {16}
} [get_ips axi_protocol_checker]

generate_target all [get_files ${ip_build_dir}/axi_protocol_checker/axi_protocol_checker.xci]
create_ip_run [get_files -of_objects [get_fileset sources_1] ${ip_build_dir}/axi_protocol_checker/axi_protocol_checker.xci]
launch_runs axi_protocol_checker_synth_1 -jobs 8
wait_on_run axi_protocol_checker_synth_1
puts "✓ axi_protocol_checker 生成成功"

# 最终保存项目
puts ""
puts "保存项目..."
save_project -force
puts "✓ 项目保存完成"

# 验证所有IP都生成成功
puts ""
puts "验证IP生成结果..."
set required_ips {axi_mm_bram axi_sys_mm axi_protocol_checker}
set all_ok 1

foreach ip $required_ips {
    set xci_file ${ip_build_dir}/$ip/$ip.xci
    if {[file exists $xci_file]} {
        set file_size [file size $xci_file]
        puts "  ✓ $ip : $file_size bytes"
    } else {
        puts "  ❌ $ip : XCI文件不存在"
        set all_ok 0
    }
}

if {$all_ok} {
    puts ""
    puts "========================================="
    puts "所有基础仿真IP生成成功！"
    puts "========================================="
    puts ""
    puts "生成的IP:"
    foreach ip $required_ips {
        puts "  ✓ $ip -> $ip_build_dir/$ip"
    }
    puts ""
    puts "下一步: 生成design_1块设计"
    puts "命令: vivado -mode batch -source gen_design_1_simple.tcl"
    puts "========================================="
} else {
    puts ""
    puts "ERROR: 部分IP生成失败，请检查上述错误信息"
    exit 1
}

puts ""
puts "基础IP生成脚本执行完成"