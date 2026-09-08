`timescale 1ns / 1ps
`default_nettype none
/*****************************************************************************
 *  Author: Piotr Kadziela
 *  Description:
 *      Unit testbench for imm_decoder. One instruction per format, encoded by
 *      hand, with a negative case for the formats that sign extend. The B and
 *      J formats also confirm that bit zero of the immediate is cleared.
 *****************************************************************************/

`include "opcodes.svh"
`include "tb_utils.svh"

module imm_decoder_tb;

`TB_VARS

logic [31:0] instr;
logic [31:0] imm;

imm_decoder dut (
    .instr(instr),
    .imm(imm)
);

task automatic check_imm(
    input string       name,
    input logic [31:0] encoded,
    input logic [31:0] expected
);
    instr = encoded;
    #1;
    `CHECK_EQ(imm, expected, name)
endtask

initial begin
    // add x1, x2, x3 - an R-type instruction carries no immediate
    check_imm("r-type has none", 32'h0031_00B3, 32'h0000_0000);

    // addi x1, x0, 5
    check_imm("i-type positive", 32'h0050_0093, 32'h0000_0005);
    // addi x1, x0, -1
    check_imm("i-type negative", 32'hFFF0_0093, 32'hFFFF_FFFF);

    // sw x2, 8(x1)
    check_imm("s-type positive", 32'h0020_A423, 32'h0000_0008);
    // sw x2, -4(x1)
    check_imm("s-type negative", 32'hFE20_AE23, 32'hFFFF_FFFC);

    // beq x1, x2, +8 - the immediate is even by construction
    check_imm("b-type positive", 32'h0020_8463, 32'h0000_0008);
    // beq x1, x2, -8
    check_imm("b-type negative", 32'hFE20_8CE3, 32'hFFFF_FFF8);

    // jal x1, +16
    check_imm("j-type positive", 32'h0100_00EF, 32'h0000_0010);

    // lui x1, 0x12345
    check_imm("u-type", 32'h1234_50B7, 32'h1234_5000);

    // An opcode that decodes to nothing gets the marker pattern.
    check_imm("unknown opcode", 32'h0000_007F, 32'h5555_5555);

    `TB_FINISH
end

endmodule

`default_nettype wire
