//==============================================================================
// Copyright (C) 2023, Advanced Micro Devices, Inc. All rights reserved.
// SPDX-License-Identifier: MIT
//
// 支持HBM的RecoNIC仿真testbench
//==============================================================================
`timescale 1ns/1ps

import rn_tb_pkg::*;

module rn_tb_top_hbm;

string traffic_filename          = "packets";
string table_filename            = "";
string rsp_table_filename        = "";
string golden_resp_filename      = "";
string get_req_feedback_filename = "";
string axi_read_info_filename    = "";
string axi_dev_mem_filename      = "rdma_dev_mem";
string axi_sys_mem_filename      = "rdma_sys_mem";
string rdma_combined_cfg_filename= "rdma_combined_config";

longint num_pkts;
mbox_pkt_str_t gen_pkt_mbox;

logic axil_clk;
logic axil_rstn;
logic axis_clk;
logic axis_rstn;

// HBM时钟信号
logic hbm_clk_p;
logic hbm_clk_n;
logic hbm_clk_locked;

// Metadata
logic [USER_META_DATA_WIDTH-1:0] user_metadata_out;
logic                            user_metadata_out_valid;

// RDMA AXI4-Lite register channel
logic        s_axil_rdma_awvalid;
logic [31:0] s_axil_rdma_awaddr;
logic        s_axil_rdma_awready;
logic        s_axil_rdma_wvalid;
logic [31:0] s_axil_rdma_wdata;
logic        s_axil_rdma_wready;
logic        s_axil_rdma_bvalid;
logic  [1:0] s_axil_rdma_bresp;
logic        s_axil_rdma_bready;
logic        s_axil_rdma_arvalid;
logic [31:0] s_axil_rdma_araddr;
logic        s_axil_rdma_arready;
logic        s_axil_rdma_rvalid;
logic [31:0] s_axil_rdma_rdata;
logic  [1:0] s_axil_rdma_rresp;
logic        s_axil_rdma_rready;

// RecoNIC AXI4-Lite register channel
logic        s_axil_rn_awvalid;
logic [31:0] s_axil_rn_awaddr;
logic        s_axil_rn_awready;
logic        s_axil_rn_wvalid;
logic [31:0] s_axil_rn_wdata;
logic        s_axil_rn_wready;
logic        s_axil_rn_bvalid;
logic  [1:0] s_axil_rn_bresp;
logic        s_axil_rn_bready;
logic        s_axil_rn_arvalid;
logic [31:0] s_axil_rn_araddr;
logic        s_axil_rn_arready;
logic        s_axil_rn_rvalid;
logic [31:0] s_axil_rn_rdata;
logic  [1:0] s_axil_rn_rresp;
logic        s_axil_rn_rready;

// QDMA H2C/C2H simulation interfaces
logic         s_axis_qdma_h2c_sim_tvalid;
logic [511:0] s_axis_qdma_h2c_sim_tdata;
logic [31:0]  s_axis_qdma_h2c_sim_tcrc;
logic         s_axis_qdma_h2c_sim_tlast;
logic [10:0]  s_axis_qdma_h2c_sim_tuser_qid;
logic [2:0]   s_axis_qdma_h2c_sim_tuser_port_id;
logic         s_axis_qdma_h2c_sim_tuser_err;
logic [31:0]  s_axis_qdma_h2c_sim_tuser_mdata;
logic [5:0]   s_axis_qdma_h2c_sim_tuser_mty;
logic         s_axis_qdma_h2c_sim_tuser_zero_byte;
logic         s_axis_qdma_h2c_sim_tready;

logic         m_axis_qdma_c2h_sim_tvalid;
logic [511:0] m_axis_qdma_c2h_sim_tdata;
logic [31:0]  m_axis_qdma_c2h_sim_tcrc;
logic         m_axis_qdma_c2h_sim_tlast;
logic         m_axis_qdma_c2h_sim_ctrl_marker;
logic [2:0]   m_axis_qdma_c2h_sim_ctrl_port_id;
logic [6:0]   m_axis_qdma_c2h_sim_ctrl_ecc;
logic [15:0]  m_axis_qdma_c2h_sim_ctrl_len;
logic [10:0]  m_axis_qdma_c2h_sim_ctrl_qid;
logic         m_axis_qdma_c2h_sim_ctrl_has_cmpt;
logic [5:0]   m_axis_qdma_c2h_sim_mty;
logic         m_axis_qdma_c2h_sim_tready;

// CMAC simulation interfaces
logic         m_axis_cmac_tx_sim_tvalid;
logic [511:0] m_axis_cmac_tx_sim_tdata;
logic [63:0]  m_axis_cmac_tx_sim_tkeep;
logic         m_axis_cmac_tx_sim_tlast;
logic         m_axis_cmac_tx_sim_tuser_err;
logic         m_axis_cmac_tx_sim_tready;

logic         s_axis_cmac_rx_sim_tvalid;
logic [511:0] s_axis_cmac_rx_sim_tdata;
logic [63:0]  s_axis_cmac_rx_sim_tkeep;
logic         s_axis_cmac_rx_sim_tlast;
logic         s_axis_cmac_rx_sim_tuser_err;

logic rdma_intr;

// 信号用于指示内存初始化完成
logic init_sys_mem_done;
logic init_dev_mem_done;
logic start_config_rdma;

// 生成HBM时钟
hbm_clk_gen hbm_clk_gen_inst (
    .hbm_clk_p    (hbm_clk_p),
    .hbm_clk_n    (hbm_clk_n),
    .hbm_clk_locked(hbm_clk_locked)
);

// 数据包生成器
rn_tb_generator generator (
  .traffic_filename(traffic_filename),
  .num_pkts        (num_pkts),
  .mbox_pkt_str    (gen_pkt_mbox)
);

// 测试驱动器
rn_tb_driver driver(
  .num_pkts          (num_pkts),
  .table_filename    (""),
  .rsp_table_filename(""),
  .rdma_cfg_filename (rdma_combined_cfg_filename),
  .rdma_stat_filename(""),

  .mbox_pkt_str(gen_pkt_mbox), 
  
  // 输入到CMAC RX的仿真数据
  .m_axis_tvalid    (s_axis_cmac_rx_sim_tvalid),
  .m_axis_tdata     (s_axis_cmac_rx_sim_tdata),
  .m_axis_tkeep     (s_axis_cmac_rx_sim_tkeep),
  .m_axis_tlast     (s_axis_cmac_rx_sim_tlast),
  .m_axis_tuser_size(16'd0), // 在仿真接口中，这个信号是错误的
  .m_axis_tready    (1'b1), // CMAC RX总是准备接收

  .m_axil_rn_awvalid(s_axil_rn_awvalid),
  .m_axil_rn_awaddr (s_axil_rn_awaddr),
  .m_axil_rn_awready(s_axil_rn_awready),
  .m_axil_rn_wvalid (s_axil_rn_wvalid),
  .m_axil_rn_wdata  (s_axil_rn_wdata),
  .m_axil_rn_wready (s_axil_rn_wready),
  .m_axil_rn_bvalid (s_axil_rn_bvalid),
  .m_axil_rn_bresp  (s_axil_rn_bresp),
  .m_axil_rn_bready (s_axil_rn_bready),
  .m_axil_rn_arvalid(s_axil_rn_arvalid),
  .m_axil_rn_araddr (s_axil_rn_araddr),
  .m_axil_rn_arready(s_axil_rn_arready),
  .m_axil_rn_rvalid (s_axil_rn_rvalid),
  .m_axil_rn_rdata  (s_axil_rn_rdata),
  .m_axil_rn_rresp  (s_axil_rn_rresp),
  .m_axil_rn_rready (s_axil_rn_rready),

  .m_axil_rdma_awvalid(s_axil_rdma_awvalid),
  .m_axil_rdma_awaddr (s_axil_rdma_awaddr),
  .m_axil_rdma_awready(s_axil_rdma_awready),
  .m_axil_rdma_wvalid (s_axil_rdma_wvalid),
  .m_axil_rdma_wdata  (s_axil_rdma_wdata),
  .m_axil_rdma_wready (s_axil_rdma_wready),
  .m_axil_rdma_bvalid (s_axil_rdma_bvalid),
  .m_axil_rdma_bresp  (s_axil_rdma_bresp),
  .m_axil_rdma_bready (s_axil_rdma_bready),
  .m_axil_rdma_arvalid(s_axil_rdma_arvalid),
  .m_axil_rdma_araddr (s_axil_rdma_araddr),
  .m_axil_rdma_arready(s_axil_rdma_arready),
  .m_axil_rdma_rvalid (s_axil_rdma_rvalid),
  .m_axil_rdma_rdata  (s_axil_rdma_rdata),
  .m_axil_rdma_rresp  (s_axil_rdma_rresp),
  .m_axil_rdma_rready (s_axil_rdma_rready),

  .start_sim         (axis_rstn),
  .start_config_rdma (start_config_rdma),
  .start_stat_rdma   (1'b0),
  .stimulus_all_sent(),

  .axil_clk (axil_clk), 
  .axil_rstn(axil_rstn),
  .axis_clk (axis_clk), 
  .axis_rstn(axis_rstn)
);

// 实例化带HBM的open_nic_shell进行仿真
open_nic_shell #(
  .BUILD_TIMESTAMP(32'h01010000),
  .MIN_PKT_LEN    (64),
  .MAX_PKT_LEN    (1518),
  .USE_PHYS_FUNC  (1),
  .NUM_PHYS_FUNC  (1),
  .NUM_QUEUE      (512),
  .NUM_CMAC_PORT  (1)
) open_nic_shell_inst (
  // 仿真模式的接口
  .s_axil_sim_awvalid          (s_axil_rdma_awvalid),
  .s_axil_sim_awaddr           (s_axil_rdma_awaddr),
  .s_axil_sim_awready          (s_axil_rdma_awready),
  .s_axil_sim_wvalid           (s_axil_rdma_wvalid),
  .s_axil_sim_wdata            (s_axil_rdma_wdata),
  .s_axil_sim_wready           (s_axil_rdma_wready),
  .s_axil_sim_bvalid           (s_axil_rdma_bvalid),
  .s_axil_sim_bresp            (s_axil_rdma_bresp),
  .s_axil_sim_bready           (s_axil_rdma_bready),
  .s_axil_sim_arvalid          (s_axil_rdma_arvalid),
  .s_axil_sim_araddr           (s_axil_rdma_araddr),
  .s_axil_sim_arready          (s_axil_rdma_arready),
  .s_axil_sim_rvalid           (s_axil_rdma_rvalid),
  .s_axil_sim_rdata            (s_axil_rdma_rdata),
  .s_axil_sim_rresp            (s_axil_rdma_rresp),
  .s_axil_sim_rready           (s_axil_rdma_rready),

  .s_axis_qdma_h2c_sim_tvalid      (s_axis_qdma_h2c_sim_tvalid),
  .s_axis_qdma_h2c_sim_tdata       (s_axis_qdma_h2c_sim_tdata),
  .s_axis_qdma_h2c_sim_tcrc        (s_axis_qdma_h2c_sim_tcrc),
  .s_axis_qdma_h2c_sim_tlast       (s_axis_qdma_h2c_sim_tlast),
  .s_axis_qdma_h2c_sim_tuser_qid   (s_axis_qdma_h2c_sim_tuser_qid),
  .s_axis_qdma_h2c_sim_tuser_port_id(s_axis_qdma_h2c_sim_tuser_port_id),
  .s_axis_qdma_h2c_sim_tuser_err   (s_axis_qdma_h2c_sim_tuser_err),
  .s_axis_qdma_h2c_sim_tuser_mdata (s_axis_qdma_h2c_sim_tuser_mdata),
  .s_axis_qdma_h2c_sim_tuser_mty   (s_axis_qdma_h2c_sim_tuser_mty),
  .s_axis_qdma_h2c_sim_tuser_zero_byte(s_axis_qdma_h2c_sim_tuser_zero_byte),
  .s_axis_qdma_h2c_sim_tready      (s_axis_qdma_h2c_sim_tready),

  .m_axis_qdma_c2h_sim_tvalid      (m_axis_qdma_c2h_sim_tvalid),
  .m_axis_qdma_c2h_sim_tdata       (m_axis_qdma_c2h_sim_tdata),
  .m_axis_qdma_c2h_sim_tcrc        (m_axis_qdma_c2h_sim_tcrc),
  .m_axis_qdma_c2h_sim_tlast       (m_axis_qdma_c2h_sim_tlast),
  .m_axis_qdma_c2h_sim_ctrl_marker (m_axis_qdma_c2h_sim_ctrl_marker),
  .m_axis_qdma_c2h_sim_ctrl_port_id(m_axis_qdma_c2h_sim_ctrl_port_id),
  .m_axis_qdma_c2h_sim_ctrl_ecc    (m_axis_qdma_c2h_sim_ctrl_ecc),
  .m_axis_qdma_c2h_sim_ctrl_len    (m_axis_qdma_c2h_sim_ctrl_len),
  .m_axis_qdma_c2h_sim_ctrl_qid    (m_axis_qdma_c2h_sim_ctrl_qid),
  .m_axis_qdma_c2h_sim_ctrl_has_cmpt(m_axis_qdma_c2h_sim_ctrl_has_cmpt),
  .m_axis_qdma_c2h_sim_mty         (m_axis_qdma_c2h_sim_mty),
  .m_axis_qdma_c2h_sim_tready      (m_axis_qdma_c2h_sim_tready),

  .m_axis_cmac_tx_sim_tvalid       (m_axis_cmac_tx_sim_tvalid),
  .m_axis_cmac_tx_sim_tdata        (m_axis_cmac_tx_sim_tdata),
  .m_axis_cmac_tx_sim_tkeep        (m_axis_cmac_tx_sim_tkeep),
  .m_axis_cmac_tx_sim_tlast        (m_axis_cmac_tx_sim_tlast),
  .m_axis_cmac_tx_sim_tuser_err    (m_axis_cmac_tx_sim_tuser_err),
  .m_axis_cmac_tx_sim_tready       (m_axis_cmac_tx_sim_tready),

  .s_axis_cmac_rx_sim_tvalid       (s_axis_cmac_rx_sim_tvalid),
  .s_axis_cmac_rx_sim_tdata        (s_axis_cmac_rx_sim_tdata),
  .s_axis_cmac_rx_sim_tkeep        (s_axis_cmac_rx_sim_tkeep),
  .s_axis_cmac_rx_sim_tlast        (s_axis_cmac_rx_sim_tlast),
  .s_axis_cmac_rx_sim_tuser_err    (s_axis_cmac_rx_sim_tuser_err),

  .powerup_rstn                    (axis_rstn && hbm_clk_locked)
);

// 始终接收发送到CMAC tx的数据包
assign m_axis_cmac_tx_sim_tready = 1'b1;
assign m_axis_qdma_c2h_sim_tready = 1'b1;

// 将仿真输入信号连接到适当的接口
assign s_axis_cmac_rx_sim_tuser_err = 1'b0; // 没有错误

// 初始化QDMA仿真信号（当前测试中未使用）
assign s_axis_qdma_h2c_sim_tvalid = 1'b0;
assign s_axis_qdma_h2c_sim_tdata = 512'd0;
assign s_axis_qdma_h2c_sim_tcrc = 32'd0;
assign s_axis_qdma_h2c_sim_tlast = 1'b0;
assign s_axis_qdma_h2c_sim_tuser_qid = 11'd0;
assign s_axis_qdma_h2c_sim_tuser_port_id = 3'd0;
assign s_axis_qdma_h2c_sim_tuser_err = 1'b0;
assign s_axis_qdma_h2c_sim_tuser_mdata = 32'd0;
assign s_axis_qdma_h2c_sim_tuser_mty = 6'd0;
assign s_axis_qdma_h2c_sim_tuser_zero_byte = 1'b0;

assign start_config_rdma = hbm_clk_locked && axis_rstn;

initial begin
  gen_pkt_mbox = new();

  fork
    generator.run();
  join_none
end

// 用于分析的always块
always_comb begin
  if (m_axis_cmac_tx_sim_tvalid && m_axis_cmac_tx_sim_tready) begin
    $display("INFO: [rn_tb_top_hbm] packet_data=%x %x %x", m_axis_cmac_tx_sim_tdata, m_axis_cmac_tx_sim_tkeep, m_axis_cmac_tx_sim_tlast);
  end
end

endmodule: rn_tb_top_hbm
