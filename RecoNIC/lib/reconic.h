//==============================================================================
// Copyright (C) 2023, Advanced Micro Devices, Inc. All rights reserved.
// SPDX-License-Identifier: MIT
//
//==============================================================================

/** @file reconic.h
 * @brief The header file of the RecoNIC user-space API library.
 * @brief RecoNIC 用户空间 API 库的头文件。
 */

#ifndef __RECONIC_H__
#define __RECONIC_H__

// 包含其他模块的头文件，将整个库的功能汇集在一起
#include "auxiliary.h"
#include "reconic_reg.h"
#include "memory_api.h"
#include "control_api.h"

// -- 全局变量声明 --
/*! \var device
 * \brief 用于表示设备内存访问的字符设备的全局字符串
 */
extern char* device;

/*! \var fpga_fd
 * \brief 用于内存访问的字符设备的文件描述符
 */
extern int fpga_fd;

// -- 内存位置宏定义 --
/*! \def HOST_MEM
 * \brief 代表主机内存的宏字符串
 */
#define HOST_MEM "host_mem"

/*! \def DEVICE_MEM
 * \brief 代表设备内存（板载DDR）的宏字符串
 */
#define DEVICE_MEM "dev_mem"

// -- 内存与页面大小相关宏定义 --
/*! \def DEVICE_MEM_SIZE
 * \brief 以字节为单位的设备内存大小 (4GB)
 */
#define DEVICE_MEM_SIZE 4294967296

/*! \def HARDWARE_PAGE_SIZE
 * \brief 硬件进行AXI4-MM事务的页面大小 (4KB)
 */
#define HARDWARE_PAGE_SIZE 4096

/*! \def HARDWARE_PAGE_SIZE_ALIGNMENT_MASK
 * \brief 用于将地址与硬件页面大小对齐的掩码
 */
#define HARDWARE_PAGE_SIZE_ALIGNMENT_MASK 0xfffffffffffff000

/*! \def HARDWARE_PAGE_SIZE_ADDRESS_MASK
 * \brief 用于获取硬件页面内偏移地址的掩码
 */
#define HARDWARE_PAGE_SIZE_ADDRESS_MASK 0x0000000000000fff

/*! \def PAGE_SHIFT
 * \brief 用于计算页面大小的位移值 (1 << 12 = 4096)
 */
#define PAGE_SHIFT       12  // 4KB

/*! \def PAGEMAP_LENGTH
 * \brief /proc/self/pagemap 中每个条目的长度 (8字节)
 */
#define PAGEMAP_LENGTH  8

/*! \def HUGE_PAGE_SHIFT
 * \brief 用于计算大页内存大小的位移值 (1 << 21 = 2MB)
 */
#define HUGE_PAGE_SHIFT 21

// -- 设备内存地址空间定义 --
/*! \def DEVICE_MEM_OFFSET
 * \brief 设备内存地址的偏移量/标识符
 */
#define DEVICE_MEM_OFFSET 0xa350000000000000

/*! \def DEVICE_MEM_MASK
 * \brief 用于识别设备内存地址的掩码
 */
 
#define DEVICE_MEM_MASK 0xfff0000000000000

// -- 核心数据结构定义 --
/*! \struct mac_addr_t
 * \brief MAC地址结构体，分为高16位和低32位
 */
struct mac_addr_t {
  uint32_t mac_lsb; /*!< MAC地址的低32位 */
  uint32_t mac_msb; /*!< MAC地址的高16位 */
};

/*! \struct win_size_t
 * \brief 用于PCIe BDF地址转换的窗口大小掩码
 */
struct win_size_t {
  uint32_t win_size_lsb; /*!< 窗口大小掩码低32位 */
  uint32_t win_size_msb; /*!< 窗口大小掩码高32位 */
};

/*! \struct rdma_buff_t
 * \brief RDMA缓冲区结构体，包含虚拟和物理地址
 */
struct rdma_buff_t {
  void* buffer;      /*!< 缓冲区的虚拟地址 */
  uint64_t dma_addr; /*!< 缓冲区的物理(DMA)地址 */
  uint32_t buf_size; /*!< 缓冲区大小 */
};

/*! \struct rn_dev_t
 * \brief RecoNIC设备的核心结构体，代表一个物理设备实例
 */
