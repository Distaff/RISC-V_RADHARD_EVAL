`timescale 1ns / 1ps
`default_nettype none
/*****************************************************************************
 *  Author: Piotr Kadziela
 *  Description:
 *      Multiplier for the Zmmul extension: MUL, MULH, MULHSU and MULHU.
 *      Operands are extended to 33 bits by signedness, so one signed product
 *      serves all four. Takes four cycles. Nothing is latched: funct3 and
 *      the operands must stay stable from start until done, and start must
 *      not be raised again before done.
 *****************************************************************************/

`include "opcodes.svh"

module mul (
    input wire              clk,
    input wire              rst_n,

    input wire              start,      // one-cycle pulse, begins the operation
    input wire   [2:0]      funct3,     // stable until done
    input wire  [31:0]      op_a,       // stable until done
    input wire  [31:0]      op_b,       // stable until done

    output logic [31:0]     result,
    output logic            done        // one-cycle pulse, result is valid
);

localparam LATENCY = 4;                 // pipeline depth of mul64

logic                   a_signed;
logic                   b_signed;
logic  [63:0]           product;
logic  [LATENCY-1:0]    busy;

always_comb begin
    case (funct3)
        `FUNCT3_MULH:   {a_signed, b_signed} = 2'b11;
        `FUNCT3_MULHSU: {a_signed, b_signed} = 2'b10;
        default:        {a_signed, b_signed} = 2'b00;
    endcase
end

mul64 mul64_0 (
    .clk(clk),
    .a_in({a_signed & op_a[31], op_a}),
    .b_in({b_signed & op_b[31], op_b}),
    .p_out(product)
);

always_ff @(posedge clk) begin
    if (!rst_n)
        busy <= '0;
    else
        busy <= {busy[LATENCY-2:0], start};
end

assign done   = busy[LATENCY-1];
assign result = (funct3 == `FUNCT3_MUL) ? product[31:0] : product[63:32];

endmodule

`default_nettype wire
