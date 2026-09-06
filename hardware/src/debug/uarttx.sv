`timescale 1ns / 1ps
`default_nettype none
/*****************************************************************************
 *  Author: Piotr Kadziela
 *  Description:
 *      UART transmitter, 8 data bits, no parity, one stop bit.
 *      //TODO
 *****************************************************************************/

module uarttx #(
    parameter CLK_HZ = 50_000_000,
    parameter BAUD   = 115_200
) (
    input wire              clk,
    input wire              rst_n,

    input wire       [7:0]  tx_data,        // byte to send
    input wire              tx_start,       // one-cycle pulse, ignored while busy
    output logic            tx_busy,        // high from tx_start until the stop bit ends

    output logic            tx              // serial output line, idles high
);

// TODO

endmodule

`default_nettype wire
