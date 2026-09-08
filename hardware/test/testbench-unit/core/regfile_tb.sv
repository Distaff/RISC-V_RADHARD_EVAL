`timescale 1ns / 1ps
`default_nettype none
/*****************************************************************************
 *  Author: Piotr Kadziela
 *  Description:
 *      Unit testbench for regfile. Covers the clearing sequence and its
 *      length, that x0 stays zero whatever is written to it, and that the two
 *      read ports work independently.
 *      The clearing sequence is timed exactly rather than merely waited for,
 *      because a file that reports ready too early would let the core run over
 *      registers that are still being zeroed.
 *****************************************************************************/

`include "tb_utils.svh"

module regfile_tb;

`TB_VARS
`TB_TIMEOUT(20000)

logic           clk;
logic           rst_n;
logic           rst_ready;
logic  [4:0]    r_sel_1;
logic  [4:0]    r_sel_2;
logic [31:0]    r_data_1;
logic [31:0]    r_data_2;
logic           w_en;
logic  [4:0]    w_sel;
logic [31:0]    w_data;

int             clear_cycles;

regfile dut (
    .clk(clk),
    .rst_n(rst_n),
    .rst_ready(rst_ready),
    .r_sel_1(r_sel_1),
    .r_sel_2(r_sel_2),
    .r_data_1(r_data_1),
    .r_data_2(r_data_2),
    .w_en(w_en),
    .w_sel(w_sel),
    .w_data(w_data)
);

initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
end

// Writes one register on the next clock edge.
task automatic write_reg(input logic [4:0] sel, input logic [31:0] value);
    @(negedge clk);
    w_en   = 1'b1;
    w_sel  = sel;
    w_data = value;
    @(negedge clk);
    w_en   = 1'b0;
endtask

// Reads are asynchronous, so selecting is enough.
task automatic read_reg(input logic [4:0] sel, output logic [31:0] value);
    r_sel_1 = sel;
    #1;
    value = r_data_1;
endtask

logic [31:0] value;

initial begin
    rst_n   = 1'b0;
    w_en    = 1'b0;
    w_sel   = 5'd0;
    w_data  = 32'd0;
    r_sel_1 = 5'd0;
    r_sel_2 = 5'd0;

    repeat (2) @(negedge clk);
    `CHECK_EQ(rst_ready, 1'b0, "not ready while in reset")

    rst_n = 1'b1;

    // The file holds 32 registers and clears one per cycle, so readiness has
    // to arrive exactly 32 clocks after reset is released.
    clear_cycles = 0;
    while (!rst_ready) begin
        @(posedge clk);
        clear_cycles++;
        #1;     // let the edge settle before looking at the flag it sets
    end
    `CHECK_EQ(clear_cycles, 32, "clearing takes one cycle per register")

    // Everything reads as zero once the sequence has finished.
    read_reg(5'd0,  value);
    `CHECK_EQ(value, 32'h0000_0000, "x0 cleared")
    read_reg(5'd17, value);
    `CHECK_EQ(value, 32'h0000_0000, "x17 cleared")
    read_reg(5'd31, value);
    `CHECK_EQ(value, 32'h0000_0000, "x31 cleared")

    // Ordinary write and read back.
    write_reg(5'd5, 32'hDEAD_BEEF);
    read_reg(5'd5, value);
    `CHECK_EQ(value, 32'hDEAD_BEEF, "write then read x5")

    // x0 is hardwired to zero and must ignore writes.
    write_reg(5'd0, 32'hFFFF_FFFF);
    read_reg(5'd0, value);
    `CHECK_EQ(value, 32'h0000_0000, "write to x0 ignored")

    // A write with the enable low must not land.
    @(negedge clk);
    w_en   = 1'b0;
    w_sel  = 5'd6;
    w_data = 32'h1234_5678;
    @(negedge clk);
    read_reg(5'd6, value);
    `CHECK_EQ(value, 32'h0000_0000, "write ignored without enable")

    // Both ports read at once, from different registers.
    write_reg(5'd12, 32'h1111_2222);
    r_sel_1 = 5'd5;
    r_sel_2 = 5'd12;
    #1;
    `CHECK_EQ(r_data_1, 32'hDEAD_BEEF, "port 1 reads x5")
    `CHECK_EQ(r_data_2, 32'h1111_2222, "port 2 reads x12")

    `TB_FINISH
end

endmodule

`default_nettype wire
