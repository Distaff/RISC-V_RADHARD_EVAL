`timescale 1ns / 1ps
`default_nettype none
/*****************************************************************************
 *  Author: Piotr Kadziela (AI Generated)
 *  Description:
 *      Integration testbench for the memory system: axil_lsu on the core
 *      side, raw AXI4-Lite on the debug side, axil_xbar and two memories
 *      behind memory_adapter_axil, wired like the data and instruction
 *      memories in toplevel.
 *      The instruction memory is writable only while debug owns the bus.
 *****************************************************************************/

`include "opcodes.svh"
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

// CORE SIDE

logic           lsu_req;
logic           lsu_we;
logic  [2:0]    lsu_funct3;
logic [31:0]    lsu_addr;
logic [31:0]    lsu_wdata;
logic [31:0]    lsu_rdata;
logic           lsu_done;
axil_resp_t     lsu_resp;

axil_lsu lsu1 (
    .clk(clk),
    .rst_n(rst_n),
    .req(lsu_req),
    .we(lsu_we),
    .funct3(lsu_funct3),
    .addr(lsu_addr),
    .wdata(lsu_wdata),
    .rdata(lsu_rdata),
    .done(lsu_done),
    .resp(lsu_resp),
    .data_axi(core_axi)
);

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

// Every access must end with exactly one done pulse
int accesses   = 0;
int done_count = 0;

always @(posedge clk)
    if (lsu_done === 1'b1) done_count++;

// One access through the LSU, the way the core makes it: request held until
// done, dropped on the edge that completes it. Signals are driven and
// sampled on the falling edge.
task automatic lsu_access(
    input  logic        store,
    input  logic  [2:0] f3,
    input  logic [31:0] addr,
    input  logic [31:0] wdata,
    output logic [31:0] rdata,
    output logic  [1:0] resp
);
    int n = 0;

    @(negedge clk);
    lsu_we     = store;
    lsu_funct3 = f3;
    lsu_addr   = addr;
    lsu_wdata  = wdata;
    lsu_req    = 1'b1;

    while (lsu_done !== 1'b1 && n < WAIT_CYCLES) begin
        @(negedge clk);
        n++;
    end
    rdata = lsu_done ? lsu_rdata : 32'hxxxx_xxxx;
    resp  = lsu_done ? lsu_resp  : 2'bxx;

    @(negedge clk);
    lsu_req = 1'b0;
    accesses++;
endtask

task automatic store(input logic [2:0] f3, input logic [31:0] addr, input logic [31:0] wdata,
                     output logic [1:0] resp);
    logic [31:0] unused;
    lsu_access(1'b1, f3, addr, wdata, unused, resp);
endtask

task automatic load(input logic [2:0] f3, input logic [31:0] addr,
                    output logic [31:0] rdata, output logic [1:0] resp);
    lsu_access(1'b0, f3, addr, 32'd0, rdata, resp);
endtask

// Raw AXI4-Lite master for the debug side
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

logic [31:0] data;
logic  [1:0] resp;

initial begin
    rst_n            = 1'b0;
    dbg_override_sel = 1'b0;

    lsu_req    = 1'b0;
    lsu_we     = 1'b0;
    lsu_funct3 = 3'd0;
    lsu_addr   = 32'd0;
    lsu_wdata  = 32'd0;

    dbg_axi.awvalid = 1'b0;
    dbg_axi.wvalid  = 1'b0;
    dbg_axi.bready  = 1'b0;
    dbg_axi.arvalid = 1'b0;
    dbg_axi.rready  = 1'b0;
    dbg_axi.awaddr  = 32'd0;
    dbg_axi.araddr  = 32'd0;
    dbg_axi.wdata   = 32'd0;
    dbg_axi.wstrb   = 4'd0;

    repeat (4) @(negedge clk);
    rst_n = 1'b1;
    repeat (2) @(negedge clk);

    //-------------------------------------------------------------------------
    // Loads: every byte of 0x80FF_7F01 has a different top bit pattern
    //-------------------------------------------------------------------------
    store(`FUNCT3_SW, 32'h0000_0010, 32'h80FF_7F01, resp);
    `CHECK_EQ(resp, AXIL_RESP_OKAY, "sw")
    load(`FUNCT3_LW, 32'h0000_0010, data, resp);
    `CHECK_EQ(resp, AXIL_RESP_OKAY, "lw resp")
    `CHECK_EQ(data, 32'h80FF_7F01, "lw")

    load(`FUNCT3_LB, 32'h0000_0010, data, resp);
    `CHECK_EQ(data, 32'h0000_0001, "lb lane 0")
    load(`FUNCT3_LB, 32'h0000_0011, data, resp);
    `CHECK_EQ(data, 32'h0000_007F, "lb lane 1")
    load(`FUNCT3_LB, 32'h0000_0012, data, resp);
    `CHECK_EQ(data, 32'hFFFF_FFFF, "lb lane 2, sign extended")
    load(`FUNCT3_LB, 32'h0000_0013, data, resp);
    `CHECK_EQ(data, 32'hFFFF_FF80, "lb lane 3, sign extended")
    load(`FUNCT3_LBU, 32'h0000_0012, data, resp);
    `CHECK_EQ(data, 32'h0000_00FF, "lbu lane 2")
    load(`FUNCT3_LBU, 32'h0000_0013, data, resp);
    `CHECK_EQ(data, 32'h0000_0080, "lbu lane 3")

    load(`FUNCT3_LH, 32'h0000_0010, data, resp);
    `CHECK_EQ(data, 32'h0000_7F01, "lh low half")
    load(`FUNCT3_LH, 32'h0000_0012, data, resp);
    `CHECK_EQ(data, 32'hFFFF_80FF, "lh high half, sign extended")
    load(`FUNCT3_LHU, 32'h0000_0012, data, resp);
    `CHECK_EQ(data, 32'h0000_80FF, "lhu high half")

    //-------------------------------------------------------------------------
    // Stores: only the addressed lanes change
    //-------------------------------------------------------------------------
    store(`FUNCT3_SW, 32'h0000_0014, 32'h1111_1111, resp);
    store(`FUNCT3_SB, 32'h0000_0015, 32'h0000_00AB, resp);
    `CHECK_EQ(resp, AXIL_RESP_OKAY, "sb")
    store(`FUNCT3_SB, 32'h0000_0017, 32'h0000_00CD, resp);
    load(`FUNCT3_LW, 32'h0000_0014, data, resp);
    `CHECK_EQ(data, 32'hCD11_AB11, "sb lanes 1 and 3")

    store(`FUNCT3_SH, 32'h0000_0016, 32'h0000_BEEF, resp);
    `CHECK_EQ(resp, AXIL_RESP_OKAY, "sh")
    load(`FUNCT3_LW, 32'h0000_0014, data, resp);
    `CHECK_EQ(data, 32'hBEEF_AB11, "sh high half")
    store(`FUNCT3_SH, 32'h0000_0014, 32'h0000_1234, resp);
    load(`FUNCT3_LW, 32'h0000_0014, data, resp);
    `CHECK_EQ(data, 32'hBEEF_1234, "sh low half")

    // Bits above the stored width are ignored
    store(`FUNCT3_SB, 32'h0000_0014, 32'hFFFF_FF5A, resp);
    load(`FUNCT3_LW, 32'h0000_0014, data, resp);
    `CHECK_EQ(data, 32'hBEEF_125A, "sb uses the low byte only")

    // The neighbouring word is untouched by all of the above
    load(`FUNCT3_LW, 32'h0000_0010, data, resp);
    `CHECK_EQ(data, 32'h80FF_7F01, "neighbouring word untouched")

    //-------------------------------------------------------------------------
    // Errors reach the core as a response code
    //-------------------------------------------------------------------------
    load(`FUNCT3_LW, 32'h0000_0400, data, resp);
    `CHECK_EQ(resp, AXIL_RESP_DECERR, "load past dmem end")
    store(`FUNCT3_SW, 32'h0000_0400, 32'h0, resp);
    `CHECK_EQ(resp, AXIL_RESP_DECERR, "store past dmem end")

    //-------------------------------------------------------------------------
    // Debug loads the instruction memory and sees what the core wrote
    //-------------------------------------------------------------------------
    dbg_override_sel = 1'b1;
    axi_write(dbg_axi, 32'h4000_0000, 32'h0000_0013, 4'b1111, resp);
    `CHECK_EQ(resp, AXIL_RESP_OKAY, "debug imem write")
    axi_read(dbg_axi, 32'h0000_0014, data, resp);
    `CHECK_EQ(data, 32'hBEEF_125A, "debug reads dmem")

    //-------------------------------------------------------------------------
    // The running core reads the instruction memory but cannot write it
    //-------------------------------------------------------------------------
    dbg_override_sel = 1'b0;
    load(`FUNCT3_LW, 32'h4000_0000, data, resp);
    `CHECK_EQ(resp, AXIL_RESP_OKAY, "core imem read")
    `CHECK_EQ(data, 32'h0000_0013, "core imem data")
    load(`FUNCT3_LBU, 32'h4000_0000, data, resp);
    `CHECK_EQ(data, 32'h0000_0013, "core imem byte")

    store(`FUNCT3_SW, 32'h4000_0000, 32'hFFFF_FFFF, resp);
    `CHECK_EQ(resp, AXIL_RESP_SLVERR, "core imem write refused")
    load(`FUNCT3_LW, 32'h4000_0000, data, resp);
    `CHECK_EQ(data, 32'h0000_0013, "imem unchanged")

    `CHECK_EQ(done_count, accesses, "one done pulse per access")

    `TB_FINISH
end

endmodule

`default_nettype wire
