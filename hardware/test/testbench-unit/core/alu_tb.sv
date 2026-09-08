`timescale 1ns / 1ps
`default_nettype none
/*****************************************************************************
 *  Author: Piotr Kadziela
 *  Description:
 *      Unit testbench for alu. Every expected value is worked out by hand and
 *      written into the vector, so nothing here depends on a second
 *      implementation of the same arithmetic.
 *      Both operand sources are driven with the same value, which leaves
 *      src_sel selecting only the path the DUT takes and not the answer.
 *****************************************************************************/

`include "opcodes.svh"
`include "tb_utils.svh"

module alu_tb;

`TB_VARS

logic  [2:0]    funct3;
logic  [6:0]    funct7;
logic           alu_en;
logic           src_sel;
logic [31:0]    reg_data_1;
logic [31:0]    reg_data_2;
logic [31:0]    immediate;
logic [31:0]    alu_res;

alu dut (
    .funct3(funct3),
    .funct7(funct7),
    .alu_en(alu_en),
    .src_sel(src_sel),
    .reg_data_1(reg_data_1),
    .reg_data_2(reg_data_2),
    .immediate(immediate),
    .alu_res(alu_res)
);

task automatic check_op(
    input string       name,
    input logic  [2:0] f3,
    input logic  [6:0] f7,
    input logic        src,
    input logic [31:0] a,
    input logic [31:0] b,
    input logic [31:0] expected
);
    funct3     = f3;
    funct7     = f7;
    src_sel    = src;
    reg_data_1 = a;
    reg_data_2 = b;
    immediate  = b;
    alu_en     = 1'b1;
    #1;
    `CHECK_EQ(alu_res, expected, name)
endtask

