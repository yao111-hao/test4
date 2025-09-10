#==============================================================================
# Copyright (C) 2023, Advanced Micro Devices, Inc. All rights reserved.
# SPDX-License-Identifier: MIT
#
# 为HBM系统生成IP和块设计的脚本
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

puts "INFO: Building HBM subsystem and required IPs for simulation"
create_project -force managed_ip_project $build_managed_ip_dir -part $part
set_property BOARD_PART $board_part [current_project]

# 1. 首先生成标准IP核
puts "INFO: Generating standard IP cores..."
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

# 2. 生成HBM块设计
puts "INFO: Generating HBM block design..."
set bd_name design_1
set bd_dir ${ip_build_dir}/${bd_name}
file mkdir $bd_dir

# 创建块设计
create_bd_design $bd_name

# 执行HBM块设计的TCL脚本
source ${hbm_subsystem_dir}/design_1.tcl

# 生成输出产品
generate_target all [get_files ${bd_name}.bd]

# 创建HDL wrapper
make_wrapper -files [get_files ${bd_name}.bd] -top
add_files -norecurse [get_property directory [current_project]]/managed_ip_project.srcs/sources_1/bd/${bd_name}/hdl/${bd_name}_wrapper.v

# 生成块设计的仿真文件
generate_target simulation [get_files ${bd_name}.bd]
export_simulation -of_objects [get_files ${bd_name}.bd] -directory ${bd_dir}/sim -ip_user_files_dir ${bd_dir}/sim/ip_user_files -ipstatic_source_dir ${bd_dir}/sim/ipstatic -lib_map_path [list {modelsim=${bd_dir}/sim/lib/questa} {questa=${bd_dir}/sim/lib/questa} {riviera=${bd_dir}/sim/lib/riviera} {activehdl=${bd_dir}/sim/lib/activehdl}] -use_ip_compiled_libs -force

puts "INFO: HBM block design $bd_name is generated"

# 3. 生成HBM时钟生成器IP（如果需要的话）
set hbm_clk_gen_ip "hbm_clk_gen"
set hbm_clk_gen_xci ${ip_build_dir}/${hbm_clk_gen_ip}/${hbm_clk_gen_ip}.xci

# 创建HBM时钟生成器
create_ip -name clk_wiz -vendor xilinx.com -library ip -version 6.0 -module_name $hbm_clk_gen_ip -dir $ip_build_dir
set_property -dict [list \
  CONFIG.PRIM_SOURCE {Differential_clock_capable_pin} \
  CONFIG.PRIM_IN_FREQ {100.000} \
  CONFIG.CLKOUT1_USED {true} \
  CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {100.000} \
  CONFIG.CLK_IN1_BOARD_INTERFACE {hbm_clk} \
  CONFIG.USE_BOARD_FLOW {true} \
  CONFIG.USE_RESET {false} \
  CONFIG.USE_LOCKED {true} \
  CONFIG.RESET_TYPE {ACTIVE_LOW} \
  CONFIG.CLKIN1_JITTER_PS {50.0} \
  CONFIG.MMCM_DIVCLK_DIVIDE {1} \
  CONFIG.MMCM_CLKFBOUT_MULT_F {10.000} \
  CONFIG.MMCM_CLKIN1_PERIOD {10.000} \
  CONFIG.MMCM_CLKOUT0_DIVIDE_F {10.000} \
  CONFIG.CLKOUT1_JITTER {115.831} \
  CONFIG.CLKOUT1_PHASE_ERROR {87.180} \
] [get_ips $hbm_clk_gen_ip]

generate_target all [get_files $hbm_clk_gen_xci]
create_ip_run [get_files -of_objects [get_fileset sources_1] $hbm_clk_gen_xci]
launch_runs ${hbm_clk_gen_ip}_synth_1 -jobs 8
wait_on_run ${hbm_clk_gen_ip}_synth_1
puts "INFO: $hbm_clk_gen_ip is generated"

puts "INFO: All HBM IPs and block design for simulation are generated"
puts "INFO: Block design files are located at: ${bd_dir}"
puts "INFO: Block design simulation files are located at: ${bd_dir}/sim"
