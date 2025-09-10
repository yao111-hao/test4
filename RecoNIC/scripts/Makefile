# ==============================================================================
#  Copyright (C) 2023, Advanced Micro Devices, Inc. All rights reserved.
#  SPDX-License-Identifier: MIT
# 
# ==============================================================================
#
# Makefile
# -- The script is used to prepare build files and build the project to generate
#    hardware bitstream
#
# Makefile 概述
# -- 该脚本用于生成构建所需文件并调用 Vivado/TCL 脚本完成硬件 bitstream 的生成
# ==============================================================================

# Please make sure you have exported BOARD_REPO in your system environment
# --------------------------------------------------------------------
# 目录和环境变量定义
# --------------------------------------------------------------------
# 根目录，指向上层目录
# shell 级别的系统顶层模块代码目录
# 存放各种脚本（如 Python 生成 TCL 脚本）的目录
# 总的构建输出目录
# ReconIC (自定义 NIC) 的构建输出子目录,即在build目录下面创建一个reconic文件夹存放构建完成的项目
ROOT_DIR     := ..
SHELL_DIR    := $(ROOT_DIR)/shell
SCRIPT_DIR   := $(ROOT_DIR)/scripts
BUILD_DIR    := $(ROOT_DIR)/build
RN_BUILD_DIR := $(BUILD_DIR)/reconic

# --------------------------------------------------------------------
# 工程构建可配置选项（可通过命令行或环境变量覆盖）
# 是否执行实现（place & route），1: 执行，0: 只综合
# 是否覆盖已有的构建输出，1: 覆盖，0: 不覆盖
# 是否强制重新生成 HLS 代码，1: 生成，0: 跳过（使用已有）
# 目标开发板型号，默认为 au250
# Python 可执行文件名或路径
# --------------------------------------------------------------------
IMPL       ?= 1

OVERWRITE  ?= 1

GEN_HLS    ?= 0

BOARD      ?= au50

PYTHON_EXE ?= python

# --------------------------------------------------------------------
# 检查并提取 Vivado 版本号（如 v2021.2）
# --------------------------------------------------------------------
# Check Vivado version
VIVADO_VERSION := $(shell vivado -version | grep ^Vivado |  sed -n 's/.*\(v[0-9]*.[0-9]*\).*/\1/p')

# Module directories
## RecoNIC top module
# --------------------------------------------------------------------
# 各个模块的源码目录定义
# --------------------------------------------------------------------
# ReconIC 顶层模块
# Packet Classification 模块
# Tag Matching 模块
# Address Translator 模块
# Lookaside Compute 模块
# TODO: Streaming Compute 模块（暂未使用）
# 通用工具代码目录
# 插件目录
# ReconIC 插件目录
# Open NIC Shell（SmartNIC）源码目录
# Open NIC Shell 构建脚本目录
RN_TOP            := $(SHELL_DIR)/top
## Packet Classification module
PC                := packet_classification
PKT_CLASSI_DIR    := $(SHELL_DIR)/$(PC)
## Tag Matching module
TM                := tag_matching
TAG_MATCH_DIR     := $(SHELL_DIR)/$(TM)
## Address Translator module
AT                := address_translator
ADDR_TRANS_DIR    := $(SHELL_DIR)/$(AT)
## Lookaside Compute module
LC                := lookside
LOOKASIDE_COMP_DIR := $(SHELL_DIR)/compute/$(LC)
## TODO: Add Streaming Compute module
#SC                := streaming
#STREAMING_COMP_DIR := $(SHELL_DIR)/compute/$(SC)
## Utilities
UTILITIES_DIR     := $(SHELL_DIR)/utilities
## Plugs
PLUGS_DIR         := $(SHELL_DIR)/plugs

PLUGIN_DIR     := $(PLUGS_DIR)/rdma_onic_plugin
SMARTNIC_DIR := $(ROOT_DIR)/base_nics/open-nic-shell/src/box_250mhz
SMARTNIC_SCRIPT_DIR := $(ROOT_DIR)/base_nics/open-nic-shell/script

