`timescale 1ns / 1ps
`default_nettype none
/*****************************************************************************
 *  Author: Piotr Kadziela
 *  Description:
 *      Unit testbench for uartrx. Frames are driven onto the line one bit at a
 *      time and the received byte is checked against what was sent.
 *      Also covers the two ways a frame can go wrong: a stop bit that is not
 *      high, which has to raise rx_error, and a glitch on an idle line, which
 *      has to be discarded without reporting anything at all.
 *****************************************************************************/

`include "tb_utils.svh"

module uartrx_tb;

`TB_VARS
`TB_TIMEOUT(50000)

localparam CLK_HZ    = 1_000_000;
localparam BAUD      = 125_000;
localparam DIVISOR   = CLK_HZ / BAUD;   // 8 clocks per bit
localparam CLK_NS    = 10;
localparam BIT_NS    = DIVISOR * CLK_NS;

logic           clk;
logic           rst_n;
logic           rx;
logic  [7:0]    rx_data;
logic           rx_valid;
logic           rx_error;

int             valid_count;
int             error_count;
logic  [7:0]    last_byte;

uartrx #(
    .CLK_HZ(CLK_HZ),
    .BAUD(BAUD)
) dut (
    .clk(clk),
    .rst_n(rst_n),
    .rx(rx),
    .rx_data(rx_data),
    .rx_valid(rx_valid),
    .rx_error(rx_error)
);

initial begin
    clk = 1'b0;
    forever #(CLK_NS / 2) clk = ~clk;
end

// Counts the pulses the receiver produces, so the checks can look at what
// happened over a whole frame rather than at one instant.
always_ff @(posedge clk) begin
    if (!rst_n) begin
        valid_count <= 0;
        error_count <= 0;
        last_byte   <= 8'h00;
    end
    else begin
        if (rx_valid) begin
            valid_count <= valid_count + 1;
            last_byte   <= rx_data;
        end
        if (rx_error) error_count <= error_count + 1;
    end
end

// Drives one frame. stop_bit is a parameter so that a broken frame can be
// sent as easily as a good one.
task automatic send_frame(input logic [7:0] value, input logic stop_bit);
    rx = 1'b0;                  // start bit
    #(BIT_NS);
    for (int i = 0; i < 8; i++) begin
        rx = value[i];          // least significant bit first
        #(BIT_NS);
    end
    rx = stop_bit;
    #(BIT_NS);
    rx = 1'b1;                  // back to idle
endtask

initial begin
    rst_n = 1'b0;
    rx    = 1'b1;               // an idle line sits high

    repeat (4) @(negedge clk);
    rst_n = 1'b1;
    repeat (2) @(negedge clk);

    // A byte with bits set at both ends, so a reversed bit order shows up.
    send_frame(8'h55, 1'b1);
    #(BIT_NS);
    `CHECK_EQ(valid_count, 1, "0x55 reported once")
    `CHECK_EQ(last_byte, 8'h55, "0x55 received")
    `CHECK_EQ(error_count, 0, "0x55 raised no error")

    send_frame(8'hA3, 1'b1);
    #(BIT_NS);
    `CHECK_EQ(valid_count, 2, "0xA3 reported once")
    `CHECK_EQ(last_byte, 8'hA3, "0xA3 received")

    send_frame(8'h00, 1'b1);
    #(BIT_NS);
    `CHECK_EQ(last_byte, 8'h00, "0x00 received")

    send_frame(8'hFF, 1'b1);
    #(BIT_NS);
    `CHECK_EQ(last_byte, 8'hFF, "0xFF received")
    `CHECK_EQ(error_count, 0, "four good frames raised no error")
    `CHECK_EQ(valid_count, 4, "four good frames reported four bytes")

    // A stop bit that is not high means the baud rates disagree.
    send_frame(8'h5A, 1'b0);
    #(BIT_NS);
    `CHECK_EQ(error_count, 1, "bad stop bit reported")
    `CHECK_EQ(valid_count, 4, "bad frame delivered no byte")

    // A pulse far shorter than a bit is noise, not a start bit.
    rx = 1'b0;
    #(BIT_NS / 4);
    rx = 1'b1;
    #(BIT_NS * 12);
    `CHECK_EQ(valid_count, 4, "glitch delivered no byte")
    `CHECK_EQ(error_count, 1, "glitch raised no error")

    `TB_FINISH
end

endmodule

`default_nettype wire
