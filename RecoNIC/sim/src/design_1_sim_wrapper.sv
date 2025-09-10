//==============================================================================
// Copyright (C) 2023, Advanced Micro Devices, Inc. All rights reserved.
// SPDX-License-Identifier: MIT
//
// HBM系统(design_1)的仿真包装器
//==============================================================================
`timescale 1ns/1ps

module design_1_sim_wrapper #(
  parameter C_AXI_DATA_WIDTH = 512,
  parameter C_AXI_ADDR_WIDTH = 64
) (
  // System Clocks and Resets
  input  logic axis_aclk,
  input  logic axis_arestn,
  input  logic pcie_rstn,

  // HBM Physical Interface (simulation - 由时钟生成器提供)
  input  logic hbm_clk_clk_n,
  input  logic hbm_clk_clk_p,

  // Slave AXI Interface 0 (连接到 QDMA Master) 
  input  logic [63:0]  s_axi_qdma_mm_araddr,
  input  logic [1:0]   s_axi_qdma_mm_arburst,
  input  logic [3:0]   s_axi_qdma_mm_arcache,
  input  logic [4:0]   s_axi_qdma_mm_arid,
  input  logic [7:0]   s_axi_qdma_mm_arlen,
  input  logic         s_axi_qdma_mm_arlock,
  input  logic [2:0]   s_axi_qdma_mm_arprot,
  input  logic [3:0]   s_axi_qdma_mm_arqos,
  output logic         s_axi_qdma_mm_arready,
  input  logic [2:0]   s_axi_qdma_mm_arsize,
  input  logic         s_axi_qdma_mm_arvalid,
  input  logic [63:0]  s_axi_qdma_mm_awaddr,
  input  logic [1:0]   s_axi_qdma_mm_awburst,
  input  logic [3:0]   s_axi_qdma_mm_awcache,
  input  logic [4:0]   s_axi_qdma_mm_awid,
  input  logic [7:0]   s_axi_qdma_mm_awlen,
  input  logic         s_axi_qdma_mm_awlock,
  input  logic [2:0]   s_axi_qdma_mm_awprot,
  input  logic [3:0]   s_axi_qdma_mm_awqos,
  output logic         s_axi_qdma_mm_awready,
  input  logic [2:0]   s_axi_qdma_mm_awsize,
  input  logic         s_axi_qdma_mm_awvalid,
  output logic [3:0]   s_axi_qdma_mm_bid,
  input  logic         s_axi_qdma_mm_bready,
  output logic [1:0]   s_axi_qdma_mm_bresp,
  output logic         s_axi_qdma_mm_bvalid,
  output logic [511:0] s_axi_qdma_mm_rdata,
  output logic [3:0]   s_axi_qdma_mm_rid,
  output logic         s_axi_qdma_mm_rlast,
  input  logic         s_axi_qdma_mm_rready,
  output logic [1:0]   s_axi_qdma_mm_rresp,
  output logic         s_axi_qdma_mm_rvalid,
  input  logic [511:0] s_axi_qdma_mm_wdata,
  input  logic         s_axi_qdma_mm_wlast,
  output logic         s_axi_qdma_mm_wready,
  input  logic [63:0]  s_axi_qdma_mm_wstrb,
  input  logic         s_axi_qdma_mm_wvalid,

  // Slave AXI Interface 1 (连接到 Compute Logic Master)
  input  logic [63:0]  s_axi_compute_logic_araddr,
  input  logic [1:0]   s_axi_compute_logic_arburst,
  input  logic [3:0]   s_axi_compute_logic_arcache,
  input  logic         s_axi_compute_logic_arid,
  input  logic [7:0]   s_axi_compute_logic_arlen,
  input  logic         s_axi_compute_logic_arlock,
  input  logic [2:0]   s_axi_compute_logic_arprot,
  input  logic [3:0]   s_axi_compute_logic_arqos,
  output logic         s_axi_compute_logic_arready,
  input  logic [2:0]   s_axi_compute_logic_arsize,
  input  logic         s_axi_compute_logic_arvalid,
  input  logic [63:0]  s_axi_compute_logic_awaddr,
  input  logic [1:0]   s_axi_compute_logic_awburst,
  input  logic [3:0]   s_axi_compute_logic_awcache,
  input  logic         s_axi_compute_logic_awid,
  input  logic [7:0]   s_axi_compute_logic_awlen,
  input  logic         s_axi_compute_logic_awlock,
  input  logic [2:0]   s_axi_compute_logic_awprot,
  input  logic [3:0]   s_axi_compute_logic_awqos,
  output logic         s_axi_compute_logic_awready,
  input  logic [2:0]   s_axi_compute_logic_awsize,
  input  logic         s_axi_compute_logic_awvalid,
  output logic         s_axi_compute_logic_bid,
  input  logic         s_axi_compute_logic_bready,
  output logic [1:0]   s_axi_compute_logic_bresp,
  output logic         s_axi_compute_logic_bvalid,
  output logic [511:0] s_axi_compute_logic_rdata,
  output logic         s_axi_compute_logic_rid,
  output logic         s_axi_compute_logic_rlast,
  input  logic         s_axi_compute_logic_rready,
  output logic [1:0]   s_axi_compute_logic_rresp,
  output logic         s_axi_compute_logic_rvalid,
  input  logic [511:0] s_axi_compute_logic_wdata,
  input  logic         s_axi_compute_logic_wlast,
  output logic         s_axi_compute_logic_wready,
  input  logic [63:0]  s_axi_compute_logic_wstrb,
  input  logic         s_axi_compute_logic_wvalid,

  // Slave AXI Interface 2 (连接到 System Crossbar Master)
  input  logic [63:0]  s_axi_from_sys_crossbar_araddr,
  input  logic [1:0]   s_axi_from_sys_crossbar_arburst,
  input  logic [3:0]   s_axi_from_sys_crossbar_arcache,
  input  logic [4:0]   s_axi_from_sys_crossbar_arid,
  input  logic [7:0]   s_axi_from_sys_crossbar_arlen,
  input  logic         s_axi_from_sys_crossbar_arlock,
  input  logic [2:0]   s_axi_from_sys_crossbar_arprot,
  input  logic [3:0]   s_axi_from_sys_crossbar_arqos,
  output logic         s_axi_from_sys_crossbar_arready,
  input  logic [2:0]   s_axi_from_sys_crossbar_arsize,
  input  logic         s_axi_from_sys_crossbar_arvalid,
  input  logic [63:0]  s_axi_from_sys_crossbar_awaddr,
  input  logic [1:0]   s_axi_from_sys_crossbar_awburst,
  input  logic [3:0]   s_axi_from_sys_crossbar_awcache,
  input  logic [4:0]   s_axi_from_sys_crossbar_awid,
  input  logic [7:0]   s_axi_from_sys_crossbar_awlen,
  input  logic         s_axi_from_sys_crossbar_awlock,
  input  logic [2:0]   s_axi_from_sys_crossbar_awprot,
  input  logic [3:0]   s_axi_from_sys_crossbar_awqos,
  output logic         s_axi_from_sys_crossbar_awready,
  input  logic [2:0]   s_axi_from_sys_crossbar_awsize,
  input  logic         s_axi_from_sys_crossbar_awvalid,
  output logic [4:0]   s_axi_from_sys_crossbar_bid,
  input  logic         s_axi_from_sys_crossbar_bready,
  output logic [1:0]   s_axi_from_sys_crossbar_bresp,
  output logic         s_axi_from_sys_crossbar_bvalid,
  output logic [511:0] s_axi_from_sys_crossbar_rdata,
  output logic [4:0]   s_axi_from_sys_crossbar_rid,
  output logic         s_axi_from_sys_crossbar_rlast,
  input  logic         s_axi_from_sys_crossbar_rready,
  output logic [1:0]   s_axi_from_sys_crossbar_rresp,
  output logic         s_axi_from_sys_crossbar_rvalid,
  input  logic [511:0] s_axi_from_sys_crossbar_wdata,
  input  logic         s_axi_from_sys_crossbar_wlast,
  output logic         s_axi_from_sys_crossbar_wready,
  input  logic [63:0]  s_axi_from_sys_crossbar_wstrb,
  input  logic         s_axi_from_sys_crossbar_wvalid,

  // APB Interface (悬空)
  output logic [31:0]  SAPB_0_paddr,
  output logic         SAPB_0_penable,
  input  logic [31:0]  SAPB_0_prdata,
  input  logic         SAPB_0_pready,
  output logic         SAPB_0_psel,
  input  logic         SAPB_0_pslverr,
  output logic [31:0]  SAPB_0_pwdata,
  output logic         SAPB_0_pwrite
);

// 对于仿真，我们使用简化的BRAM模型来模拟HBM
// 这里使用与原始设计相同的axi_mm_bram来模拟device memory

// 内部信号
logic hbm_clk_100m;
logic hbm_rst_n;

// 简单的时钟缓冲器（仿真中使用axis_aclk作为HBM时钟）
assign hbm_clk_100m = axis_aclk; // 仿真中简化
assign hbm_rst_n = axis_arestn;

// 使用BRAM模拟HBM (512KB for device memory simulation)
// 在实际仿真中，我们依然使用BRAM来模拟HBM的行为
axi_mm_bram hbm_bram_inst (
  .s_axi_aclk      (axis_aclk),
  .s_axi_aresetn   (axis_arestn),
  
  // QDMA MM interface (扩展ID位宽以匹配接口)
  .s_axi_awid      (s_axi_qdma_mm_awid),
  .s_axi_awaddr    (s_axi_qdma_mm_awaddr[18:0]), // 512KB地址空间
  .s_axi_awlen     (s_axi_qdma_mm_awlen),
  .s_axi_awsize    (s_axi_qdma_mm_awsize),
  .s_axi_awburst   (s_axi_qdma_mm_awburst),
  .s_axi_awlock    (s_axi_qdma_mm_awlock),
  .s_axi_awcache   (s_axi_qdma_mm_awcache),
  .s_axi_awprot    (s_axi_qdma_mm_awprot),
  .s_axi_awvalid   (s_axi_qdma_mm_awvalid),
  .s_axi_awready   (s_axi_qdma_mm_awready),
  .s_axi_wdata     (s_axi_qdma_mm_wdata),
  .s_axi_wstrb     (s_axi_qdma_mm_wstrb),
  .s_axi_wlast     (s_axi_qdma_mm_wlast),
  .s_axi_wvalid    (s_axi_qdma_mm_wvalid),
  .s_axi_wready    (s_axi_qdma_mm_wready),
  .s_axi_bid       (s_axi_qdma_mm_bid),
  .s_axi_bresp     (s_axi_qdma_mm_bresp),
  .s_axi_bvalid    (s_axi_qdma_mm_bvalid),
  .s_axi_bready    (s_axi_qdma_mm_bready),
  .s_axi_arid      (s_axi_qdma_mm_arid),
  .s_axi_araddr    (s_axi_qdma_mm_araddr[18:0]), // 512KB地址空间
  .s_axi_arlen     (s_axi_qdma_mm_arlen),
  .s_axi_arsize    (s_axi_qdma_mm_arsize),
  .s_axi_arburst   (s_axi_qdma_mm_arburst),
  .s_axi_arlock    (s_axi_qdma_mm_arlock),
  .s_axi_arcache   (s_axi_qdma_mm_arcache),
  .s_axi_arprot    (s_axi_qdma_mm_arprot),
  .s_axi_arvalid   (s_axi_qdma_mm_arvalid),
  .s_axi_arready   (s_axi_qdma_mm_arready),
  .s_axi_rid       (s_axi_qdma_mm_rid),
  .s_axi_rdata     (s_axi_qdma_mm_rdata),
  .s_axi_rresp     (s_axi_qdma_mm_rresp),
  .s_axi_rlast     (s_axi_qdma_mm_rlast),
  .s_axi_rvalid    (s_axi_qdma_mm_rvalid),
  .s_axi_rready    (s_axi_qdma_mm_rready)
);

// 对于compute logic和system crossbar接口，在仿真中我们先悬空
// 在真实的HBM系统中，这些接口会连接到smartconnect
assign s_axi_compute_logic_awready = 1'b0;
assign s_axi_compute_logic_wready = 1'b0;
assign s_axi_compute_logic_bvalid = 1'b0;
assign s_axi_compute_logic_bresp = 2'b00;
assign s_axi_compute_logic_bid = 1'b0;
assign s_axi_compute_logic_arready = 1'b0;
assign s_axi_compute_logic_rdata = 512'd0;
assign s_axi_compute_logic_rresp = 2'b00;
assign s_axi_compute_logic_rlast = 1'b0;
assign s_axi_compute_logic_rvalid = 1'b0;
assign s_axi_compute_logic_rid = 1'b0;

assign s_axi_from_sys_crossbar_awready = 1'b0;
assign s_axi_from_sys_crossbar_wready = 1'b0;
assign s_axi_from_sys_crossbar_bvalid = 1'b0;
assign s_axi_from_sys_crossbar_bresp = 2'b00;
assign s_axi_from_sys_crossbar_bid = 5'd0;
assign s_axi_from_sys_crossbar_arready = 1'b0;
assign s_axi_from_sys_crossbar_rdata = 512'd0;
assign s_axi_from_sys_crossbar_rresp = 2'b00;
assign s_axi_from_sys_crossbar_rlast = 1'b0;
assign s_axi_from_sys_crossbar_rvalid = 1'b0;
assign s_axi_from_sys_crossbar_rid = 5'd0;

// APB接口悬空
assign SAPB_0_paddr = 32'd0;
assign SAPB_0_penable = 1'b0;
assign SAPB_0_psel = 1'b0;
assign SAPB_0_pwdata = 32'd0;
assign SAPB_0_pwrite = 1'b0;

endmodule
