`timescale 1ns / 1ps
`default_nettype none
/*****************************************************************************
 *  Author: Piotr Kadziela
 *  Description:
 *      AXI4-Lite master for the debug unit. Turns single word read and write
 *      requests into bus transactions and returns the response code.
 *****************************************************************************/

module dbg_axil_master (
    input wire              clk,
    input wire              rst_n,

    input wire              req,        // start an access, held until done
    input wire              we,         // high for a write
    input wire  [31:0]      addr,       // byte address, word aligned
    input wire  [31:0]      wdata,
    output logic [31:0]     rdata,
    output logic            done,       // one-cycle pulse
    output logic  [1:0]     resp,       // AXI response code of the finished access

    axil_if.master          dbg_axi
);

// TODO

endmodule

`default_nettype wire
