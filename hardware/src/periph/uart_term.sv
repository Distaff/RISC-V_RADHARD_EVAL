`timescale 1ns / 1ps
`default_nettype none
/*****************************************************************************
 *  Author: Piotr Kadziela
 *  Description:
 *      UART terminal peripheral, wrapping uarttx and uartrx as registers.
 *      This is the I/O channel available to the running program; the debug
 *      link is separate and is not on the bus.
 *****************************************************************************/

module uart_term #(
    parameter CLK_HZ = 50_000_000,
    parameter BAUD   = 115_200
) (
    input wire              clk,
    input wire              rst_n,

    axil_if.slave           axi,

    input wire              uart_rx,
    output logic            uart_tx
    // TODO - I/O z modułu do poprawy chyba
);

// TODO

endmodule

`default_nettype wire
