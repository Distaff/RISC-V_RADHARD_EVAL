`timescale 1ns / 1ps
`default_nettype none
/*****************************************************************************
 *  Author: Piotr Kadziela (AI Generated)
 *  Description:
 *      Integration testbench for axil_xbar with two memories behind
 *      memory_adapter_axil, wired like the data and instruction memories
 *      in toplevel.
 *      The instruction memory is writable only while debug owns the bus.
 *****************************************************************************/

`include "tb_utils.svh"

module mem_bus_tb;

import axil_pkg::*;

`TB_VARS
`TB_TIMEOUT(50000)

localparam WAIT_CYCLES = 32;
localparam MEM_WORDS   = 256;               // 1 KB each

localparam DMEM_BASE   = 32'h0000_0000;
localparam IMEM_BASE   = 32'h4000_0000;
localparam MEM_MASK    = 32'hFFFF_FC00;

logic clk;
logic rst_n;
logic dbg_override_sel;

axil_if core_axi (.clk(clk), .rst_n(rst_n));
axil_if dbg_axi (.clk(clk), .rst_n(rst_n));
axil_if slv_axi [2] (.clk(clk), .rst_n(rst_n));

axil_xbar #(
    .NUM_SLV(2),
    .SLV_BASE({IMEM_BASE, DMEM_BASE}),
    .SLV_MASK({MEM_MASK, MEM_MASK})
) xbar1 (
    .clk(clk),
    .rst_n(rst_n),
    .dbg_override_sel(dbg_override_sel),
    .core_axi(core_axi),
    .dbg_axi(dbg_axi),
    .slv_axi(slv_axi)
);

// DATA MEMORY

logic           dmem_en;
logic [31:0]    dmem_addr, dmem_rdata, dmem_wdata;
logic  [3:0]    dmem_wstrb;

memory_adapter_axil dmem_axi (
    .clk(clk),
    .rst_n(rst_n),
    .write_lock(1'b0),
    .axi(slv_axi[0]),
    .mem_en(dmem_en),
    .mem_addr(dmem_addr),
    .mem_rdata(dmem_rdata),
    .mem_wdata(dmem_wdata),
    .mem_wstrb(dmem_wstrb)
);

memory #(.MEMORY_SIZE_WORDS(MEM_WORDS)) dmem (
    .clk(clk),
    .a_en(1'b0),
    .a_addr(32'd0),
    .a_data(),
    .b_en(dmem_en),
    .b_addr(dmem_addr),
    .b_data(dmem_rdata),
    .b_wdata(dmem_wdata),
    .b_wstrb(dmem_wstrb)
);

// INSTRUCTION MEMORY

logic           imem_en;
logic [31:0]    imem_addr, imem_rdata, imem_wdata;
logic  [3:0]    imem_wstrb;

memory_adapter_axil imem_axi (
    .clk(clk),
    .rst_n(rst_n),
    .write_lock(!dbg_override_sel),
    .axi(slv_axi[1]),
    .mem_en(imem_en),
    .mem_addr(imem_addr),
    .mem_rdata(imem_rdata),
    .mem_wdata(imem_wdata),
    .mem_wstrb(imem_wstrb)
);

memory #(.MEMORY_SIZE_WORDS(MEM_WORDS)) imem (
    .clk(clk),
    .a_en(1'b0),
    .a_addr(32'd0),
    .a_data(),
    .b_en(imem_en),
    .b_addr(imem_addr),
    .b_data(imem_rdata),
    .b_wdata(imem_wdata),
    .b_wstrb(imem_wstrb)
);

initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
end

// Signals are driven and sampled on the falling edge, so a ready seen there
// is the one the next rising edge acts on.
task automatic axi_write(
    virtual axil_if     m,
    input  logic [31:0] addr,
    input  logic [31:0] data,
    input  logic  [3:0] strb,
    output logic  [1:0] resp
);
    int  n = 0;
    bit  aw_hs, w_hs;

    @(negedge clk);
    m.awaddr  = addr;
    m.awvalid = 1'b1;
    m.wdata   = data;
    m.wstrb   = strb;
    m.wvalid  = 1'b1;
    m.bready  = 1'b1;

    while ((m.awvalid || m.wvalid) && n < WAIT_CYCLES) begin
        aw_hs = m.awvalid && m.awready;
        w_hs  = m.wvalid && m.wready;
        @(negedge clk);
        if (aw_hs) m.awvalid = 1'b0;
        if (w_hs)  m.wvalid  = 1'b0;
        n++;
    end

    while (m.bvalid !== 1'b1 && n < WAIT_CYCLES) begin
        @(negedge clk);
        n++;
    end
    resp = m.bvalid ? m.bresp : 2'bxx;

    @(negedge clk);
    m.bready = 1'b0;
endtask

task automatic axi_read(
    virtual axil_if     m,
    input  logic [31:0] addr,
    output logic [31:0] data,
    output logic  [1:0] resp
);
    int n = 0;

    @(negedge clk);
    m.araddr  = addr;
    m.arvalid = 1'b1;
    m.rready  = 1'b1;

    while (m.arready !== 1'b1 && n < WAIT_CYCLES) begin
        @(negedge clk);
        n++;
    end
    @(negedge clk);
    m.arvalid = 1'b0;

    while (m.rvalid !== 1'b1 && n < WAIT_CYCLES) begin
        @(negedge clk);
        n++;
    end
    data = m.rvalid ? m.rdata : 32'hxxxx_xxxx;
    resp = m.rvalid ? m.rresp : 2'bxx;

    @(negedge clk);
    m.rready = 1'b0;
endtask

task automatic idle(virtual axil_if m);
    m.awvalid = 1'b0;
    m.wvalid  = 1'b0;
    m.bready  = 1'b0;
    m.arvalid = 1'b0;
    m.rready  = 1'b0;
    m.awaddr  = 32'd0;
    m.araddr  = 32'd0;
    m.wdata   = 32'd0;
    m.wstrb   = 4'd0;
endtask

logic [31:0] data;
logic  [1:0] resp;

initial begin
    rst_n            = 1'b0;
    dbg_override_sel = 1'b0;
    idle(core_axi);
    idle(dbg_axi);

    repeat (4) @(negedge clk);
    rst_n = 1'b1;
    repeat (2) @(negedge clk);

    // Data memory: two words must not alias, a byte strobe touches one lane
    axi_write(core_axi, 32'h0000_0010, 32'hDEAD_BEEF, 4'b1111, resp);
    `CHECK_EQ(resp, RESP_OKAY, "dmem write")
    axi_write(core_axi, 32'h0000_0014, 32'hCAFE_F00D, 4'b1111, resp);
    axi_write(core_axi, 32'h0000_0010, 32'h0000_5500, 4'b0010, resp);
    `CHECK_EQ(resp, RESP_OKAY, "dmem byte write")

    axi_read(core_axi, 32'h0000_0010, data, resp);
    `CHECK_EQ(resp, RESP_OKAY, "dmem read")
    `CHECK_EQ(data, 32'hDEAD_55EF, "dmem byte lane")
    axi_read(core_axi, 32'h0000_0014, data, resp);
    `CHECK_EQ(data, 32'hCAFE_F00D, "dmem second word")

    // Past the end of the memory the window does not decode
    axi_read(core_axi, 32'h0000_0400, data, resp);
    `CHECK_EQ(resp, RESP_DECERR, "past dmem end")

    // Debug loads the instruction memory and sees what the core wrote
    dbg_override_sel = 1'b1;
    axi_write(dbg_axi, 32'h4000_0000, 32'h0000_0013, 4'b1111, resp);
    `CHECK_EQ(resp, RESP_OKAY, "debug imem write")
    axi_read(dbg_axi, 32'h0000_0014, data, resp);
    `CHECK_EQ(data, 32'hCAFE_F00D, "debug reads dmem")

    // The running core reads the instruction memory but cannot write it
    dbg_override_sel = 1'b0;
    axi_read(core_axi, 32'h4000_0000, data, resp);
    `CHECK_EQ(resp, RESP_OKAY, "core imem read")
    `CHECK_EQ(data, 32'h0000_0013, "core imem data")

    axi_write(core_axi, 32'h4000_0000, 32'hFFFF_FFFF, 4'b1111, resp);
    `CHECK_EQ(resp, RESP_SLVERR, "core imem write refused")
    axi_read(core_axi, 32'h4000_0000, data, resp);
    `CHECK_EQ(data, 32'h0000_0013, "imem unchanged")

    `TB_FINISH
end

endmodule

`default_nettype wire
