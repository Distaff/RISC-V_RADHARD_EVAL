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

logic   [ADDR_WIDTH-1:0]    awaddr;
logic                       awvalid;
logic                       awready;

logic   [DATA_WIDTH-1:0]    wdata;
logic   [STRB_WIDTH-1:0]    wstrb;
logic                       wvalid;
logic                       wready;

logic              [1:0]    bresp;
logic                       bvalid;
logic                       bready;

logic   [ADDR_WIDTH-1:0]    araddr;
logic                       arvalid;
logic                       arready;

logic   [DATA_WIDTH-1:0]    rdata;
logic              [1:0]    rresp;
logic                       rvalid;
logic                       rready;

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

property p_valid_held(valid, ready);
    @(posedge clk) disable iff (!rst_n)
    (valid && !ready) |=> valid;
endproperty

property p_payload_held(valid, ready, payload);
    @(posedge clk) disable iff (!rst_n)
    (valid && !ready) |=> $stable(payload);
endproperty

a_aw_valid_held:    assert property (p_valid_held(awvalid, awready));
a_aw_addr_held:     assert property (p_payload_held(awvalid, awready, awaddr));

a_w_valid_held:     assert property (p_valid_held(wvalid, wready));
a_w_data_held:      assert property (p_payload_held(wvalid, wready, {wdata, wstrb}));

a_b_valid_held:     assert property (p_valid_held(bvalid, bready));
a_b_resp_held:      assert property (p_payload_held(bvalid, bready, bresp));

a_ar_valid_held:    assert property (p_valid_held(arvalid, arready));
a_ar_addr_held:     assert property (p_payload_held(arvalid, arready, araddr));

a_r_valid_held:     assert property (p_valid_held(rvalid, rready));
a_r_data_held:      assert property (p_payload_held(rvalid, rready, {rdata, rresp}));

// A handshake on an undefined VALID is a testbench bug rather than a design
// bug, but it is far cheaper to catch here than to chase through a waveform.
a_no_x_on_valid:    assert property (
    @(posedge clk) disable iff (!rst_n)
    !$isunknown({awvalid, wvalid, bvalid, arvalid, rvalid})
);

`endif

endinterface

`default_nettype wire
