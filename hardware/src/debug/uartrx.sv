`timescale 1ns / 1ps
`default_nettype none
/*****************************************************************************
 *  Author: Piotr Kadziela
 *  Description:
 *      UART receiver, 8 data bits, no parity, one stop bit.
 *      //TODO
 *****************************************************************************/

module uartrx #(
    parameter CLK_HZ = 50_000_000,
    parameter BAUD   = 115_200
) (
    input wire              clk,
    input wire              rst_n,

    input wire              rx,             // serial input line

    output logic     [7:0]  rx_data,        // received byte, valid while rx_valid is high
    output logic            rx_valid,       // one-cycle pulse, byte received
    output logic            rx_error        // one-cycle pulse, framing error
);

// TODO

endmodule

`default_nettype wire
