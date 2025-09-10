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
// A placeholder block for AXI-Lite register access
//
// This block serves as a sink for unused AXI-Lite interface.  On write, it
// completes the transaction immediately without writing into any real register.
// On read, it returns the read address (lower 16-bit) and a user-define prefix
// (upper 16-bit).
// *************************************************************************
// A placeholder block for AXI-Lite register access
// 一个用于AXI-Lite寄存器访问的占位符模块。
//
// This block serves as a sink for unused AXI-Lite interface.  On write, it
// completes the transaction immediately without writing into any real register.
// On read, it returns the read address (lower 16-bit) and a user-define prefix
// (upper 16-bit).
// 这个模块作为一个未使用的AXI-Lite接口的“接收器”(Sink)或“黑洞”。
// 对于写操作，它会立即完成事务，但不会写入任何真实的寄存器。
// 对于读操作，它会返回一个由用户定义的前缀(高16位)和读取的地址(低16位)组成的值。
`timescale 1ns/1ps
module axi_lite_slave #(
  // 参数: 寄存器地址位宽，用于匹配上游主设备的地址宽度
  parameter int REG_ADDR_W = 12,
  // 参数: 读取时返回的数据的高16位前缀，可用于调试
  parameter int REG_PREFIX = 0
)(
   // --- AXI4-Lite 从接口 ---
  // 这是模块的唯一接口，用于连接到一个AXI主设备
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
  // --- 全局时钟与复位 ---
  input         aclk,
  input         aresetn
);

   // --- 内部信号定义 ---
  // 定义连接到axi_lite_register模块的简单寄存器接口信号
  wire               reg_en;   // 寄存器访问使能
  wire               reg_we;   // 寄存器写使能
  wire [REG_ADDR_W-1:0] reg_addr; // 寄存器地址
  wire       [31:0]  reg_din;  // 写入的数据 (在此模块中被忽略)
  reg        [31:0]  reg_dout; // 准备返回的读取数据

  // --- 例化AXI-Lite到寄存器风格接口的转换模块 ---
  // 复用了我们之前分析过的axi_lite_register模块来处理所有AXI握手逻辑。
  // 这是一个非常好的模块化设计实践。
  axi_lite_register #(
    .CLOCKING_MODE ("common_clock"),
    .ADDR_W        (REG_ADDR_W),
    .DATA_W        (32)
  ) axil_reg_inst (
    .s_axil_awvalid (s_axil_awvalid),
    .s_axil_awaddr  (s_axil_awaddr[REG_ADDR_W-1:0]),
    .s_axil_awready (s_axil_awready),
    .s_axil_wvalid  (s_axil_wvalid),
    .s_axil_wdata   (s_axil_wdata),
    .s_axil_wready  (s_axil_wready),
    .s_axil_bvalid  (s_axil_bvalid),
    .s_axil_bresp   (s_axil_bresp),
    .s_axil_bready  (s_axil_bready),
    .s_axil_arvalid (s_axil_arvalid),
    .s_axil_araddr  (s_axil_araddr[REG_ADDR_W-1:0]),
    .s_axil_arready (s_axil_arready),
    .s_axil_rvalid  (s_axil_rvalid),
    .s_axil_rdata   (s_axil_rdata),
    .s_axil_rresp   (s_axil_rresp),
    .s_axil_rready  (s_axil_rready),

    .reg_en         (reg_en),
    .reg_we         (reg_we),
    .reg_addr       (reg_addr),
    .reg_din        (reg_din),
    .reg_dout       (reg_dout),

    .axil_aclk      (aclk),
    .axil_aresetn   (aresetn),
    .reg_clk        (aclk),
    .reg_rstn       (aresetn)
  );

  // --- 读数据生成逻辑 ---
  // 这是本模块唯一的 "功能" 逻辑。
  always @(posedge aclk) begin
    if (~aresetn) begin
      reg_dout <= 0;
    end
    // 当有一个读请求时 (reg_en=1, reg_we=0)
    else if (reg_en && ~reg_we) begin
      // 将返回数据的高16位设置为参数化的前缀
      reg_dout[31:16] <= REG_PREFIX;
      // 将返回数据的低16位设置为本次读取的地址
      // 这是一个有用的调试特性，可以让软件知道它实际访问的地址是什么。
      reg_dout[15:0]  <= reg_addr;
    end
  end

endmodule: axi_lite_slave
