# =========================================================================
#
# TCL脚本：用于在Alveo U50上配置QDMA IP核 (最全功能整合版)
#
# 作者: Gemini AI & User
# 日期: 2025年9月10日
#
# -------------------------------------------------------------------------
# === 脚本功能概述 ===
# -------------------------------------------------------------------------
# 本脚本旨在为Alveo U50开发板创建一个功能全面的QDMA IP核实例。
# 它整合了AU280和AU250配置脚本中的所有相关参数，以确保不会因省略
# 任何默认设置而丢失功能或引发潜在问题。
#
# -------------------------------------------------------------------------
# === 参数详解 ===
# -------------------------------------------------------------------------
#
# --- 基础PCIe与模式配置 ---
# CONFIG.mode_selection:                使用“Advanced”（高级）模式以解锁所有配置选项。
# CONFIG.pl_link_cap_max_link_width:    设置PCIe链路能力为x16带宽。
# CONFIG.pl_link_cap_max_link_speed:    设置PCIe链路速度为Gen3 (8.0 GT/s)。
# CONFIG.en_transceiver_status_ports:   禁用收发器状态端口，以在不需要调试时节省逻辑资源。
#
# --- 板级接口映射 (对AU50至关重要) ---
# CONFIG.SYS_RST_N_BOARD_INTERFACE:     将IP核的物理复位端口，映射到开发板预定义的“pcie_perstn”接口上。
# CONFIG.PCIE_BOARD_INTERFACE:          将IP核的PCIe高速收发器(GT)通道，映射到开发板的“pci_express_x16”物理接口上。
# CONFIG.xlnx_ref_board:                明确告知IP核，当前配置是针对Alveo U50开发板，这有助于工具推断正确的内部参数。
#
# --- 功能性接口配置 ---
# CONFIG.dma_intf_sel_qdma:             设置DMA的数据接口模式为同时支持AXI Memory Mapped和AXI Stream。
# CONFIG.en_axi_mm_qdma:                明确启用AXI-MM（内存映射）接口。
# CONFIG.csr_axilite_slave:             启用AXI-Lite从机接口，用于控制和状态寄存器（CSR）。这是主机软件控制QDMA引擎的必需接口。
# CONFIG.en_bridge_slv:                 启用AXI从设备桥接功能。它允许主机通过某个PCIe BAR地址空间，直接访问FPGA设计中的其他AXI-Lite外设。
#
# --- 高级功能配置 ---
# CONFIG.dsc_byp_mode:                  设置描述符旁路模式，允许IP内部自动获取描述符和由主机软件直接提供描述符两种模式。
# CONFIG.dma_reset_source_sel:          设置DMA核的复位源为“Phy_Ready”，意味着DMA核心将保持在复位状态，直到PCIe物理链路建立稳定。
#
# --- BAR空间、地址映射与MSI-X配置 ---
# pfX_pciebar2axibar_2:                 设置物理功能X的BAR2到AXI地址空间的转换偏移量。设为0表示直接映射，是最常见的配置。
# pfX_bar2_scale_qdma:                  设置物理功能(PF)X的BAR2地址空间的单位（兆字节）。
# pfX_bar2_size_qdma:                   设置BAR2地址空间的大小。
# PF_MSIX_CAP_TABLE_SIZE_qdma:          设置每个PF支持的MSI-X中断向量的数量。
#
# =========================================================================

# 定义IP核名称，便于后续引用
set qdma qdma_no_sriov

# 创建QDMA IP核的一个实例
create_ip -name qdma -vendor xilinx.com -library ip -module_name $qdma -dir ${ip_build_dir}

# 使用-dict（字典）格式一次性设置IP核的多个详细参数
set_property -dict {
    CONFIG.mode_selection {Advanced}
    CONFIG.pl_link_cap_max_link_width {X16}
    CONFIG.pl_link_cap_max_link_speed {8.0_GT/s}
    CONFIG.en_transceiver_status_ports {false}
    CONFIG.SYS_RST_N_BOARD_INTERFACE {pcie_perstn}
    CONFIG.PCIE_BOARD_INTERFACE {pci_express_x16}
    CONFIG.xlnx_ref_board {AU50}
    CONFIG.dma_intf_sel_qdma {AXI_MM_and_AXI_Stream_with_Completion}
    CONFIG.en_axi_mm_qdma {true}
    CONFIG.csr_axilite_slave {true}
    CONFIG.en_bridge_slv {true}
    CONFIG.dsc_byp_mode {Descriptor_bypass_and_internal}
    CONFIG.dma_reset_source_sel {Phy_Ready}
    CONFIG.pf0_bar2_scale_qdma {Megabytes}
    CONFIG.pf0_bar2_size_qdma {4}
    CONFIG.pf1_bar2_scale_qdma {Megabytes}
    CONFIG.pf1_bar2_size_qdma {4}
    CONFIG.pf2_bar2_scale_qdma {Megabytes}
    CONFIG.pf2_bar2_size_qdma {4}
    CONFIG.pf3_bar2_scale_qdma {Megabytes}
    CONFIG.pf3_bar2_size_qdma {4}
    CONFIG.pf1_pciebar2axibar_2 {0x0000000000000000}
    CONFIG.pf2_pciebar2axibar_2 {0x0000000000000000}
    CONFIG.pf3_pciebar2axibar_2 {0x0000000000000000}
    CONFIG.PF0_MSIX_CAP_TABLE_SIZE_qdma {009}
    CONFIG.PF1_MSIX_CAP_TABLE_SIZE_qdma {008}
    CONFIG.PF2_MSIX_CAP_TABLE_SIZE_qdma {008}
    CONFIG.PF3_MSIX_CAP_TABLE_SIZE_qdma {008}
} [get_ips $qdma]

# 从外部变量（通常由Makefile或上层脚本传入）设置启用的物理功能(PF)和队列数量
set_property CONFIG.tl_pf_enable_reg $num_phys_func [get_ips $qdma]
set_property CONFIG.num_queues $num_queue [get_ips $qdma]