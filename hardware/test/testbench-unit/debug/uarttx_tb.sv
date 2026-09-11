`timescale 1ns / 1ps
`default_nettype none
/*****************************************************************************
 *  Author: Piotr Kadziela
 *  Description:
 *      Unit testbench for uarttx. The serial line is sampled at the centre of
 *      each bit and compared against the frame the byte should produce: a low
 *      start bit, eight data bits least significant first, then a high stop
 *      bit.
 *      CLK_HZ and BAUD are chosen to give a short bit period, so the frames
 *      pass quickly; the ratio between them is what the module actually uses.
 *****************************************************************************/

`include "tb_utils.svh"

module uarttx_tb;

`TB_VARS
`TB_TIMEOUT(50000)

localparam CLK_HZ    = 1_000_000;
localparam BAUD      = 125_000;
localparam DIVISOR   = CLK_HZ / BAUD;   // 8 clocks per bit
localparam CLK_NS    = 10;
localparam BIT_NS    = DIVISOR * CLK_NS;

logic           clk;
logic           rst_n;
logic  [7:0]    tx_data;
logic           tx_start;
logic           tx_busy;
logic           tx;

uarttx #(
    .CLK_HZ(CLK_HZ),
    .BAUD(BAUD)
) dut (
    .clk(clk),
    .rst_n(rst_n),
    .tx_data(tx_data),
    .tx_start(tx_start),
    .tx_busy(tx_busy),
    .tx(tx)
);

initial begin
    clk = 1'b0;
    forever #(CLK_NS / 2) clk = ~clk;
end

// Sends one byte and checks the frame that appears on the line.
task automatic check_frame(input string name, input logic [7:0] value);
    @(negedge clk);
    tx_data  = value;
    tx_start = 1'b1;
    @(negedge clk);
    tx_start = 1'b0;

    // The start bit begins on the cycle the byte is latched; move to its
    // centre and step a whole bit period from there.
    #(BIT_NS / 2);
    `CHECK_EQ(tx, 1'b0, {name, ": start bit low"})

    for (int i = 0; i < 8; i++) begin
        #(BIT_NS);
        `CHECK_EQ(tx, value[i], {name, ": data bit"})
    end

    #(BIT_NS);
    `CHECK_EQ(tx, 1'b1, {name, ": stop bit high"})
endtask

initial begin
    rst_n    = 1'b0;
    tx_data  = 8'h00;
    tx_start = 1'b0;

    repeat (4) @(negedge clk);
    `CHECK_EQ(tx, 1'b1, "line idles high in reset")

    rst_n = 1'b1;
    repeat (2) @(negedge clk);
    `CHECK_EQ(tx_busy, 1'b0, "not busy when idle")

    // A byte with both a set and a clear bit at each end, so a reversed
    // bit order would show up.
    check_frame("0x55", 8'h55);

    // Wait out the stop bit before the next frame.
    #(BIT_NS);
    `CHECK_EQ(tx_busy, 1'b0, "not busy once the frame ends")

    check_frame("0xA3", 8'hA3);
    #(BIT_NS);

    check_frame("0x00", 8'h00);
    #(BIT_NS);

    check_frame("0xFF", 8'hFF);
    #(BIT_NS);

    `TB_FINISH
end

endmodule

`default_nettype wire
