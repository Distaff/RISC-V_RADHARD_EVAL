`timescale 1ns / 1ps
`default_nettype none
/*****************************************************************************
 *  Author: Piotr Kadziela
 *  Description:
 *      Unit testbench for memory_axil driving a real memory instance, so the
 *      whole path from the bus to the array is exercised.
 *      Covers a word round trip, a byte strobe leaving the other lanes alone,
 *      and write_lock refusing writes with SLVERR while still allowing reads.
 *      The bus tasks give up after a bounded wait rather than blocking, so a
 *      front end that never answers fails instead of hanging the simulation.
 *****************************************************************************/

`include "tb_utils.svh"

module memory_axil_tb;

import axil_pkg::*;

`TB_VARS
`TB_TIMEOUT(20000)

localparam MEM_WORDS   = 256;
localparam WAIT_CYCLES = 32;    // how long a handshake may take before giving up

logic           clk;
logic           rst_n;
logic           write_lock;

logic           mem_en;
logic [31:0]    mem_addr;
logic [31:0]    mem_rdata;
logic [31:0]    mem_wdata;
logic  [3:0]    mem_wstrb;

axil_if axi (.clk(clk), .rst_n(rst_n));

memory_axil dut (
    .clk(clk),
    .rst_n(rst_n),
    .write_lock(write_lock),
    .axi(axi),
    .mem_en(mem_en),
    .mem_addr(mem_addr),
    .mem_rdata(mem_rdata),
    .mem_wdata(mem_wdata),
    .mem_wstrb(mem_wstrb)
);

memory #(
    .MEMORY_SIZE_WORDS(MEM_WORDS)
) mem (
    .clk(clk),
    .a_en(1'b0),
    .a_addr(32'd0),
    .a_data(),
    .b_en(mem_en),
    .b_addr(mem_addr),
    .b_data(mem_rdata),
    .b_wdata(mem_wdata),
    .b_wstrb(mem_wstrb)
);

initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
end

// One AXI4-Lite write. Returns the response code, or 2'bxx if the front end
// did not complete the transaction in time.
task automatic axi_write(
    input  logic [31:0] addr,
    input  logic [31:0] data,
    input  logic  [3:0] strb,
    output logic  [1:0] resp
);
    int waited;

    @(negedge clk);
    axi.awaddr  = addr;
    axi.awvalid = 1'b1;
    axi.wdata   = data;
    axi.wstrb   = strb;
    axi.wvalid  = 1'b1;
    axi.bready  = 1'b1;

    waited = 0;
    while ((axi.awvalid || axi.wvalid) && waited < WAIT_CYCLES) begin
        @(posedge clk);
        if (axi.awvalid && axi.awready) axi.awvalid = 1'b0;
        if (axi.wvalid  && axi.wready)  axi.wvalid  = 1'b0;
        waited++;
    end

    resp = 2'bxx;
    while (waited < WAIT_CYCLES) begin
        @(posedge clk);
        waited++;
        if (axi.bvalid) begin
            resp = axi.bresp;
            break;
        end
    end

    @(negedge clk);
    axi.awvalid = 1'b0;
    axi.wvalid  = 1'b0;
    axi.bready  = 1'b0;
endtask

// One AXI4-Lite read.
task automatic axi_read(
    input  logic [31:0] addr,
    output logic [31:0] data,
    output logic  [1:0] resp
);
    int waited;

    @(negedge clk);
    axi.araddr  = addr;
    axi.arvalid = 1'b1;
    axi.rready  = 1'b1;

    waited = 0;
    while (axi.arvalid && waited < WAIT_CYCLES) begin
        @(posedge clk);
        if (axi.arready) axi.arvalid = 1'b0;
        waited++;
    end

    data = 32'hxxxx_xxxx;
    resp = 2'bxx;
    while (waited < WAIT_CYCLES) begin
        @(posedge clk);
        waited++;
        if (axi.rvalid) begin
            data = axi.rdata;
            resp = axi.rresp;
            break;
        end
    end

    @(negedge clk);
    axi.arvalid = 1'b0;
    axi.rready  = 1'b0;
endtask

logic [31:0] data;
logic  [1:0] resp;

initial begin
    rst_n       = 1'b0;
    write_lock  = 1'b0;
    axi.awvalid = 1'b0;
    axi.wvalid  = 1'b0;
    axi.bready  = 1'b0;
    axi.arvalid = 1'b0;
    axi.rready  = 1'b0;
    axi.awaddr  = 32'd0;
    axi.araddr  = 32'd0;
    axi.wdata   = 32'd0;
    axi.wstrb   = 4'd0;

    repeat (4) @(negedge clk);
    rst_n = 1'b1;
    repeat (2) @(negedge clk);

    // Full word out and back.
    axi_write(32'h0000_0010, 32'hDEAD_BEEF, 4'b1111, resp);
    `CHECK_EQ(resp, RESP_OKAY, "word write accepted")
    axi_read(32'h0000_0010, data, resp);
    `CHECK_EQ(resp, RESP_OKAY, "word read accepted")
    `CHECK_EQ(data, 32'hDEAD_BEEF, "word read back")

    // A single byte lane must leave the rest of the word alone.
    axi_write(32'h0000_0010, 32'h0000_0055, 4'b0001, resp);
    `CHECK_EQ(resp, RESP_OKAY, "byte write accepted")
    axi_read(32'h0000_0010, data, resp);
    `CHECK_EQ(data, 32'hDEAD_BE55, "byte write touches one lane")

    // With the lock raised a write is refused and the memory keeps its value.
    write_lock = 1'b1;
    axi_write(32'h0000_0010, 32'h0000_0000, 4'b1111, resp);
    `CHECK_EQ(resp, RESP_SLVERR, "locked write refused")
    axi_read(32'h0000_0010, data, resp);
    `CHECK_EQ(resp, RESP_OKAY, "read allowed while locked")
    `CHECK_EQ(data, 32'hDEAD_BE55, "locked write left no trace")

    write_lock = 1'b0;

    `TB_FINISH
end

endmodule

`default_nettype wire
