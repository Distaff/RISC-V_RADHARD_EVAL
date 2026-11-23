`timescale 1ns / 1ps
`default_nettype none
/*****************************************************************************
 *  Author: Piotr Kadziela (AI Generated)
 *  Description:
 *      Unit testbench for mul. Products are worked out by hand and written
 *      into the vectors.
 *      The three high-half variants differ only in how the operands are
 *      interpreted, so several vectors deliberately reuse the same operand
 *      pair across MULH, MULHSU and MULHU - an implementation that confuses
 *      two of them cannot pass all three.
 *****************************************************************************/

`include "opcodes.svh"
`include "tb_utils.svh"

module mul_tb;

`TB_VARS
`TB_TIMEOUT(20000)

localparam WAIT_CYCLES = 64;    // how long a product may take before giving up

logic           clk;
logic           rst_n;
logic           start;
logic  [2:0]    funct3;
logic [31:0]    op_a;
logic [31:0]    op_b;
logic [31:0]    result;
logic           done;

mul dut (
    .clk(clk),
    .rst_n(rst_n),
    .start(start),
    .funct3(funct3),
    .op_a(op_a),
    .op_b(op_b),
    .result(result),
    .done(done)
);

initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
end

// Starts one multiply and waits for it, giving up rather than blocking if the
// unit never reports completion.
task automatic check_mul(
    input string       name,
    input logic  [2:0] f3,
    input logic [31:0] a,
    input logic [31:0] b,
    input logic [31:0] expected
);
    int waited;

    @(negedge clk);
    funct3 = f3;
    op_a   = a;
    op_b   = b;
    start  = 1'b1;
    @(negedge clk);
    start  = 1'b0;

    waited = 0;
    // Compared against one rather than negated, so that an undriven done
    // counts as not finished instead of ending the wait immediately.
    while (done !== 1'b1 && waited < WAIT_CYCLES) begin
        @(posedge clk);
        #1;
        waited++;
    end

    if (waited >= WAIT_CYCLES) begin
        tb_errors++;
        tb_checks++;
        $display("  FAIL %m  %s: no done within %0d cycles", name, WAIT_CYCLES);
    end
    else begin
        `CHECK_EQ(result, expected, name)
    end
endtask

initial begin
    rst_n  = 1'b0;
    start  = 1'b0;
    funct3 = `FUNCT3_MUL;
    op_a   = 32'd0;
    op_b   = 32'd0;

    repeat (4) @(negedge clk);
    rst_n = 1'b1;
    repeat (2) @(negedge clk);

    //-------------------------------------------------------------------------
    // MUL returns the low half, so it is blind to signedness
    //-------------------------------------------------------------------------
    check_mul("mul small",     `FUNCT3_MUL, 32'h0000_0003, 32'h0000_0005, 32'h0000_000F);
    // 0x10000 * 0x10000 is 2^32 exactly, so the low half is empty
    check_mul("mul overflows", `FUNCT3_MUL, 32'h0001_0000, 32'h0001_0000, 32'h0000_0000);
    // -1 * -1 = 1
    check_mul("mul negatives", `FUNCT3_MUL, 32'hFFFF_FFFF, 32'hFFFF_FFFF, 32'h0000_0001);

    //-------------------------------------------------------------------------
    // MULH - both operands signed
    //-------------------------------------------------------------------------
    // -1 * -1 = 1, which needs none of the high half
    check_mul("mulh both neg",  `FUNCT3_MULH, 32'hFFFF_FFFF, 32'hFFFF_FFFF, 32'h0000_0000);
    // -1 * 1 = -1, so the high half is all ones
    check_mul("mulh mixed",     `FUNCT3_MULH, 32'hFFFF_FFFF, 32'h0000_0001, 32'hFFFF_FFFF);
    // -2^31 * 2 = -2^32
    check_mul("mulh min by two",`FUNCT3_MULH, 32'h8000_0000, 32'h0000_0002, 32'hFFFF_FFFF);

    //-------------------------------------------------------------------------
    // MULHU - both operands unsigned. The same pairs answer differently.
    //-------------------------------------------------------------------------
    // 2^31 * 2 = 2^32
    check_mul("mulhu min by two", `FUNCT3_MULHU, 32'h8000_0000, 32'h0000_0002, 32'h0000_0001);
    // 0xFFFFFFFF squared is 0xFFFFFFFE00000001
    check_mul("mulhu max",        `FUNCT3_MULHU, 32'hFFFF_FFFF, 32'hFFFF_FFFF, 32'hFFFF_FFFE);
    // 4294967295 * 2 = 0x1FFFFFFFE
    check_mul("mulhu max by two", `FUNCT3_MULHU, 32'hFFFF_FFFF, 32'h0000_0002, 32'h0000_0001);

    //-------------------------------------------------------------------------
    // MULHSU - rs1 signed, rs2 unsigned. Distinguished from MULH by the first
    // vector and from MULHU by the second.
    //-------------------------------------------------------------------------
    // 2 * 4294967295 = 0x1FFFFFFFE, where MULH would answer 0xFFFFFFFF
    check_mul("mulhsu pos by big", `FUNCT3_MULHSU, 32'h0000_0002, 32'hFFFF_FFFF, 32'h0000_0001);
    // -1 * 2 = -2, where MULHU would answer 0x00000001
    check_mul("mulhsu neg by two", `FUNCT3_MULHSU, 32'hFFFF_FFFF, 32'h0000_0002, 32'hFFFF_FFFF);
    // -1 * 4294967295 = -4294967295, which is 0xFFFFFFFF00000001
    check_mul("mulhsu neg by big", `FUNCT3_MULHSU, 32'hFFFF_FFFF, 32'hFFFF_FFFF, 32'hFFFF_FFFF);

    `TB_FINISH
end

endmodule

`default_nettype wire