initial begin
    //-------------------------------------------------------------------------
    // A disabled ALU drives zero whatever sits on its inputs
    //-------------------------------------------------------------------------
    alu_en     = 1'b0;
    funct3     = `FUNCT3_ADD_SUB;
    funct7     = `FUNCT7_ALU_NORM;
    src_sel    = 1'b1;
    reg_data_1 = 32'hDEAD_BEEF;
    reg_data_2 = 32'h1234_5678;
    immediate  = 32'h1234_5678;
    #1;
    `CHECK_EQ(alu_res, 32'h0000_0000, "disabled alu drives zero")

    //-------------------------------------------------------------------------
    // ADD
    //-------------------------------------------------------------------------
    check_op("add small",     `FUNCT3_ADD_SUB, `FUNCT7_ALU_NORM, 1'b1,
             32'h0000_0002, 32'h0000_0003, 32'h0000_0005);
    check_op("add digits",    `FUNCT3_ADD_SUB, `FUNCT7_ALU_NORM, 1'b1,
             32'h1234_5678, 32'h1111_1111, 32'h2345_6789);
    check_op("add wraps",     `FUNCT3_ADD_SUB, `FUNCT7_ALU_NORM, 1'b1,
             32'hFFFF_FFFF, 32'h0000_0001, 32'h0000_0000);
    check_op("add to sign",   `FUNCT3_ADD_SUB, `FUNCT7_ALU_NORM, 1'b1,
             32'h7FFF_FFFF, 32'h0000_0001, 32'h8000_0000);

    //-------------------------------------------------------------------------
    // SUB, and the absence of SUBI
    //-------------------------------------------------------------------------
    check_op("sub positive",  `FUNCT3_ADD_SUB, `FUNCT7_SUB_SRA,  1'b1,
             32'h0000_000A, 32'h0000_0004, 32'h0000_0006);
    check_op("sub negative",  `FUNCT3_ADD_SUB, `FUNCT7_SUB_SRA,  1'b1,
             32'h0000_0003, 32'h0000_0005, 32'hFFFF_FFFE);
    check_op("sub borrows",   `FUNCT3_ADD_SUB, `FUNCT7_SUB_SRA,  1'b1,
             32'h0000_0000, 32'h0000_0001, 32'hFFFF_FFFF);
    check_op("sub from sign", `FUNCT3_ADD_SUB, `FUNCT7_SUB_SRA,  1'b1,
             32'h8000_0000, 32'h0000_0001, 32'h7FFF_FFFF);
    // There is no SUBI: with an immediate operand this encoding has to add.
    check_op("addi not subi", `FUNCT3_ADD_SUB, `FUNCT7_SUB_SRA,  1'b0,
             32'h0000_000A, 32'h0000_0004, 32'h0000_000E);

    //-------------------------------------------------------------------------
    // Bitwise
    //-------------------------------------------------------------------------
    check_op("and", `FUNCT3_AND, `FUNCT7_ALU_NORM, 1'b1,
             32'hF0F0_F0F0, 32'h0FF0_0FF0, 32'h00F0_00F0);
    check_op("or",  `FUNCT3_OR,  `FUNCT7_ALU_NORM, 1'b1,
             32'hF0F0_F0F0, 32'h0FF0_0FF0, 32'hFFF0_FFF0);
    check_op("xor", `FUNCT3_XOR, `FUNCT7_ALU_NORM, 1'b1,
             32'hF0F0_F0F0, 32'h0FF0_0FF0, 32'hFF00_FF00);
    check_op("and with zero", `FUNCT3_AND, `FUNCT7_ALU_NORM, 1'b1,
             32'hDEAD_BEEF, 32'h0000_0000, 32'h0000_0000);
    check_op("xor with self", `FUNCT3_XOR, `FUNCT7_ALU_NORM, 1'b1,
             32'hDEAD_BEEF, 32'hDEAD_BEEF, 32'h0000_0000);

    //-------------------------------------------------------------------------
    // Shifts. The shift amount is the low five bits of the operand, so a count
    // of 33 has to behave as a count of 1.
    //-------------------------------------------------------------------------
    check_op("sll by 4",      `FUNCT3_SLL, `FUNCT7_ALU_NORM, 1'b1,
             32'h1234_5678, 32'h0000_0004, 32'h2345_6780);
    check_op("sll by 31",     `FUNCT3_SLL, `FUNCT7_ALU_NORM, 1'b1,
             32'h0000_0001, 32'h0000_001F, 32'h8000_0000);
    check_op("sll shamt mask",`FUNCT3_SLL, `FUNCT7_ALU_NORM, 1'b1,
             32'h0000_0001, 32'h0000_0021, 32'h0000_0002);
    check_op("sll drops top", `FUNCT3_SLL, `FUNCT7_ALU_NORM, 1'b1,
             32'hFFFF_FFFF, 32'h0000_0008, 32'hFFFF_FF00);

    check_op("srl by 8",      `FUNCT3_SRL_SRA, `FUNCT7_ALU_NORM, 1'b1,
             32'h1234_5678, 32'h0000_0008, 32'h0012_3456);
    check_op("srl of sign",   `FUNCT3_SRL_SRA, `FUNCT7_ALU_NORM, 1'b1,
             32'h8000_0000, 32'h0000_001F, 32'h0000_0001);
    check_op("srl fills zero",`FUNCT3_SRL_SRA, `FUNCT7_ALU_NORM, 1'b1,
             32'hFFFF_FF00, 32'h0000_0004, 32'h0FFF_FFF0);

    check_op("sra of sign",   `FUNCT3_SRL_SRA, `FUNCT7_SUB_SRA, 1'b1,
             32'h8000_0000, 32'h0000_001F, 32'hFFFF_FFFF);
    check_op("sra fills sign",`FUNCT3_SRL_SRA, `FUNCT7_SUB_SRA, 1'b1,
             32'hFFFF_FF00, 32'h0000_0004, 32'hFFFF_FFF0);
    check_op("sra of positive",`FUNCT3_SRL_SRA, `FUNCT7_SUB_SRA, 1'b1,
             32'h7FFF_FFFF, 32'h0000_0004, 32'h07FF_FFFF);
             
    // SRAI exists, so unlike SUB the alternate encoding still applies with an
    // immediate operand.
    check_op("srai",          `FUNCT3_SRL_SRA, `FUNCT7_SUB_SRA, 1'b0,
             32'hFFFF_FF00, 32'h0000_0004, 32'hFFFF_FFF0);

    //-------------------------------------------------------------------------
    // Comparisons. The same operands answer differently signed and unsigned,
    // which is where a missing $signed shows up.
    //-------------------------------------------------------------------------
    check_op("slt neg lt pos",  `FUNCT3_SLT,  `FUNCT7_ALU_NORM, 1'b1,
             32'hFFFF_FFFF, 32'h0000_0001, 32'h0000_0001);
    check_op("slt pos lt neg",  `FUNCT3_SLT,  `FUNCT7_ALU_NORM, 1'b1,
             32'h0000_0001, 32'hFFFF_FFFF, 32'h0000_0000);
    check_op("slt extremes",    `FUNCT3_SLT,  `FUNCT7_ALU_NORM, 1'b1,
             32'h8000_0000, 32'h7FFF_FFFF, 32'h0000_0001);
    check_op("slt equal",       `FUNCT3_SLT,  `FUNCT7_ALU_NORM, 1'b1,
             32'h0000_0007, 32'h0000_0007, 32'h0000_0000);
    check_op("slti",            `FUNCT3_SLT,  `FUNCT7_ALU_NORM, 1'b0,
             32'hFFFF_FFFB, 32'h0000_0000, 32'h0000_0001);

    check_op("sltu neg gt pos", `FUNCT3_SLTU, `FUNCT7_ALU_NORM, 1'b1,
             32'hFFFF_FFFF, 32'h0000_0001, 32'h0000_0000);
    check_op("sltu pos lt neg", `FUNCT3_SLTU, `FUNCT7_ALU_NORM, 1'b1,
             32'h0000_0001, 32'hFFFF_FFFF, 32'h0000_0001);
    check_op("sltu extremes",   `FUNCT3_SLTU, `FUNCT7_ALU_NORM, 1'b1,
             32'h8000_0000, 32'h7FFF_FFFF, 32'h0000_0000);
    check_op("sltu equal",      `FUNCT3_SLTU, `FUNCT7_ALU_NORM, 1'b1,
             32'h0000_0007, 32'h0000_0007, 32'h0000_0000);

    `TB_FINISH
end

endmodule

`default_nettype wire
