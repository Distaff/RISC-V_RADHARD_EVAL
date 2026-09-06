`timescale 1ns / 1ps
`default_nettype none
/*****************************************************************************
 *  Author: Piotr Kadziela
 *  Description:
 *      Debug unit top level. 
 *****************************************************************************/

module dbgtoplevel #(
    parameter CLK_HZ = 50_000_000,
    parameter BAUD   = 115_200
) (
    input wire              clk,
    input wire              rst_n,

    // Debug link
    input wire              uart_rx,
    output logic            uart_tx,

    // Bus master
    axil_if.master          dbg_axi,

    // Core sideband
    debug_if.host           dbg,

    // Latched error status, held by the top level
    input wire    [7:0]     err_flags,
    output logic            err_clear       // one-cycle pulse, clears the latch
);

// TODO

endmodule

`default_nettype wire