# --------------------------------------------------------------------
# 默认目标：先构建 ReconIC，再构建 SmartNIC
# --------------------------------------------------------------------
build_nic: build_reconic
# 如果 IMPL=1，则带实现选项调用 Vivado TCL 脚本
ifeq ($(IMPL), 1)
# 进入Open NIC Shell 构建脚本目录（这个不是原始的构建脚本，而是经过patch文件补丁后的文件）
# build.tcl改动不大，主要增加了单独对ddr4_controller  ip的路径位置的改变
	cd $(SMARTNIC_SCRIPT_DIR) && vivado -mode batch -source build.tcl -tclargs -max_pkt_len 9600 -impl 1 -overwrite $(OVERWRITE) -board_repo $(BOARD_REPO) -board $(BOARD)
else
	cd $(SMARTNIC_SCRIPT_DIR) &&vivado -mode batch -source build.tcl -tclargs -max_pkt_len 9600 -impl 0 -overwrite $(OVERWRITE) -board_repo $(BOARD_REPO) -board $(BOARD)
endif

# --------------------------------------------------------------------
# 构建 ReconIC：先清理、再 HLS 生成、最后拷贝到 BUILD_DIR 并生成 TCL 
# --------------------------------------------------------------------
build_reconic: clean_build hls_build
# 创建输出目录
# - **`BUILD_DIR`**：整个 ReconIC 构建的临时工作区，用来存放插件、TCL 生成脚本等中间产物。
# - **`RN_BUILD_DIR`**：最终打包给 SmartNIC 那部分的子目录（即：要拷贝到 SmartNIC 源码树的代码和文件）。
# - **`$(LC)`** (lookaside)：在 `RN_BUILD_DIR` 下专门为 Lookaside Compute 模块再创建一层目录，用于放 HLS 生成的 `.sv`/`.v` 文件。
# BUILD_DIR：   /mnt/2T/vivado/NIC/reco-nic/reco_built_u250_3/RecoNIC/build
# RN_BUILD_DIR：/mnt/2T/vivado/NIC/reco-nic/reco_built_u250_3/RecoNIC/build/reconic
# 
	mkdir -p $(BUILD_DIR)
	mkdir -p $(RN_BUILD_DIR)
	mkdir -p $(RN_BUILD_DIR)/$(LC)
