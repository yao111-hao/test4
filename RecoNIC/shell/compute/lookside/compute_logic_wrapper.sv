//==============================================================================
// Copyright (C) 2023, Advanced Micro Devices, Inc. All rights reserved.
// SPDX-License-Identifier: MIT
//
//==============================================================================
`timescale 1ns/1ps

// 这是一个顶层封装模块(wrapper)，它将所有与计算相关的逻辑整合在一起。
module compute_logic_wrapper # (
  // --- 参数定义 ---
  parameter AXIL_ADDR_WIDTH  = 12, // AXI-Lite接口的地址位宽，2^12 = 4096个地址，即4KB地址空间
  parameter AXIL_DATA_WIDTH  = 32, // AXI-Lite接口的数据位宽，32位，对应C代码中的uint32_t
  parameter AXIS_DATA_WIDTH  = 512,// AXI-Stream/AXI-Memory Mapped接口的数据位宽，512位，用于高带宽数据传输
  parameter AXIS_KEEP_WIDTH  = 64  // AXI-Stream的TKEEP信号位宽 (512/8)
) (
  // AXI-Lite 从机接口 (Slave Interface) - 这是与主机CPU进行MMIO交互的端口
  // 主机通过这个接口来读写本模块内的控制和状态寄存器。
  // 这就是C代码中 write32_data 和 read32_data 函数直接操作的硬件接口。
  input         s_axil_awvalid,
  input  [31:0] s_axil_awaddr,
  output        s_axil_awready,
  input         s_axil_wvalid,
  input  [31:0] s_axil_wdata,
  output        s_axil_wready,
  output        s_axil_bvalid,
  output  [1:0] s_axil_bresp,
  input         s_axil_bready,
  input         s_axil_arvalid,
  input  [31:0] s_axil_araddr,
  output        s_axil_arready,
  output        s_axil_rvalid,
  output [31:0] s_axil_rdata,
  output  [1:0] s_axil_rresp,
  input         s_axil_rready,
  
  // 全功能AXI 主机接口 (Master Interface) - 这是计算核心访问板载DDR内存的端口
  // 与3to1 crossbar连接
  // 计算核心(mmult)通过这个接口，作为总线主控方，去读写FPGA板上的DDR。
  // ... 用于发起写和读事务，以访问板载DDR中的矩阵A, B, C。
  output            m_axi_awid,
  output   [63 : 0] m_axi_awaddr,
  output    [3 : 0] m_axi_awqos,
  output    [7 : 0] m_axi_awlen,
  output    [2 : 0] m_axi_awsize,
  output    [1 : 0] m_axi_awburst,
  output    [3 : 0] m_axi_awcache,
  output    [2 : 0] m_axi_awprot,
  output            m_axi_awvalid,
  input             m_axi_awready,
  output  [511 : 0] m_axi_wdata,
  output   [63 : 0] m_axi_wstrb,
  output            m_axi_wlast,
  output            m_axi_wvalid,
  input             m_axi_wready,
  output            m_axi_awlock,
  input             m_axi_bid,
  input     [1 : 0] m_axi_bresp,
  input             m_axi_bvalid,
  output            m_axi_bready,
  output            m_axi_arid,
  output   [63 : 0] m_axi_araddr,
  output    [7 : 0] m_axi_arlen,
  output    [2 : 0] m_axi_arsize,
  output    [1 : 0] m_axi_arburst,
  output    [3 : 0] m_axi_arcache,
  output    [2 : 0] m_axi_arprot,
  output            m_axi_arvalid,
  input             m_axi_arready,
  input             m_axi_rid,
  input   [511 : 0] m_axi_rdata,
  input     [1 : 0] m_axi_rresp,
  input             m_axi_rlast,
  input             m_axi_rvalid,
  output            m_axi_rready,
  output            m_axi_arlock,
  output     [3:0]  m_axi_arqos,

  // --- 时钟和复位信号 ---
  input          axil_aclk, // AXI-Lite接口的时钟
  input          axil_rstn, // AXI-Lite接口的复位 (低有效)
  input          axis_aclk, // AXI-Stream/计算核心的时钟
  input          axis_rstn  // AXI-Stream/计算核心的复位 (低有效)
);

// --- 内部信号线定义 ---
// 临时的AXI lock信号线
logic [1:0] m_axi_awlock_tmp;
logic [1:0] m_axi_arlock_tmp;

// --- 连接 control_command_processor 和 cl_box 的“命令FIFO”的信号线 ---
logic [31:0] ctl_cmd_fifo_dout;    // 从FIFO读出的数据 (即命令字)
logic        ctl_cmd_fifo_empty_n; // FIFO非空标志
logic        ctl_cmd_fifo_rd_en;   // FIFO读使能信号

// --- 连接 mmult_kernel 和 control_command_processor 的“状态FIFO”的信号线 ---
logic [31:0] ker_status_fifo_din;    // 写入FIFO的数据 (即完成的work_id)
logic        ker_status_fifo_full_n; // FIFO未满标志
logic        ker_status_fifo_wr_en;  // FIFO写使能信号

// --- cl_box模块的控制信号 ---
logic cl_box_start; // 启动cl_box开始解析命令
logic cl_box_done;  // cl_box解析完成一个完整命令的标志
logic cl_box_idle;  // cl_box空闲
logic cl_box_ready; // cl_box准备好接收

// --- cl_box模块解析出的命令参数信号 ---
// 这些信号对应C代码中ctl_cmd_t结构体的字段
// typedef struct {
// 	uint32_t ctl_cmd_size; /*!< ctl_cmd_size size of a compute control command. 一条控制命令的总大小 */
// 	uint32_t a_baseaddr;   /*!< a_baseaddr baseaddress of array A.矩阵A在FPGA板载DDR**中的基地址*/
// 	uint32_t b_baseaddr;   /*!< b_baseaddr baseaddress of array B. */
// 	uint32_t c_baseaddr;   /*!< c_baseaddr baseaddress of array C. */
// 	uint16_t a_row;        /*!< a_row row size of array A. */ 矩阵的维度
// 	uint16_t a_col;        /*!< a_col column size of array A. */
// 	uint16_t b_col;        /*!< b_col column size of array B. */
// 	uint16_t work_id;      /*!< work_id a work/job ID. */ 任务ID
// } ctl_cmd_t;
//  任务ID。用于异步任务管理。主机可以连续下发多个任务（每个任务有唯一的work_id），
//  FPGA完成后，会将对应的work_id写回到状态FIFO，这样主机就能准确知道是哪一个任务完成了。

logic [31:0] a_baseaddr;
logic        a_baseaddr_ap_vld; // a_baseaddr有效标志
logic [31:0] b_baseaddr;
logic        b_baseaddr_ap_vld;
logic [31:0] c_baseaddr;
logic        c_baseaddr_ap_vld;
logic [31:0] a_row;
logic        a_row_ap_vld;
logic [31:0] a_col;
logic        a_col_ap_vld;
logic [31:0] b_col;
logic        b_col_ap_vld;
logic [31:0] work_id;
logic        work_id_ap_vld;

// --- 传递给mmult计算核心的控制信号和参数寄存器 ---
logic ap_start; // 启动mmult核心的信号
logic ap_done;  // mmult核心完成信号
logic ap_idle;  // mmult核心空闲信号
logic ap_ready; // mmult核心准备好接收下一个任务

// 用于锁存(latch)从cl_box解析出的参数，为mmult核心提供稳定的输入
logic [63:0] a_baseaddr_reg;
logic [63:0] b_baseaddr_reg;
logic [63:0] c_baseaddr_reg;
logic [31:0] a_row_reg;
logic [31:0] a_col_reg;
logic [31:0] b_col_reg;
logic [31:0] work_id_reg;

// --- 状态机定义 ---
localparam COMPUTE_IDLE = 1'b0; // 计算状态机：空闲
localparam COMPUTE_BUSY = 1'b1; // 计算状态机：忙碌

logic comp_state;  // 当前状态机状态
logic new_req;     // 标志信号，表示一个新命令已经被cl_box解析完毕
logic new_req_reg; // new_req的寄存器版本，用于同步

//==============================================================================
// 模块实例化
//==============================================================================

// --- 1. 命令处理器 (Control Command Processor) ---
// 这个模块是硬件的“前门”。它处理来自主机的AXI-Lite读写请求。
// - 写操作: 主机通过`issue_ctl_cmd`写入的数据，被此模块接收并推入`ctl_cmd_fifo`。
// - 读操作: 主机通过`wait_compute`读取状态，此模块会从`ker_status_fifo`中读取完成的work_id并返回。
control_command_processor #(
  .AXIL_ADDR_WIDTH (AXIL_ADDR_WIDTH),
  .AXIL_DATA_WIDTH (AXIL_DATA_WIDTH)
) ctl_cmd_proc (
  // AXI-Lite从机接口，连接到模块顶层
  .s_axil_awvalid(s_axil_awvalid),
  .s_axil_awaddr (s_axil_awaddr[AXIL_ADDR_WIDTH-1:0]),
  .s_axil_awready(s_axil_awready),
  .s_axil_wvalid (s_axil_wvalid ),
  .s_axil_wdata  (s_axil_wdata  ),
  .s_axil_wready (s_axil_wready ),
  .s_axil_bvalid (s_axil_bvalid ),
  .s_axil_bresp  (s_axil_bresp  ),
  .s_axil_bready (s_axil_bready ),
  .s_axil_arvalid(s_axil_arvalid),
  .s_axil_araddr (s_axil_araddr[AXIL_ADDR_WIDTH-1:0]),
  .s_axil_arready(s_axil_arready),
  .s_axil_rvalid (s_axil_rvalid ),
  .s_axil_rdata  (s_axil_rdata  ),
  .s_axil_rresp  (s_axil_rresp  ),
  .s_axil_rready (s_axil_rready ),

  // 连接到cl_box模块的控制信号
  .cl_box_idle         (cl_box_idle),
  .cl_box_start        (cl_box_start),
  .cl_box_done         (cl_box_done),
  // 连接到mmult核心的控制信号
  .cl_kernel_idle      (ap_idle),
  .cl_kernel_done      (ap_done),
  // 命令FIFO接口 (从此模块输出到FIFO)
  .ctl_cmd_fifo_dout   (ctl_cmd_fifo_dout),
  .ctl_cmd_fifo_empty_n(ctl_cmd_fifo_empty_n),
  .ctl_cmd_fifo_rd_en  (ctl_cmd_fifo_rd_en),

  // 状态FIFO接口 (从此模块输入到FIFO)
  .ker_status_fifo_din   (ker_status_fifo_din),
  .ker_status_fifo_full_n(ker_status_fifo_full_n),
  .ker_status_fifo_wr_en (ker_status_fifo_wr_en),

  // 时钟和复位
  .axil_aclk (axil_aclk),
  .axil_arstn(axil_rstn),
  .axis_aclk (axis_aclk),
  .axis_arstn(axis_rstn)
);

// Compute_Logic box
// --- 2. 命令解析器 (Compute Logic Box) ---
// 这个模块从`ctl_cmd_fifo`中读取原始的命令字流，
// 并将其解析/解包(unpack)成结构化的参数信号（如a_baseaddr, a_row等）。
// 它负责将C代码中打包的两个16位数重新拆开。
cl_box cl_box_wrapper (
  .ap_local_block              (),
  .ap_local_deadlock           (),
  .ap_clk                      (axis_aclk),
  .ap_rst                      (~axis_rstn),  // 注意：复位信号极性取反
  .ap_start                    (cl_box_start),
  .ap_done                     (cl_box_done),
  .ap_idle                     (cl_box_idle),
  .ap_ready                    (cl_box_ready),
  // 命令FIFO的输入端
  .ctl_cmd_stream_dout         (ctl_cmd_fifo_dout),
  .ctl_cmd_stream_empty_n      (ctl_cmd_fifo_empty_n),
  .ctl_cmd_stream_read         (ctl_cmd_fifo_rd_en),
  // 解析出的参数输出端
  // (所有ctl_cmd_t字段对应的输出信号)
  .a_baseaddr                  (a_baseaddr),
  .a_baseaddr_ap_vld           (a_baseaddr_ap_vld),
  .b_baseaddr                  (b_baseaddr),
  .b_baseaddr_ap_vld           (b_baseaddr_ap_vld),
  .c_baseaddr                  (c_baseaddr),
  .c_baseaddr_ap_vld           (c_baseaddr_ap_vld),
  .a_row                       (a_row),
  .a_row_ap_vld                (a_row_ap_vld),
  .a_col                       (a_col),
  .a_col_ap_vld                (a_col_ap_vld),
  .b_col                       (b_col),
  .b_col_ap_vld                (b_col_ap_vld),
  .work_id                     (work_id),
  .work_id_ap_vld              (work_id_ap_vld)
);

// --- 3. 矩阵乘法计算核心 (MMult Kernel) ---
// 这才是真正执行计算任务的模块。它通常由Vitis HLS等高层次综合工具生成。
// 它接收解析后的参数，通过AXI Master接口从板载DDR读写数据，完成计算
mmult kernel_mmult (
  .ap_local_block   (),
  .ap_local_deadlock(),
  .ap_clk           (axis_aclk),
  .ap_rst_n         (axis_rstn),
  .ap_start         (ap_start),  // 由顶层的状态机控制
  .ap_done          (ap_done),
  .ap_idle          (ap_idle),
  .ap_ready         (ap_ready),
   // AXI Master接口，连接到模块顶层，用于访问DDR
  .m_axi_systolic_AWVALID (m_axi_awvalid),
  .m_axi_systolic_AWREADY (m_axi_awready),
  .m_axi_systolic_AWADDR  (m_axi_awaddr),
  .m_axi_systolic_AWID    (m_axi_awid),
  .m_axi_systolic_AWLEN   (m_axi_awlen),
  .m_axi_systolic_AWSIZE  (m_axi_awsize),
  .m_axi_systolic_AWBURST (m_axi_awburst),
  .m_axi_systolic_AWLOCK  (m_axi_awlock_tmp),
  .m_axi_systolic_AWCACHE (m_axi_awcache),
  .m_axi_systolic_AWPROT  (m_axi_awprot),
  .m_axi_systolic_AWQOS   (m_axi_awqos),
  .m_axi_systolic_AWREGION(),
  .m_axi_systolic_AWUSER  (),
  .m_axi_systolic_WVALID  (m_axi_wvalid),
  .m_axi_systolic_WREADY  (m_axi_wready),
  .m_axi_systolic_WDATA   (m_axi_wdata),
  .m_axi_systolic_WSTRB   (m_axi_wstrb),
  .m_axi_systolic_WLAST   (m_axi_wlast),
  .m_axi_systolic_WID     (),
  .m_axi_systolic_WUSER   (),
  .m_axi_systolic_ARVALID (m_axi_arvalid),
  .m_axi_systolic_ARREADY (m_axi_arready),
  .m_axi_systolic_ARADDR  (m_axi_araddr),
  .m_axi_systolic_ARID    (m_axi_arid),
  .m_axi_systolic_ARLEN   (m_axi_arlen),
  .m_axi_systolic_ARSIZE  (m_axi_arsize),
  .m_axi_systolic_ARBURST (m_axi_arburst),
  .m_axi_systolic_ARLOCK  (m_axi_arlock_tmp),
  .m_axi_systolic_ARCACHE (m_axi_arcache),
  .m_axi_systolic_ARPROT  (m_axi_arprot),
  .m_axi_systolic_ARQOS   (m_axi_arqos),
  .m_axi_systolic_ARREGION(),
  .m_axi_systolic_ARUSER  (),
  .m_axi_systolic_RVALID  (m_axi_rvalid),
  .m_axi_systolic_RREADY  (m_axi_rready),
  .m_axi_systolic_RDATA   (m_axi_rdata),
  .m_axi_systolic_RLAST   (m_axi_rlast),
  .m_axi_systolic_RID     (m_axi_rid),
  .m_axi_systolic_RUSER   (),
  .m_axi_systolic_RRESP   (m_axi_rresp),
  .m_axi_systolic_BVALID  (m_axi_bvalid),
  .m_axi_systolic_BREADY  (m_axi_bready),
  .m_axi_systolic_BRESP   (m_axi_bresp),
  .m_axi_systolic_BID     (m_axi_bid),
  .m_axi_systolic_BUSER   (),
  // 状态FIFO的输出端，当计算完成后，将work_id写入FIFO
  .work_id_out_stream_din   (ker_status_fifo_din),
  .work_id_out_stream_full_n(ker_status_fifo_full_n),
  .work_id_out_stream_write (ker_status_fifo_wr_en),
  // 接收锁存后的参数作为输入
  .a             (a_baseaddr_reg),
  .b             (b_baseaddr_reg),
  .c             (c_baseaddr_reg),
  .a_row         (a_row_reg),
  .a_row_ap_vld  (new_req_reg),
  .a_col         (a_col_reg),
  .a_col_ap_vld  (new_req_reg),
  .b_col         (b_col_reg),
  .b_col_ap_vld  (new_req_reg),
  .work_id       (work_id_reg),
  .work_id_ap_vld(new_req_reg)
);

assign new_req = cl_box_done;

always_ff @(posedge axis_aclk) begin
  if(!axis_rstn) begin
    a_baseaddr_reg <= 64'd0;
    b_baseaddr_reg <= 64'd0;
    c_baseaddr_reg <= 64'd0;
    a_row_reg      <= 32'd0;
    a_col_reg      <= 32'd0;
    b_col_reg      <= 32'd0;
    work_id_reg    <= 32'd0;

    ap_start    <= 1'b0;
    new_req_reg <= 1'b0;
    comp_state  <= COMPUTE_IDLE;
  end
  else begin
    ap_start <= 1'b0;
    a_baseaddr_reg <= a_baseaddr_ap_vld ? {32'd0, a_baseaddr} : a_baseaddr_reg;
    b_baseaddr_reg <= b_baseaddr_ap_vld ? {32'd0, b_baseaddr} : b_baseaddr_reg;
    c_baseaddr_reg <= c_baseaddr_ap_vld ? {32'd0, c_baseaddr} : c_baseaddr_reg;

    a_row_reg     <= a_row_ap_vld ? a_row : a_row_reg;
    a_col_reg     <= a_col_ap_vld ? a_col : a_col_reg;
    b_col_reg     <= b_col_ap_vld ? b_col : b_col_reg;

    work_id_reg   <= work_id_ap_vld ? work_id : work_id_reg;

    new_req_reg <= new_req;

    case(comp_state)
    COMPUTE_IDLE: begin
      if(ap_idle) begin
        if(new_req) begin
          ap_start <= 1'b1;
          comp_state <= COMPUTE_BUSY;
        end
        else begin
          comp_state <= COMPUTE_IDLE;
        end
      end
    end
    COMPUTE_BUSY: begin
      ap_start   <= ap_ready ? 1'b0 : 1'b1;
      comp_state <= ap_done ? COMPUTE_IDLE : COMPUTE_BUSY;
    end
    endcase
  end
end

assign m_axi_awlock = m_axi_awlock_tmp[0];
assign m_axi_arlock = m_axi_arlock_tmp[0];

endmodule: compute_logic_wrapper
