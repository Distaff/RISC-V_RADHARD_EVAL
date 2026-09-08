`timescale 1ns / 1ps
`default_nettype none
/*****************************************************************************
 *  Author: Piotr Kadziela
 *  Description:
 *      Unit testbench for branch_unit. One taken and one not taken case per
 *      condition, plus the disabled unit.
 *      The signed and unsigned comparisons are driven with the same operand
 *      pair, so an implementation that treats them alike cannot pass both.
 *****************************************************************************/

`include "opcodes.svh"
`include "tb_utils.svh"

module branch_unit_tb;

`TB_VARS

logic           br_en;
logic  [2:0]    funct3;
logic [31:0]    br_data_a;
logic [31:0]    br_data_b;
logic           br_taken;

branch_unit dut (
    .br_en(br_en),
    .funct3(funct3),
    .br_data_a(br_data_a),
    .br_data_b(br_data_b),
    .br_taken(br_taken)
);

task automatic check_br(
    input string       name,
    input logic  [2:0] f3,
    input logic [31:0] a,
    input logic [31:0] b,
    input logic        expected
);
    funct3    = f3;
    br_data_a = a;
    br_data_b = b;
    br_en     = 1'b1;
    #1;
    `CHECK_EQ(br_taken, expected, name)
endtask

initial begin
    // A disabled unit never reports a branch, whatever the operands say.
    br_en     = 1'b0;
    funct3    = `FUNCT3_BEQ;
    br_data_a = 32'h0000_0007;
    br_data_b = 32'h0000_0007;
    #1;
    `CHECK_EQ(br_taken, 1'b0, "disabled unit never takes")

    check_br("beq equal",     `FUNCT3_BEQ, 32'h0000_0007, 32'h0000_0007, 1'b1);
    check_br("beq different", `FUNCT3_BEQ, 32'h0000_0007, 32'h0000_0008, 1'b0);

    check_br("bne equal",     `FUNCT3_BNE, 32'h0000_0007, 32'h0000_0007, 1'b0);
    check_br("bne different", `FUNCT3_BNE, 32'h0000_0007, 32'h0000_0008, 1'b1);

    // -1 against 1: less than when signed, greater than when unsigned.
    check_br("blt neg lt pos",  `FUNCT3_BLT,  32'hFFFF_FFFF, 32'h0000_0001, 1'b1);
    check_br("blt pos lt neg",  `FUNCT3_BLT,  32'h0000_0001, 32'hFFFF_FFFF, 1'b0);
    check_br("bltu neg gt pos", `FUNCT3_BLTU, 32'hFFFF_FFFF, 32'h0000_0001, 1'b0);
    check_br("bltu pos lt neg", `FUNCT3_BLTU, 32'h0000_0001, 32'hFFFF_FFFF, 1'b1);

    check_br("bge equal",       `FUNCT3_BGE,  32'h0000_0007, 32'h0000_0007, 1'b1);
    check_br("bge neg vs pos",  `FUNCT3_BGE,  32'hFFFF_FFFF, 32'h0000_0001, 1'b0);
    check_br("bgeu equal",      `FUNCT3_BGEU, 32'h0000_0007, 32'h0000_0007, 1'b1);
    check_br("bgeu neg vs pos", `FUNCT3_BGEU, 32'hFFFF_FFFF, 32'h0000_0001, 1'b1);

    `TB_FINISH
end

endmodule

`default_nettype wire