# 拷贝 ReconIC 各模块源码
# - **`RN_TOP`**：顶层 shell 模块（顶层 Verilog/SystemVerilog 文件、接口定义等）。
# - **`PKT_CLASSI_DIR`**：Packet Classification 模块源码。
# - **`UTILITIES_DIR`**：公共工具库（如仿真脚本、公共定义、辅助函数等）。
# - 这些源码将直接成为 SmartNIC 最终项目的一部分，放在 `RN_BUILD_DIR` 下，保持原有目录结构。
# 
	cp -rf $(PLUGIN_DIR)/* $(BUILD_DIR)/
	cp -rf $(RN_TOP) $(RN_BUILD_DIR)/
	cp -rf $(PKT_CLASSI_DIR) $(RN_BUILD_DIR)/
	cp -rf $(UTILITIES_DIR) $(RN_BUILD_DIR)/
# 拷贝 Lookaside Compute 模块的 HLS 输出
# - 首先拷贝手写或已有的 `.sv` 接口（若有）。
# - 接着拷贝 HLS 在 `interface/` 和 `kernel/` 子目录中生成的 `.v` 文件。
# - 这样，Lookaside Compute 模块就包含完整的手写加 HLS 自动生成的代码。
# 全部放在一个文件夹下
	cp $(LOOKASIDE_COMP_DIR)/*.sv $(RN_BUILD_DIR)/$(LC)/
	cp $(LOOKASIDE_COMP_DIR)/interface/*.v $(RN_BUILD_DIR)/$(LC)/
	cp $(LOOKASIDE_COMP_DIR)/kernel/*.v $(RN_BUILD_DIR)/$(LC)/
# 执行 Python 脚本生成 Vivado TCL
# - 进入中间工作区 `BUILD_DIR`。
# - 调用 `build_tcl.py`，该脚本会：
#   1. 根据你拷贝过来的插件和源码目录，动态生成 Vivado 项目的 `project.tcl`、`settings.tcl` 等文件。
#   2. 设置 IP 路径、约束文件（XDC）、顶层模块名、Board Repository 信息等。
# - 参数 `-nic rdma-opennic` 用于脚本内部切换不同 NIC 类型或配置。
	cd $(BUILD_DIR); $(PYTHON_EXE) $(SCRIPT_DIR)/build_tcl.py -nic rdma-opennic
# SMARTNIC_DIR：/mnt/2T/vivado/NIC/reco-nic/reco_built_u250_3/RecoNIC/base_nics/open-nic-shell/src/box_250mhz
# BUILD_DIR：/mnt/2T/vivado/NIC/reco-nic/reco_built_u250_3/RecoNIC/build
	cp -rf $(BUILD_DIR)/* $(SMARTNIC_DIR)/

# --------------------------------------------------------------------
# HLS 代码生成：根据 GEN_HLS 或已有文件决定是否重新跑 vitis_hls
# --------------------------------------------------------------------
hls_build:
ifeq ($(GEN_HLS), 1)
 # 在 Lookaside Compute 目录下创建 interface 和 kernel 两级输出目录
# /mnt/2T/vivado/NIC/reco-nic/reco_built_u250_3/RecoNIC/shell
	mkdir -p $(LOOKASIDE_COMP_DIR)/interface
	mkdir -p $(LOOKASIDE_COMP_DIR)/kernel
# 进入 HLS 脚本所在目录，依次运行 cl_box 和 mmult 两个 HLS 脚本
	cd $(LOOKASIDE_COMP_DIR); vitis_hls -f ./cl_box.tcl; vitis_hls -f ./mmult.tcl
# 将各自 solution1 下 syn/verilog 目录里生成的所有 .v 文件，
# 分别拷贝到 interface 和 kernel 目录
	cp $(LOOKASIDE_COMP_DIR)/cl_box/solution1/syn/verilog/* $(LOOKASIDE_COMP_DIR)/interface/
	cp $(LOOKASIDE_COMP_DIR)/mmult/solution1/syn/verilog/* $(LOOKASIDE_COMP_DIR)/kernel/
else
 # —— 非强制，仅在缺少目标文件时才生成 —— #
  # 1) 检查 interface 部分：如果 interface/cl_box.v 不存在，则跑 cl_box.tcl
ifeq (,$(wildcard $(LOOKASIDE_COMP_DIR)/interface/cl_box.v))
	mkdir -p $(LOOKASIDE_COMP_DIR)/interface
	cd $(LOOKASIDE_COMP_DIR); vitis_hls -f ./cl_box.tcl
	cp $(LOOKASIDE_COMP_DIR)/cl_box/solution1/syn/verilog/* $(LOOKASIDE_COMP_DIR)/interface/
else
	@echo "Use old files in $(LOOKASIDE_COMP_DIR)/interface"
endif

 # 2) 检查 kernel 部分：如果 kernel/mmult.v 不存在，则跑 mmult.tcl
ifeq (,$(wildcard $(LOOKASIDE_COMP_DIR)/kernel/mmult.v))
	mkdir -p $(LOOKASIDE_COMP_DIR)/kernel
	cd $(LOOKASIDE_COMP_DIR); vitis_hls -f ./mmult.tcl
	cp $(LOOKASIDE_COMP_DIR)/mmult/solution1/syn/verilog/* $(LOOKASIDE_COMP_DIR)/kernel/
else
	@echo "Use old files in $(LOOKASIDE_COMP_DIR)/kernel"
endif
endif

# --------------------------------------------------------------------
# 清理 BUILD_DIR 中的所有文件
# --------------------------------------------------------------------
clean_build:
	rm -rf $(BUILD_DIR)/*

# --------------------------------------------------------------------
# 完整清理：BUILD_DIR 及 SmartNIC 输出目录
# --------------------------------------------------------------------
clean:
	rm -rf $(BUILD_DIR)/*
	rm -rf $(SMARTNIC_DIR)/*
