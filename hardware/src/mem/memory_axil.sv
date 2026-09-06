`timescale 1ns / 1ps
`default_nettype none
/*****************************************************************************
 *  Author: Piotr Kadziela
 *  Description:
 *      AXI4-Lite front end for the memory module, driving port B.
 *      While write_lock is high, writes are refused with SLVERR. Reads are
 *      unaffected.
 *****************************************************************************/

module memory_axil (
    input wire              clk,
    input wire              rst_n,

    input wire              write_lock, // high refuses writes with SLVERR

    axil_if.slave           axi,

    // Port B of the memory instance
    output logic            mem_en,
    output logic [31:0]     mem_addr,
    input wire   [31:0]     mem_rdata,
    output logic [31:0]     mem_wdata,
    output logic  [3:0]     mem_wstrb
);

// TODO

endmodule

`default_nettype wire
