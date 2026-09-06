`timescale 1ns / 1ps
`default_nettype none
/*****************************************************************************
 *  Author: Piotr Kadziela
 *  Description:
 *      Binary protocol decoder for the debug link.
 *      //TODO
 *****************************************************************************/

module dbg_proto (
    input wire              clk,
    input wire              rst_n,

    // Byte stream from and to the transport
    input wire    [7:0]     rx_data,
    input wire              rx_valid,
    output logic  [7:0]     tx_data,
    output logic            tx_start,
    input wire              tx_busy,

    // Decoded command
    output logic  [7:0]     cmd,            // command byte of the current frame
    output logic            cmd_valid,      // frame received complete and checksum matched
    output logic [31:0]     cmd_addr,       // address field, for the memory commands
    output logic [15:0]     cmd_count,      // word count, for the memory commands
    output logic  [7:0]     cmd_resp,       // response code to send back
    input wire              cmd_done        // executor finished, send the response
);

// TODO

endmodule

`default_nettype wire
