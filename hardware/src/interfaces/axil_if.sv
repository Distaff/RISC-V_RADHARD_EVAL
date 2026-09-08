`timescale 1ns / 1ps
`default_nettype none
/*****************************************************************************
 *  Author: Piotr Kadziela
 *  Description:
 *      AXI4-Lite interface bundle used throughout the MCU.
 *      AxPROT and AxCACHE are not carried.
 *      Interfaces must be unpacked into flat ports at the board top level.
 *****************************************************************************/

interface axil_if #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
) (
    input wire logic    clk,
    input wire logic    rst_n
);

localparam STRB_WIDTH = DATA_WIDTH / 8;

logic   [ADDR_WIDTH-1:0]    awaddr;     // Write address
logic                       awvalid;    // Write address valid/ready to be read by the slave
logic                       awready;    // Write address ready/slave ready to accept the address

logic   [DATA_WIDTH-1:0]    wdata;      // Write data
logic   [STRB_WIDTH-1:0]    wstrb;      // Write strobes, one bit for each byte lane. 1 = write, 0 = skip.
logic                       wvalid;     // Write valid/ready to be read by the slave
logic                       wready;     // Write ready/slave ready to accept the write data

logic              [1:0]    bresp;      // Write response. 2'b00 = OKAY, 2'b01 = EXOKAY, 2'b10 = SLVERR, 2'b11 = DECERR
logic                       bvalid;     // Write response valid/ready to be read by the master
logic                       bready;     // Response ready/master ready to accept the write response

logic   [ADDR_WIDTH-1:0]    araddr;     // Read address
logic                       arvalid;    // Read address valid/ready to be read by the slave
logic                       arready;    // Read address ready/slave ready to accept the address

logic   [DATA_WIDTH-1:0]    rdata;      // Read data
logic              [1:0]    rresp;      // Read response. 2'b00 = OKAY, 2'b01 = EXOKAY, 2'b10 = SLVERR, 2'b11 = DECERR
logic                       rvalid;     // Read valid/ready to be read by the master
logic                       rready;     // Read ready/master ready to accept the read data

modport master (
    output  awaddr, awvalid, wdata, wstrb, wvalid, bready, araddr, arvalid, rready,
    input   awready, wready, bresp, bvalid, arready, rdata, rresp, rvalid
);

modport slave (
    input   awaddr, awvalid, wdata, wstrb, wvalid, bready, araddr, arvalid, rready,
    output  awready, wready, bresp, bvalid, arready, rdata, rresp, rvalid
);

`ifndef SYNTHESIS

// A channel that has offered data must keep offering it, unchanged, until the
// far side takes it. Everything below is that one rule applied per channel.

a_aw_valid_held: assert property (@(posedge clk) disable iff (!rst_n)
    (awvalid && !awready) |=> awvalid);
a_aw_addr_held:  assert property (@(posedge clk) disable iff (!rst_n)
    (awvalid && !awready) |=> $stable(awaddr));

a_w_valid_held:  assert property (@(posedge clk) disable iff (!rst_n)
    (wvalid && !wready) |=> wvalid);
a_w_data_held:   assert property (@(posedge clk) disable iff (!rst_n)
    (wvalid && !wready) |=> $stable(wdata) && $stable(wstrb));

a_b_valid_held:  assert property (@(posedge clk) disable iff (!rst_n)
    (bvalid && !bready) |=> bvalid);
a_b_resp_held:   assert property (@(posedge clk) disable iff (!rst_n)
    (bvalid && !bready) |=> $stable(bresp));

a_ar_valid_held: assert property (@(posedge clk) disable iff (!rst_n)
    (arvalid && !arready) |=> arvalid);
a_ar_addr_held:  assert property (@(posedge clk) disable iff (!rst_n)
    (arvalid && !arready) |=> $stable(araddr));

a_r_valid_held:  assert property (@(posedge clk) disable iff (!rst_n)
    (rvalid && !rready) |=> rvalid);
a_r_data_held:   assert property (@(posedge clk) disable iff (!rst_n)
    (rvalid && !rready) |=> $stable(rdata) && $stable(rresp));

`endif

endinterface

`default_nettype wire
