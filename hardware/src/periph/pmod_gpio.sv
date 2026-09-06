`timescale 1ns / 1ps
`default_nettype none
/*****************************************************************************
 *  Author: Piotr Kadziela
 *  Description:
 *      General purpose I/O for one PMOD connector, eight pins wide.
 *
 *      Register map:
 *          0x00  DDR   RW  direction: 0 = input, 1 = output
 *          0x04  PORT  RW  output value
 *          0x08  PIN   RO  pin state; writing a one toggles the PORT bit
 *****************************************************************************/

module pmod_gpio #(
    parameter WIDTH = 8                 // one PMOD connector
) (
    input wire              clk,
    input wire              rst_n,

    axil_if.slave           axi,

    output logic [WIDTH-1:0] pin_o,      // value driven onto the pin
    output logic [WIDTH-1:0] pin_oe,     // output enable, 1 = drive
    input  wire  [WIDTH-1:0] pin_i       // value read from the pin
);

// TODO

endmodule

`default_nettype wire
