`timescale 1ns / 1ps
`default_nettype none
/*****************************************************************************
 *  Author: Piotr Kadziela
 *  Description:
 *      AXI4-Lite front end for the timer peripheral. Handles the bus handshake
 *      and the register decode; the counter itself lives in timer.sv.
 *****************************************************************************/

module timer_axil (
    input wire              clk,
    input wire              rst_n,

    axil_if.slave           axi
);

// TODO

endmodule

`default_nettype wire
