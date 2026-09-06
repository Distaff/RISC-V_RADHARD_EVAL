`timescale 1ns / 1ps
`default_nettype none
/*****************************************************************************
 *  Author: Piotr Kadziela
 *  Description:
 *      Multiplier for the Zmmul extension: MUL, MULH, MULHSU and MULHU.
 *      The operation takes several cycles and reports completion through done.
 *****************************************************************************/

`include "opcodes.svh"

module mul (
    input wire              clk,
    input wire              rst_n,

    input wire              start,      // one-cycle pulse, latches the operands
    input wire   [2:0]      funct3,     // selects which half of the product is returned
    input wire  [31:0]      op_a,
    input wire  [31:0]      op_b,

    output logic [31:0]     result,
    output logic            done        // one-cycle pulse, result is valid
);

// TODO

endmodule

`default_nettype wire