struct rn_dev_t {
  uint32_t* axil_ctl;           /*!< 内存映射后的PCIe控制寄存器基地址 */
  uint32_t  axil_map_size;      /*!< 控制寄存器的映射大小 */
  struct rdma_buff_t* base_buf; /*!< 指向预分配的大页内存缓冲区的指针 */
  void* rdma_dev;               /*!< 指向RDMA设备结构体的指针 (struct rdma_dev_t*) */
  uint64_t buffer_offset;       /*!< 在预分配的主机内存中的当前偏移量，用于简单的内存管理 */
  uint64_t dev_buffer_offset;   /*!< 在设备内存中的当前偏移量 */
  unsigned char num_qp;         /*!< 需要的RDMA队列对数量 */
  struct win_size_t* winSize;   /*!< PCIe BDF地址转换的窗口掩码 */
};

// -- 函数原型声明 --

/** @brief 将IP地址字符串转换为无符号整数
 * @param ip_addr IP地址字符串
 * @return 无符号整数形式的IP地址
 */
uint32_t convert_ip_addr_to_uint(char* ip_addr);

/** @brief 将带冒号的MAC地址字符串转换为mac_addr_t类型
 * @param mac_addr_char 带冒号的MAC地址字符串
 * @return mac_addr_t类型的MAC地址
 */
struct mac_addr_t convert_mac_addr_str_to_uint(char* mac_addr_str);

/** @brief 将无冒号的MAC地址字符数组转换为mac_addr_t类型
 * @param mac_addr_char 无冒号的MAC地址字符数组
 * @return mac_addr_t类型的MAC地址
 */
struct mac_addr_t convert_mac_addr_to_uint(unsigned char* mac_addr_char);

/** @brief 根据IP地址字符串获取对应的MAC地址
 * @param sockfd 一个socket文件描述符
 * @param ip_str IP地址字符串
 * @return mac_addr_t类型的MAC地址
 */
struct mac_addr_t get_mac_addr_from_str_ip(int sockfd, char* ip_str);

/** @brief 检查给定地址是设备内存地址还是主机内存地址
 * @param address 给定的64位地址
 * @return 1 - 设备内存地址; 0 - 主机内存地址
 */
uint8_t is_device_address(uint64_t address);

/** @brief 获取虚拟地址对应的页帧号(PFN)
 * @param addr 虚拟地址
 * @return 页帧号
 */
unsigned long get_page_frame_number_of_address(void *addr);

/** @brief 获取缓冲区的物理地址
 * @param buffer 缓冲区的虚拟地址
 * @return 缓冲区的物理地址
 */
uint64_t get_buffer_paddr(void *buffer);

/** @brief 获取用于计算BDF地址掩码的AXI BAR映射窗口大小
 * @return 窗口大小
 */
uint64_t get_win_size();

/** @brief 配置PCIe AXI Bridge的BDF表以进行地址转换
 * @param rn_dev RecoNIC设备指针
 * @param high_addr 主机缓冲区物理地址的高32位
 * @param low_addr 主机缓冲区物理地址的低32位
 */
void config_rn_dev_axib_bdf(struct rn_dev_t* rn_dev, uint32_t high_addr, uint32_t low_addr);

/** @brief 为RDMA通信分配一个缓冲区
 * @param rn_dev RecoNIC设备指针
 * @param buf_size 缓冲区大小
 * @param buf_location 缓冲区位置 ("host_mem" 或 "dev_mem")
 * @return 指向分配的RDMA缓冲区的指针
 */
struct rdma_buff_t* allocate_rdma_buffer(struct rn_dev_t* rn_dev, uint64_t buf_size, char* buf_location);

/** @brief 创建一个RecoNIC设备实例
 * @param pcie_resource PCIe设备的resource文件路径
 * @param pcie_resource_fd 指向PCIe资源文件描述符的指针
 * @param num_hugepages_request 请求的预分配大页数量
 * @param num_qp 需要的RDMA队列对数量
 * @return 指向创建的RecoNIC设备实例的指针
 */
struct rn_dev_t* create_rn_dev(char* pcie_resource, int* pcie_resource_fd, uint32_t num_hugepages_request, uint32_t num_qp);

#endif /* __RECONIC_H__ */
