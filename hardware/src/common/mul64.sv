`timescale 1ns / 1ps
`default_nettype none
/*****************************************************************************
 *  Author: Piotr Kadziela
 *  Description:
 *      Pipelined 33x33 signed multiplier, returning the lower 64 bits of the 
 *      product. Latency of four cycles. Tries to trigger use of DSPs.
 *****************************************************************************/

module mul64 (
    input wire                  clk,

    input wire signed [32:0]    a_in,
    input wire signed [32:0]    b_in,
    output logic      [63:0]    p_out
);

logic signed [32:0] a, b;

(* use_dsp = "yes" *) logic signed [65:0] m_1, m_2, m_3;

// Mock logic to trigger retiming and register insetion into DSP.
always_ff @(posedge clk) begin
    a <= a_in;      // 1st cycle
    b <= b_in;

    m_1 <= a * b;   // 2nd cycle
    m_2 <= m_1;     // 3rd cycle
    m_3 <= m_2;     // 4th cycle
end

assign p_out = m_3[63:0];

endmodule

`default_nettype wire
