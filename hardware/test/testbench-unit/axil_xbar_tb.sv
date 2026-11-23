`timescale 1ns / 1ps
`default_nettype none
/*****************************************************************************
 *  Author: Piotr Kadziela (AI Generated)
 *  Description:
 *      Unit testbench for axil_xbar with two slave models.
 *      Covers routing to each slave, DECERR on an unmapped address, a slave
 *      taking W before AW, and a core access held off while debug owns the bus.
 *****************************************************************************/

`include "tb_utils.svh"

// Minimal slave. Reads return {ID, 8'h00, addr[15:0]}. With W_FIRST set it
// takes the write data before the address.
module axil_xbar_tb_slave #(
    parameter ID      = 0,
    parameter W_FIRST = 0
) (
    input wire      clk,
    input wire      rst_n,
    axil_if.slave   s
);

import axil_pkg::*;

logic           aw_got;
logic           w_got;
int             writes;
int             reads;
logic [31:0]    last_wdata;

assign s.awready = !aw_got && (!W_FIRST || w_got);
assign s.wready  = !w_got;
assign s.arready = !s.rvalid;
assign s.bresp   = RESP_OKAY;
assign s.rresp   = RESP_OKAY;

always_ff @(posedge clk) begin
    if (!rst_n) begin
        aw_got   <= 1'b0;
        w_got    <= 1'b0;
        s.bvalid <= 1'b0;
        s.rvalid <= 1'b0;
        writes   <= 0;
        reads    <= 0;
    end
    else begin
        if (s.awvalid && s.awready) aw_got <= 1'b1;
        if (s.wvalid && s.wready) begin
            w_got      <= 1'b1;
            last_wdata <= s.wdata;
        end
        if (aw_got && w_got && !s.bvalid) begin
            s.bvalid <= 1'b1;
            aw_got   <= 1'b0;
            w_got    <= 1'b0;
            writes   <= writes + 1;
        end
        if (s.bvalid && s.bready) s.bvalid <= 1'b0;

        if (s.arvalid && s.arready) begin
            s.rvalid <= 1'b1;
            s.rdata  <= {8'(ID), 8'h00, s.araddr[15:0]};
            reads    <= reads + 1;
        end
        if (s.rvalid && s.rready) s.rvalid <= 1'b0;
    end
end

endmodule


module axil_xbar_tb;

import axil_pkg::*;

`TB_VARS
`TB_TIMEOUT(20000)

localparam WAIT_CYCLES = 32;

logic clk;
logic rst_n;
logic dbg_override_sel;

axil_if core_axi (.clk(clk), .rst_n(rst_n));
axil_if dbg_axi (.clk(clk), .rst_n(rst_n));
axil_if slv_axi [2] (.clk(clk), .rst_n(rst_n));

axil_xbar #(
    .NUM_SLV(2),
    .SLV_BASE({32'h8000_0000, 32'h0000_0000}),
    .SLV_MASK({32'hFFFF_0000, 32'hFFFF_0000})
) dut (
    .clk(clk),
    .rst_n(rst_n),
    .dbg_override_sel(dbg_override_sel),
    .core_axi(core_axi),
    .dbg_axi(dbg_axi),
    .slv_axi(slv_axi)
);

axil_xbar_tb_slave #(.ID(0))               s0 (.clk(clk), .rst_n(rst_n), .s(slv_axi[0]));
axil_xbar_tb_slave #(.ID(1), .W_FIRST(1))  s1 (.clk(clk), .rst_n(rst_n), .s(slv_axi[1]));

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
    output logic  [1:0] resp
);
    int  n = 0;
    bit  aw_hs, w_hs;

    @(negedge clk);
    m.awaddr  = addr;
    m.awvalid = 1'b1;
    m.wdata   = data;
    m.wstrb   = 4'hF;
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

logic [31:0] data, core_data;
logic  [1:0] resp, core_resp;
bit          core_done;

initial begin
    rst_n      = 1'b0;
    dbg_override_sel = 1'b0;
    idle(core_axi);
    idle(dbg_axi);

    repeat (4) @(negedge clk);
    rst_n = 1'b1;
    repeat (2) @(negedge clk);

    // Slave 0
    axi_write(core_axi, 32'h0000_0004, 32'hDEAD_BEEF, resp);
    `CHECK_EQ(resp, RESP_OKAY, "s0 write")
    `CHECK_EQ(s0.last_wdata, 32'hDEAD_BEEF, "s0 write data")
    `CHECK_EQ(s0.writes, 1, "s0 written once")
    `CHECK_EQ(s1.writes, 0, "s1 not written")

    axi_read(core_axi, 32'h0000_0004, data, resp);
    `CHECK_EQ(resp, RESP_OKAY, "s0 read")
    `CHECK_EQ(data, 32'h0000_0004, "s0 read data")
    `CHECK_EQ(s1.reads, 0, "s1 not read")

    // Slave 1 takes W before AW
    axi_write(core_axi, 32'h8000_0008, 32'h1234_5678, resp);
    `CHECK_EQ(resp, RESP_OKAY, "s1 write")
    `CHECK_EQ(s1.last_wdata, 32'h1234_5678, "s1 write data")
    `CHECK_EQ(s0.writes, 1, "s0 not written again")

    axi_read(core_axi, 32'h8000_0008, data, resp);
    `CHECK_EQ(resp, RESP_OKAY, "s1 read")
    `CHECK_EQ(data, 32'h0100_0008, "s1 read data")

    // Unmapped address
    axi_write(core_axi, 32'h4000_0000, 32'hFFFF_FFFF, resp);
    `CHECK_EQ(resp, RESP_DECERR, "unmapped write")
    axi_read(core_axi, 32'h4000_0000, data, resp);
    `CHECK_EQ(resp, RESP_DECERR, "unmapped read")
    `CHECK_EQ(data, 32'h0, "unmapped read data")
    `CHECK_EQ(s0.writes + s1.writes, 2, "unmapped write reached no slave")
    `CHECK_EQ(s0.reads + s1.reads, 2, "unmapped read reached no slave")

    // While debug owns the bus a core access waits, debug goes through
    dbg_override_sel = 1'b1;
    fork
        begin
            axi_read(core_axi, 32'h0000_0010, core_data, core_resp);
            core_done = 1'b1;
        end
    join_none

    axi_read(dbg_axi, 32'h8000_0020, data, resp);
    `CHECK_EQ(resp, RESP_OKAY, "debug read")
    `CHECK_EQ(data, 32'h0100_0020, "debug read data")
    `CHECK(!core_done && core_axi.arready !== 1'b1, "core held off")

    dbg_override_sel = 1'b0;
    wait fork;
    `CHECK_EQ(core_resp, RESP_OKAY, "core read after debug")
    `CHECK_EQ(core_data, 32'h0000_0010, "core read data after debug")

    `TB_FINISH
end

endmodule

`default_nettype wire
