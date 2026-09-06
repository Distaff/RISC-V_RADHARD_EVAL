`timescale 1ns / 1ps
`default_nettype none
/*****************************************************************************
 *  Author: Piotr Kadziela
 *  Description:
 *      Two-stage synchroniser for signals crossing into the clk domain.
 *      The first stage may go metastable but has a full clock period to
 *      settle; the second stage samples a settled value. Costs two flip-flops
 *      per bit and two cycles of latency.
 *****************************************************************************/

module ff2 #(
    parameter WIDTH      = 1,
    parameter logic RESET_VAL = 1'b0    // value held while rst_n is low
) (
    input wire                  clk,
    input wire                  rst_n,

    input wire  [WIDTH-1:0]     async_in,   // asynchronous input
    output logic [WIDTH-1:0]    sync_out    // synchronised output
);

// Keep the two stages out of the shift-register primitives: SRLs cannot be
// reset and the placer must be free to put stage 1 next to the pad.
(* ASYNC_REG = "TRUE" *) logic [WIDTH-1:0] stage1;
(* ASYNC_REG = "TRUE" *) logic [WIDTH-1:0] stage2;

always_ff @(posedge clk) begin
    if (!rst_n) begin
        stage1 <= {WIDTH{RESET_VAL}};
        stage2 <= {WIDTH{RESET_VAL}};
    end
    else begin
        stage1 <= async_in;
        stage2 <= stage1;
    end
end

assign sync_out = stage2;

endmodule

`default_nettype wire
