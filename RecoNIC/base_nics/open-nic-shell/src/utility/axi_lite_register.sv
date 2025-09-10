// *************************************************************************
//
// Copyright 2020 Xilinx, Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// *************************************************************************
// Utility block that converts an AXI-Lite interface to simple register R/W
// signals.  The two interfaces can be configured to run under a common clock
// where signals are directly sampled, or independent clocks where CDC buffers
// are included to guarantee data validity.
// 这是一个工具模块，用于将一个标准的AXI-Lite接口转换为简单的寄存器读/写信号。
// 这两个接口可以被配置为在同一个时钟下运行（信号直接采样），
// 或者在独立时钟下运行（此时会包含跨时钟域CDC缓冲以保证数据有效性）。
// 时钟模式: "common_clock" (同步) 或 "independent_clock" (异步),异步模式则需要用到clock converter模块进行转换
`timescale 1ns/1ps
module axi_lite_register #(
  parameter     CLOCKING_MODE = "common_clock",// 时钟模式: "common_clock" (同步) 或 "independent_clock" (异步)
  parameter int ADDR_W        = 32,
  parameter int DATA_W        = 32
) (
  // --- AXI4-Lite 从接口 (Slave Interface) ---
  // --- 写地址通道 (Write Address Channel)
  input                   s_axil_awvalid, // 写地址有效信号
  input      [ADDR_W-1:0] s_axil_awaddr,  // 写地址
  output                  s_axil_awready, // 写地址就绪信号
  // --- 写数据通道 (Write Data Channel)
  input                   s_axil_wvalid,  // 写数据有效信号
  input      [DATA_W-1:0] s_axil_wdata,   // 写数据
  output                  s_axil_wready,  // 写数据就绪信号
  // --- 写响应通道 (Write Response Channel)
  output                  s_axil_bvalid,  // 写响应有效信号
  output            [1:0] s_axil_bresp,   // 写响应状态 (00=OKAY)
  input                   s_axil_bready,  // 写响应就緒信号
  // --- 读地址通道 (Read Address Channel)
  input                   s_axil_arvalid, // 读地址有效信号
  input      [ADDR_W-1:0] s_axil_araddr,  // 读地址
  output                  s_axil_arready, // 读地址就绪信号
  // --- 读数据通道 (Read Data Channel)
  output                  s_axil_rvalid,  // 读数据有效信号
  output     [DATA_W-1:0] s_axil_rdata,   // 读数据
  output            [1:0] s_axil_rresp,   // 读响应状态 (00=OKAY)
  input                   s_axil_rready,  // 读数据就绪信号

  // --- 简化的寄存器风格接口 (Simplified Register-Style Interface) ---
  output                  reg_en,         // 寄存器访问使能信号 (读或写)
  output                  reg_we,         // 寄存器写使能信号 (高有效表示写, 低有效表示读)
  output     [ADDR_W-1:0] reg_addr,       // 访问的寄存器地址
  output     [DATA_W-1:0] reg_din,        // 写入寄存器的数据
  input      [DATA_W-1:0] reg_dout,       // 从寄存器读出的数据

  // --- 时钟与复位信号 ---
  input                   axil_aclk,      // AXI-Lite 接口时钟
  input                   axil_aresetn,   // AXI-Lite 接口复位 (低有效)
  input                   reg_clk,        // 寄存器接口时钟
  input                   reg_rstn        // 寄存器接口复位 (低有效)
);

  // --- AXI-Lite 状态机状态定义 ---
  // 写通道状态
  localparam S_AXIL_WCH_IDLE = 3'd0; // 空闲状态
  localparam S_AXIL_WCH_W    = 3'd1; // 等待写数据 (已收到地址)
  localparam S_AXIL_WCH_AW   = 3'd2; // 等待写地址 (已收到数据)
  localparam S_AXIL_WCH_B    = 3'd3; // 等待寄存器写完成, 准备发送响应
  localparam S_AXIL_WCH_RET  = 3'd4; // 已发送响应, 等待主机确认
  // 读通道状态
  localparam S_AXIL_RCH_IDLE = 2'd0; // 空闲状态
  localparam S_AXIL_RCH_RD   = 2'd1; // 等待寄存器读完成
  localparam S_AXIL_RCH_RET  = 2'd2; // 已发送读数据, 等待主机确认

  // --- 内部AXI-Lite信号定义 ---
  // 这些信号是状态机逻辑的核心。
  // 在 "common_clock" 模式下, 它们直接连接到外部端口。
  // 在 "independent_clock" 模式下, 它们连接到时钟转换器的输出端。
  wire              awvalid;
  wire [ADDR_W-1:0] awaddr;
  reg               awready;
  wire              wvalid;
  wire [DATA_W-1:0] wdata;
  reg               wready;
  reg               bvalid;
  reg         [1:0] bresp;
  wire              bready;
  wire              arvalid;
  wire [ADDR_W-1:0] araddr;
  reg               arready;
  reg               rvalid;
  reg  [DATA_W-1:0] rdata;
  reg         [1:0] rresp;
  wire              rready;

   // --- 内部通道信号, 用于连接AXI状态机和寄存器接口 ---
  reg                   wch_en;     // 写通道使能 (送往寄存器接口)
  wire                  wch_ack;    // 写通道完成确认 (来自寄存器接口)
  reg      [ADDR_W-1:0] wch_addr;   // 写地址锁存
  reg      [DATA_W-1:0] wch_din;    // 写数据锁存
  reg                   rch_en;     // 读通道使能 (送往寄存器接口)
  wire                  rch_ack;    // 读通道完成确认 (来自寄存器接口)
  reg      [ADDR_W-1:0] rch_addr;   // 读地址锁存
  wire     [DATA_W-1:0] rch_dout;   // 读数据输入
  reg                   reg_ack;    // 寄存器操作完成的单周期确认信号

  // 状态机状态变量
  reg             [2:0] wch_state;
  reg             [1:0] rch_state;

   // --- 根据时钟模式选择不同的实现 ---
  generate if (CLOCKING_MODE == "common_clock") begin
    assign awvalid        = s_axil_awvalid;
    assign awaddr         = s_axil_awaddr;
    assign s_axil_awready = awready;
    assign wvalid         = s_axil_wvalid;
    assign wdata          = s_axil_wdata;
    assign s_axil_wready  = wready;
    assign s_axil_bvalid  = bvalid;
    assign s_axil_bresp   = bresp;
    assign bready         = s_axil_bready;
    assign arvalid        = s_axil_arvalid;
    assign araddr         = s_axil_araddr;
    assign s_axil_arready = arready;
    assign s_axil_rvalid  = rvalid;
    assign s_axil_rdata   = rdata;
    assign s_axil_rresp   = rresp;
    assign rready         = s_axil_rready;
  end
  else if (CLOCKING_MODE == "independent_clock") begin
    // **异步模式**: AXI接口和寄存器接口使用不同的时钟。
    // 例化一个AXI-Lite时钟转换器来安全地桥接两个时钟域。
    axi_lite_clock_converter clk_conv_inst (
      // 从接口 (连接到外部AXI主设备, 运行在 axil_aclk)
      .s_axi_awaddr  (s_axil_awaddr),
      .s_axi_awprot  (0),
      .s_axi_awvalid (s_axil_awvalid),
      .s_axi_awready (s_axil_awready),
      .s_axi_wdata   (s_axil_wdata),
      .s_axi_wstrb   (4'hF),
      .s_axi_wvalid  (s_axil_wvalid),
      .s_axi_wready  (s_axil_wready),
      .s_axi_bvalid  (s_axil_bvalid),
      .s_axi_bresp   (s_axil_bresp),
      .s_axi_bready  (s_axil_bready),
      .s_axi_araddr  (s_axil_araddr),
      .s_axi_arprot  (0),
      .s_axi_arvalid (s_axil_arvalid),
      .s_axi_arready (s_axil_arready),
      .s_axi_rdata   (s_axil_rdata),
      .s_axi_rresp   (s_axil_rresp),
      .s_axi_rvalid  (s_axil_rvalid),
      .s_axi_rready  (s_axil_rready),
      // 主接口 (连接到本模块的内部逻辑, 运行在 reg_clk)
      .m_axi_awaddr  (awaddr),
      .m_axi_awprot  (),
      .m_axi_awvalid (awvalid),
      .m_axi_awready (awready),
      .m_axi_wdata   (wdata),
      .m_axi_wstrb   (),
      .m_axi_wvalid  (wvalid),
      .m_axi_wready  (wready),
      .m_axi_bvalid  (bvalid),
      .m_axi_bresp   (bresp),
      .m_axi_bready  (bready),
      .m_axi_araddr  (araddr),
      .m_axi_arprot  (),
      .m_axi_arvalid (arvalid),
      .m_axi_arready (arready),
      .m_axi_rdata   (rdata),
      .m_axi_rresp   (rresp),
      .m_axi_rvalid  (rvalid),
      .m_axi_rready  (rready),
      // 时钟和复位
      .s_axi_aclk    (axil_aclk),
      .s_axi_aresetn (axil_aresetn),
      .m_axi_aclk    (reg_clk),
      .m_axi_aresetn (reg_rstn)
    );
  end
  else begin
    // 如果设置了不支持的时钟模式, 则在编译时报错。
    initial begin
      $fatal("[%m] Unsupported clocking mode %s", CLOCKING_MODE);
    end
  end
  endgenerate

   // --- 寄存器接口握手逻辑 ---
  // 生成一个单周期确认脉冲 reg_ack。
  // 当寄存器访问使能 reg_en 拉高一拍后, reg_ack 会在下一拍拉高。
  // 状态机等待这个 ack 信号来确认寄存器操作已完成。（第一拍使能操作，开始操作，下一拍操作完成）
  always @(posedge reg_clk) begin
    if (~reg_rstn) begin
      reg_ack <= 1'b0;
    end
    else begin
      reg_ack <= reg_en; // 延迟一拍
    end
  end

  // --- 合并读写请求到简单的寄存器接口 ---
  //
  // 如果读和写请求同时发生, 写请求拥有更高优先级, 读请求将被忽略。
  // 这种情况下, 读通道会返回无效或过时的数据。
  assign reg_en   = rch_en || wch_en;               // 只要有读或写请求, 就使能寄存器访问
  assign reg_we   = wch_en;                         // 只有写请求时, 才拉高写使能
  assign reg_addr = (wch_state != S_AXIL_WCH_IDLE) ? wch_addr : rch_addr; // 优先选择写地址
  assign reg_din  = wch_din;                        // 输出锁存的写数据
  assign rch_ack  = reg_ack;                        // 将单周期的 ack 信号反馈给读写状态机
  assign wch_ack  = reg_ack;
  assign rch_dout = reg_dout;                      // 将从寄存器读出的数据送往读通道

   // --- 写事务状态机 ---
  always @(posedge reg_clk) begin
    if (~reg_rstn) begin
      // 复位状态: 准备好接收, 不发送响应
      awready   <= 1'b1;
      wready    <= 1'b1;
      bvalid    <= 1'b0;
      bresp     <= 0;
      wch_en    <= 1'b0;
      wch_addr  <= 0;
      wch_din   <= 0;
      wch_state <= S_AXIL_WCH_IDLE;
    end
    else begin
      case (wch_state)

        S_AXIL_WCH_IDLE: begin
          // 空闲状态, 等待写请求
          if (awvalid && wvalid) begin // 地址和数据同时到达
            awready   <= 1'b0;         // 锁定地址通道
            wch_addr  <= awaddr;       // 锁存地址
            wready    <= 1'b0;         // 锁定数据通道
            wch_en    <= 1'b1;         // 使能寄存器写
            wch_din   <= wdata;        // 锁存数据
            wch_state <= S_AXIL_WCH_B; // 跳转到发送响应状态
          end
          else if (awvalid && ~wvalid) begin // 地址先到
            awready   <= 1'b0;
            wch_addr  <= awaddr;
            wch_state <= S_AXIL_WCH_W; // 跳转到等待数据状态
          end
          else if (wvalid && ~awvalid) begin // 数据先到
            wready    <= 1'b0;
            wch_din   <= wdata;
            wch_state <= S_AXIL_WCH_AW; // 跳转到等待地址状态
          end
        end

        S_AXIL_WCH_W: begin
          // 等待写数据状态 (已收到地址)
          if (wvalid) begin
            wready    <= 1'b0;
            wch_en    <= 1'b1;
            wch_din   <= wdata;
            wch_state <= S_AXIL_WCH_B;
          end
        end

        S_AXIL_WCH_AW: begin
          // 等待写地址状态 (已收到数据)
          if (awvalid) begin
            awready   <= 1'b0;
            wch_en    <= 1'b1;
            wch_addr  <= awaddr;
            wch_state <= S_AXIL_WCH_B;
          end
        end

        S_AXIL_WCH_B: begin
          // 寄存器写已发出 (wch_en为低), 等待内部确认
          wch_en <= 1'b0;
          if (wch_ack) begin // 收到寄存器写完成确认
            bvalid    <= 1'b1; // 拉高响应有效
            bresp     <= 0;   // 设置响应为 OKAY
            wch_state <= S_AXIL_WCH_RET; // 跳转到等待主机接收响应状态
          end
        end

        S_AXIL_WCH_RET: begin
          // 等待主机接收响应
          if (bready) begin // 主机已准备好接收
            awready   <= 1'b1; // 释放地址和数据通道
            wready    <= 1'b1;
            bvalid    <= 1'b0; // 拉低响应有效, 完成握手
            wch_state <= S_AXIL_WCH_IDLE; // 回到空闲状态
          end
        end

        default: begin
          // 异常状态, 强制复位
          wch_state <= S_AXIL_WCH_IDLE;
        end
      endcase
    end
  end

  // --- 读事务状态机 ---
  always @(posedge reg_clk) begin
    if (~reg_rstn) begin
      // 复位状态: 准备好接收地址, 不发送数据
      arready   <= 1'b1;
      rvalid    <= 1'b0;
      rdata     <= 0;
      rresp     <= 0;
      rch_en    <= 1'b0;
      rch_addr  <= 0;
      rch_state <= S_AXIL_RCH_IDLE;
    end
    else begin
      case (rch_state)

        S_AXIL_RCH_IDLE: begin
          // 空闲状态, 等待读地址请求
          if (arvalid) begin
            arready   <= 1'b0;         // 锁定地址通道
            rch_en    <= 1'b1;         // 使能寄存器读
            rch_addr  <= araddr;       // 锁存读地址
            rch_state <= S_AXIL_RCH_RD; // 跳转到等待读完成状态
          end
        end

        S_AXIL_RCH_RD: begin
          // 寄存器读已发出 (rch_en为低), 等待内部确认和数据
          rch_en <= 1'b0;
          if (rch_ack) begin // 收到寄存器读完成确认
            rvalid    <= 1'b1;         // 拉高读数据有效
            rdata     <= rch_dout;     // 输出从寄存器读到的数据
            rresp     <= 0;           // 设置响应为 OKAY
            rch_state <= S_AXIL_RCH_RET; // 跳转到等待主机接收数据状态
          end
        end

        S_AXIL_RCH_RET: begin
          // 等待主机接收数据
          if (rready) begin // 主机已准备好接收
            arready   <= 1'b1; // 释放地址通道
            rvalid    <= 1'b0; // 拉低数据有效, 完成握手
            rdata     <= 0;
            rresp     <= 0;
            rch_state <= S_AXIL_RCH_IDLE; // 回到空闲状态
          end
        end

        default: begin
          // 异常状态, 强制复位
          rch_state <= S_AXIL_RCH_IDLE;
        end

      endcase
    end
  end


endmodule: axi_lite_register
