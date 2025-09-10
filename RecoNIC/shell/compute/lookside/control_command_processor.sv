//==============================================================================
// Copyright (C) 2023, Advanced Micro Devices, Inc. All rights reserved.
// SPDX-License-Identifier: MIT
//
//==============================================================================
`timescale 1ns/1ps

// 这个模块是主机CPU与FPGA计算逻辑之间的“前门”和“交通枢纽”。
// 它负责处理所有来自主机的控制命令，并将计算结果状态返回给主机。
module control_command_processor #(
  parameter AXIL_ADDR_WIDTH  = 12,
  parameter AXIL_DATA_WIDTH  = 32
) (
  // register control interface
  // --- AXI-Lite 从机接口 ---
  // 这是直接暴露给主机的MMIO接口。C代码中的read/write32_data函数最终操作的就是这个接口。
  input                              s_axil_awvalid,
  input        [AXIL_ADDR_WIDTH-1:0] s_axil_awaddr,
  output logic                       s_axil_awready,
  input                              s_axil_wvalid,
  input        [AXIL_DATA_WIDTH-1:0] s_axil_wdata,
  output logic                       s_axil_wready,
  output logic                       s_axil_bvalid,
  output logic                 [1:0] s_axil_bresp,
  input                              s_axil_bready,
  input                              s_axil_arvalid,
  input        [AXIL_ADDR_WIDTH-1:0] s_axil_araddr,
  output logic                       s_axil_arready,
  output logic                       s_axil_rvalid,
  output logic [AXIL_DATA_WIDTH-1:0] s_axil_rdata,
  output logic                 [1:0] s_axil_rresp,
  input                              s_axil_rready,

  // --- 与下游模块的控制信号 ---
  input        cl_box_idle,      // cl_box(命令解析器)是否空闲
  output logic cl_box_start,     // 启动cl_box开始解析
  input        cl_box_done,      // cl_box是否完成解析
  input        cl_kernel_idle,   // mmult(计算核心)是否空闲
  input        cl_kernel_done,   // mmult是否完成计算

  // --- 命令FIFO的输出接口 ---
  // 连接到cl_box模块，为其提供指令流
  output [31:0] ctl_cmd_fifo_dout,    // 从FIFO读出的数据
  output        ctl_cmd_fifo_empty_n, // FIFO非空标志
  input         ctl_cmd_fifo_rd_en,   // FIFO读使能 (由cl_box控制)

  // --- 状态FIFO的输入接口 ---
  // 连接到mmult核心，接收完成状态
  input  [31:0] ker_status_fifo_din,  // 要写入FIFO的数据 (work_id)
  input         ker_status_fifo_wr_en,// FIFO写使能 (由mmult控制)
  output        ker_status_fifo_full_n, // FIFO非满标志

  // --- 时钟和复位 ---
  input axil_aclk,  // AXI-Lite时钟 (主机/PCIe时钟域)
  input axil_arstn,
  input axis_aclk,  // AXI-Stream时钟 (FPGA内部计算时钟域)
  input axis_arstn
);

// 计算整数log2的函数，用于确定FIFO计数器的位宽
function integer log2;
  input integer val;
  begin
    log2 = 0;
    while (2**log2 < val) begin
      log2 = log2 + 1;
    end
  end
endfunction

localparam DEFAULT_VALUE = 32'hdeadbeef;

// For testing purpose
localparam TEMPLATE_REG = 12'd512;
logic [AXIL_DATA_WIDTH-1:0] template_reg;

// --- 寄存器地址映射 ---
// 这定义了主机CPU可以通过MMIO访问的地址。与C代码中的操作完全对应。
localparam CTL_CMD                  = 12'h000; // 命令FIFO的写入地址
localparam KER_STS                  = 12'h004; // 状态FIFO的读取地址
localparam JOB_SUBMITTED            = 12'h008; // (状态)已提交任务计数器地址
localparam JOB_COMPLETED_NOT_READ = 12'h00C; // (状态)已完成但未被主机读取的任务计数器地址

// --- 内部状态和计数器 ---
logic [31:0] job_submitted_cnt;
logic [31:0] job_completed_not_read_cnt;

/* AXI-Lite write interface */
// AXI写逻辑，状态机
localparam AXIL_WRITE_IDLE   = 2'b00;
localparam AXIL_WRITE_WREADY = 2'b01;
localparam AXIL_WRITE_RESP   = 2'b11;
localparam AXIL_WRITE_WAIT   = 2'b10;
logic [1:0] axil_write_state;
logic [AXIL_ADDR_WIDTH-1:0] awaddr; // 锁存的写地址

/* AXI-Lite read interface */
// AXI读逻辑，状态机
localparam AXIL_READ_IDLE = 2'b01;
localparam AXIL_READ_RESP = 2'b10;
logic [1:0] axil_read_state;
logic [AXIL_ADDR_WIDTH-1:0] araddr; // 锁存的读地址

// --- 异步FIFO定义 ---
// 异步(async)是这里的关键，因为它连接了两个不同的时钟域。
localparam ASYNC_FIFO_DEPTH = 2048; // FIFO深度
localparam WR_DATA_COUNT_WIDTH = log2(ASYNC_FIFO_DEPTH) + 1;  // 用于确定FIFO计数器的位宽

// --- 命令FIFO (ctl_cmd_afifo) 信号线 ---
// CPU(axil_aclk) -> FIFO -> 计算逻辑(axis_aclk)
logic ctl_cmd_wr_en;        // FIFO写使能
logic ctl_cmd_afifo_full;   // FIFO满标志
logic [31:0] ctl_cmd_data;  // 待写入FIFO的数据

logic ctl_cmd_rd_en;
logic ctl_cmd_afifo_empty;
logic [31:0] ctl_cmd_afifo_data_out;

logic [WR_DATA_COUNT_WIDTH-1:0] ctl_cmd_afifo_wr_data_count;

logic ctl_cmd_wr_rst_busy;

/* Async FIFO to buffer kernel status */
// --- 状态FIFO (ker_status_afifo) 信号线 ---
// 计算逻辑(axis_aclk) -> FIFO -> CPU(axil_aclk)
localparam RD_DATA_COUNT_WIDTH = log2(ASYNC_FIFO_DEPTH) + 1; // 用于确定FIFO计数器的位宽
logic ker_status_wr_en;       // FIFO写使能
logic ker_status_afifo_full;  // FIFO满标志
logic [31:0] ker_status_data;

logic ker_status_rd_en;
logic ker_status_afifo_empty;
logic [31:0] ker_status_afifo_data_out;

logic [RD_DATA_COUNT_WIDTH-1:0] ker_status_afifo_rd_data_count;

logic ker_status_wr_rst_busy;

// 内核调度状态机
localparam CL_IDLE          = 2'b00; // 空闲
localparam CL_BOX_ACTIVE    = 2'b01; // 命令解析器工作
localparam CL_KERNEL_ACTIVE = 2'b11; // 计算核心工作

logic [1:0] kernel_state;
logic [1:0] kernel_nextstate;

// AXI-Lite write transaction
// --- AXI-Lite 写处理逻辑 ---
// 这个always块实现了一个标准的AXI-Lite从机写状态机
always_ff @(posedge axil_aclk)
begin
  if(~axil_arstn)
  begin
    s_axil_awready <= 1'b1;
    s_axil_wready  <= 1'b0;
    s_axil_bvalid  <= 1'b0;
    s_axil_bresp   <= 2'd0;
    awaddr         <= 0;

    template_reg   <= 0;

    ctl_cmd_data   <= 0;
    ctl_cmd_wr_en  <= 0;

    axil_write_state <= AXIL_WRITE_IDLE;
  end
  else begin
    ctl_cmd_wr_en  <= 0;
    case(axil_write_state)
      AXIL_WRITE_IDLE: begin
        s_axil_bvalid  <= 1'b0;
        if(s_axil_awvalid && s_axil_awready)
        begin
          s_axil_wready  <= 1'b1;
          s_axil_awready <= 1'b0;
          awaddr         <= s_axil_awaddr;
          if(s_axil_wvalid)
          begin
            axil_write_state <= AXIL_WRITE_RESP;
            case(s_axil_awaddr)
              CTL_CMD     : begin
                ctl_cmd_data <= s_axil_wdata;
                if(ctl_cmd_afifo_full || ctl_cmd_wr_rst_busy) begin
                  ctl_cmd_wr_en  <= 1'b0;
                  axil_write_state <= AXIL_WRITE_WAIT;
                end
                else begin
                  ctl_cmd_wr_en <= 1'b1;
                end
                if(s_axil_wready)
                begin
                  s_axil_wready <= 1'b0;
                end
              end
              TEMPLATE_REG: begin
                template_reg <= s_axil_wdata;
              end
              default: begin
                template_reg <= template_reg;
              end
            endcase
          end
          else begin
            axil_write_state <= AXIL_WRITE_WREADY;
          end
        end
        else begin
          s_axil_wready <= s_axil_wready;
        end
      end
      AXIL_WRITE_WREADY: begin
        if(s_axil_wvalid)
        begin
          axil_write_state <= AXIL_WRITE_RESP;
          if(s_axil_wready)
          begin
            s_axil_wready <= 1'b0;
          end
          case(awaddr)
            CTL_CMD     : begin
              ctl_cmd_data <= s_axil_wdata;
              if(ctl_cmd_afifo_full) begin
                ctl_cmd_wr_en  <= 1'b0;
                axil_write_state <= AXIL_WRITE_WAIT;
              end
              else begin
                ctl_cmd_wr_en <= 1'b1;
              end
            end
            TEMPLATE_REG   : template_reg <= s_axil_wdata;
            default: begin
              template_reg <= template_reg;
            end
          endcase    
        end
      end
      AXIL_WRITE_WAIT: begin
        if(!ctl_cmd_afifo_full && !ctl_cmd_wr_rst_busy) begin
          s_axil_bresp  <= 0;
          ctl_cmd_wr_en <= 1'b1;
          s_axil_bvalid <= 1'b1;
          axil_write_state <= AXIL_WRITE_RESP;
        end
      end
      AXIL_WRITE_RESP: begin
        s_axil_bresp   <= 0;
        s_axil_bvalid  <= 1'b1;
        awaddr         <= 0;
        s_axil_awready <= 1'b1;
        s_axil_wready  <= 1'b0;
        ctl_cmd_wr_en  <= 1'b0;
        axil_write_state <= s_axil_bready ? AXIL_WRITE_IDLE : AXIL_WRITE_RESP;
      end
      default: begin
        s_axil_awready <= 1'b1;
        s_axil_wready  <= 1'b0;
        s_axil_bvalid  <= 1'b0;
        s_axil_bresp   <= 2'd0;
        awaddr         <= 0;     
        axil_write_state <= AXIL_WRITE_IDLE;
      end
    endcase
  end
end

// Async FIFO to buffer control commands
xpm_fifo_async #(
  .DOUT_RESET_VALUE    ("0"),
  .ECC_MODE            ("no_ecc"),
  .FIFO_MEMORY_TYPE    ("auto"),
  .FIFO_READ_LATENCY   (0),
  .FIFO_WRITE_DEPTH    (ASYNC_FIFO_DEPTH),
  .READ_DATA_WIDTH     (32),
  .RD_DATA_COUNT_WIDTH (),
  .WR_DATA_COUNT_WIDTH (WR_DATA_COUNT_WIDTH),
  .READ_MODE           ("fwft"),
  .WRITE_DATA_WIDTH    (32),
  .CDC_SYNC_STAGES     (2)
) ctl_cmd_afifo (
  .wr_en         (ctl_cmd_wr_en),
  .din           (ctl_cmd_data),
  .wr_ack        (),
  .rd_en         (ctl_cmd_rd_en),
  .data_valid    (),
  .dout          (ctl_cmd_afifo_data_out),

  .wr_data_count (ctl_cmd_afifo_wr_data_count),
  .rd_data_count (),

  .empty         (ctl_cmd_afifo_empty),
  .full          (ctl_cmd_afifo_full),
  .almost_empty  (),
  .almost_full   (),
  .overflow      (),
  .underflow     (),
  .prog_empty    (),
  .prog_full     (),
  .sleep         (1'b0),

  .sbiterr       (),
  .dbiterr       (),
  .injectsbiterr (1'b0),
  .injectdbiterr (1'b0),

  .wr_clk        (axil_aclk),
  .rd_clk        (axis_aclk),
  .rst           (~axis_arstn),
  .rd_rst_busy   (),
  .wr_rst_busy   (ctl_cmd_wr_rst_busy)
);

assign ctl_cmd_rd_en        = ctl_cmd_fifo_rd_en;
assign ctl_cmd_fifo_dout    = ctl_cmd_afifo_data_out;
assign ctl_cmd_fifo_empty_n = ~ctl_cmd_afifo_empty;

// AXI-Lite read transaction
always_ff @(posedge axil_aclk)
begin
  if(~axil_arstn)
  begin
    s_axil_arready   <= 1'b1;
    s_axil_rvalid    <= 1'b0;
    s_axil_rdata     <= 0;
    s_axil_rresp     <= 0;
    araddr           <= 0;
    ker_status_rd_en <= 1'b0;
    axil_read_state <= AXIL_READ_IDLE;
  end
  else begin
    ker_status_rd_en <= 1'b0;
    case(axil_read_state)
      AXIL_READ_IDLE: begin
        if(s_axil_arready && s_axil_arvalid)
        begin
          s_axil_arready <= 1'b0;
          s_axil_rvalid  <= 1'b1;
          s_axil_rresp   <= 0;
          araddr             <= s_axil_araddr;
          case(s_axil_araddr)
            KER_STS               : begin
              s_axil_rdata <= !ker_status_afifo_empty ? ker_status_afifo_data_out : DEFAULT_VALUE;
              ker_status_rd_en <= !ker_status_afifo_empty ? 1'b1 : 1'b0;
            end
            JOB_SUBMITTED         : s_axil_rdata <= job_submitted_cnt;
            JOB_COMPLETED_NOT_READ: s_axil_rdata <= job_completed_not_read_cnt;
            TEMPLATE_REG          : s_axil_rdata <= template_reg;
            default               : s_axil_rdata <= DEFAULT_VALUE;
          endcase
          axil_read_state <= AXIL_READ_RESP;
        end
      end
      AXIL_READ_RESP: begin
        if(s_axil_rready && s_axil_rvalid)
        begin
          s_axil_rvalid  <= 1'b0;
          s_axil_arready <= 1'b1;
          axil_read_state    <= AXIL_READ_IDLE;
        end
      end
      default: begin
        s_axil_arready <= 1'b1;
        s_axil_rvalid  <= 1'b0;
        s_axil_rdata   <= 0;
        s_axil_rresp   <= 0;
        axil_read_state <= AXIL_READ_IDLE;        
      end
    endcase
  end
end

assign job_submitted_cnt          = ctl_cmd_afifo_wr_data_count;
assign job_completed_not_read_cnt = ker_status_afifo_rd_data_count;

// Async FIFO to buffer kernel status
xpm_fifo_async #(
  .DOUT_RESET_VALUE    ("0"),
  .ECC_MODE            ("no_ecc"),
  .FIFO_MEMORY_TYPE    ("auto"),
  .FIFO_READ_LATENCY   (0),
  .FIFO_WRITE_DEPTH    (ASYNC_FIFO_DEPTH),
  .READ_DATA_WIDTH     (32),
  .RD_DATA_COUNT_WIDTH (RD_DATA_COUNT_WIDTH),
  .READ_MODE           ("fwft"),
  .WRITE_DATA_WIDTH    (32),
  .CDC_SYNC_STAGES     (2)
) ker_status_afifo (
  .wr_en         (ker_status_wr_en),
  .din           (ker_status_data),
  .wr_ack        (),
  .rd_en         (ker_status_rd_en),
  .data_valid    (),
  .dout          (ker_status_afifo_data_out),

  .wr_data_count (),
  .rd_data_count (ker_status_afifo_rd_data_count),

  .empty         (ker_status_afifo_empty),
  .full          (ker_status_afifo_full),
  .almost_empty  (),
  .almost_full   (),
  .overflow      (),
  .underflow     (),
  .prog_empty    (),
  .prog_full     (),
  .sleep         (1'b0),

  .sbiterr       (),
  .dbiterr       (),
  .injectsbiterr (1'b0),
  .injectdbiterr (1'b0),

  .wr_clk        (axis_aclk),
  .rd_clk        (axil_aclk),
  .rst           (~axil_arstn),
  .rd_rst_busy   (),
  .wr_rst_busy   (ker_status_wr_rst_busy)
);

assign ker_status_fifo_full_n = (!ker_status_afifo_full) && (!ker_status_wr_rst_busy);
assign ker_status_data        = ker_status_fifo_din;
assign ker_status_wr_en       = ker_status_fifo_wr_en;

always_ff @(posedge axis_aclk)
begin
  if(!axis_arstn) begin
    kernel_state <= CL_IDLE;

    cl_box_start <= 1'b0;
  end
  else begin
    cl_box_start <= 1'b0;
    case(kernel_state)
      CL_IDLE: begin
        if(cl_box_idle && cl_kernel_idle && !ctl_cmd_afifo_empty) begin
          cl_box_start <= 1'b1;
          kernel_state <= CL_BOX_ACTIVE;
        end
      end
      CL_BOX_ACTIVE: begin
        cl_box_start <= 1'b1;
        if(cl_box_done && !cl_kernel_done) begin
          cl_box_start <= 1'b0;
          kernel_state <= CL_KERNEL_ACTIVE;
        end

        if(cl_box_done && cl_kernel_done) begin
          cl_box_start <= 1'b0;
          kernel_state <= CL_IDLE;
        end
      end
      CL_KERNEL_ACTIVE: begin
        if(cl_kernel_done) begin
          kernel_state <= CL_IDLE;
        end
      end
      default: kernel_state <= CL_IDLE;
    endcase
  end
end

endmodule: control_command_processor