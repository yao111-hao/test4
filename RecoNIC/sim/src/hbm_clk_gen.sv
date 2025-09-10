//==============================================================================
// Copyright (C) 2023, Advanced Micro Devices, Inc. All rights reserved.
// SPDX-License-Identifier: MIT
//
// HBM时钟生成器 - 为HBM系统提供100MHz差分时钟
//==============================================================================
`timescale 1ns/1ps

module hbm_clk_gen (
    output logic hbm_clk_p,
    output logic hbm_clk_n,
    output logic hbm_clk_locked
);

// 100MHz时钟生成 (10ns周期)
logic hbm_clk_int;
initial begin
    hbm_clk_int = 0;
    forever #5 hbm_clk_int = ~hbm_clk_int; // 100MHz
end

// 生成差分时钟对
assign hbm_clk_p = hbm_clk_int;
assign hbm_clk_n = ~hbm_clk_int;

// 锁定信号 - 在复位解除后延时一段时间
logic [7:0] lock_counter = 0;
initial begin
    hbm_clk_locked = 0;
    #100; // 等待100ns
    hbm_clk_locked = 1;
end

endmodule
