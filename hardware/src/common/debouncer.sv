`timescale 1ns / 1ps
`default_nettype none
/*****************************************************************************
 *  Author: Piotr Kadziela
 *  Description:
 *      A generic debouncer module for mechanical switches. Uses internal
 *      prescaler.
 *      The switch input is synchronised inside the module.
 *      The filter is active high and needs CONSECUTIVE_SAMPLES agreeing
 *      samples to change state. An active low button has to be inverted before
 *      this module, otherwise it produces a rising edge shortly after reset.
 *****************************************************************************/

module debouncer #(
    parameter PRESCALER_DIV       = 10000,                  // prescaler division factor (assuming clk is in kHz, 10000 = one sample for every 10ms)
    parameter CONSECUTIVE_SAMPLES = 16                      // number of consecutive stable samples needed to change output state
) (
    input wire              clk,
    input wire              rst_n,

    input wire              sw_in,          // raw input from the mechanical switch
    output logic            sw_out,         // debounced output
    output logic            sw_pulse,       // debounced output (one clock pulse on positive edge of sw_out)
    output logic            sw_negpulse     // debounced output (one clock pulse on negative edge of sw_out)
);

localparam PRESCALER_WIDTH = $clog2(PRESCALER_DIV);

logic   [CONSECUTIVE_SAMPLES-1:0]   shift_reg;
logic   [PRESCALER_WIDTH-1:0]       prescaler_cnt;
logic                               sw_sync;

ff2 sw_ff2 (
    .clk(clk),
    .rst_n(rst_n),
    .async_in(sw_in),
    .sync_out(sw_sync)
);

always_ff @(posedge clk) begin
    if (!rst_n) begin
        shift_reg     <= '0;
        prescaler_cnt <= '0;
        sw_out        <= 1'b0;
        sw_pulse      <= 1'b0;
        sw_negpulse   <= 1'b0;
    end
    else begin
        // Both pulses default to low so that every path drives them; leaving
        // them to hold would keep a pulse asserted for a whole sample period
        // whenever PRESCALER_DIV is 1.
        sw_pulse    <= 1'b0;
        sw_negpulse <= 1'b0;

        if (prescaler_cnt == PRESCALER_DIV - 1) begin
            prescaler_cnt <= '0;

            shift_reg <= {shift_reg[CONSECUTIVE_SAMPLES-2:0], sw_sync};

            if (shift_reg == {CONSECUTIVE_SAMPLES{1'b1}}) begin
                sw_out   <= 1'b1;
                sw_pulse <= ~sw_out;        // only high on rising edge of sw_out
            end
            else if (shift_reg == {CONSECUTIVE_SAMPLES{1'b0}}) begin
                sw_out      <= 1'b0;
                sw_negpulse <= sw_out;      // only high on falling edge of sw_out
            end
        end
        else begin
            prescaler_cnt <= prescaler_cnt + 1;
        end
    end
end

endmodule

`default_nettype wire
