`timescale 1ns / 1ps
`default_nettype none
/*****************************************************************************
 *  Author: Piotr Kadziela
 *  Description:
 *      Zybo board wrapper: pin names, MMCM, tristate buffers and the reset
 *      button. The MCU below it only sees a clean clock and a synchronous
 *      reset.
 *      Clocking, from the 125 MHz board oscillator:
 *          f_PFD = 125 MHz / DIVCLK_DIVIDE = 25 MHz
 *          f_VCO = f_PFD * CLKFBOUT_MULT_F = 1000 MHz (must stay 600-1200)
 *          f_OUT = f_VCO / CLKOUT1_DIVIDE  = 50 MHz
 *      Reset is released once the MMCM has locked and is then held for a few
 *      more cycles. The button is not debounced separately - the hold is
 *      enough for a reset line.
 *****************************************************************************/

module zybo_top (
    input  wire logic           SYS_CLK,        // 125 MHz board oscillator
    input  wire logic           BTN_RST,        // reset button, active high

    input  wire logic           TERM_UART_RX,   // terminal link, to the program
    output logic                TERM_UART_TX,
    input  wire logic           DBG_UART_RX,    // debug link, to the debug unit
    output logic                DBG_UART_TX,

    inout  wire logic   [7:0]   PMOD_JE,        // general purpose I/O

    output logic        [3:0]   LED             // running, stopped, debug active, error
);

localparam CLK_HZ = 50_000_000;
localparam BAUD   = 115_200;

//=============================================================================
// CLOCK
//=============================================================================

logic   clk;
logic   clk_unbuf;
logic   feedback;
logic   locked;

MMCME2_BASE #(
    .CLKIN1_PERIOD(8.0),        // 125 MHz
    .DIVCLK_DIVIDE(5),
    .CLKFBOUT_MULT_F(40.0),
    .CLKOUT1_DIVIDE(20)
) mmcm (
    .CLKIN1(SYS_CLK),
    .RST(1'b0),
    .CLKOUT1(clk_unbuf),
    .LOCKED(locked),
    .CLKFBOUT(feedback),
    .CLKFBIN(feedback),
    .CLKOUT0(),
    .CLKOUT0B(),
    .CLKOUT1B(),
    .CLKOUT2(),
    .CLKOUT2B(),
    .CLKOUT3(),
    .CLKOUT3B(),
    .CLKOUT4(),
    .CLKOUT5(),
    .CLKOUT6(),
    .CLKFBOUTB(),
    .PWRDWN(1'b0)
);

BUFG bufg_clk (
    .I(clk_unbuf),
    .O(clk)
);

//=============================================================================
// RESET
//=============================================================================

logic           locked_sync;
logic           btn_rst_sync;
logic   [3:0]   rst_cnt;
logic           rst_n;

// Both synchronisers run without a reset of their own - there is no reset yet
// at this point. Configuration leaves their flip-flops at zero, which reads as
// "not locked, button not pressed" and is the safe starting point.
ff2 lock_ff2 (
    .clk(clk),
    .rst_n(1'b1),
    .async_in(locked),
    .sync_out(locked_sync)
);

ff2 btn_ff2 (
    .clk(clk),
    .rst_n(1'b1),
    .async_in(BTN_RST),
    .sync_out(btn_rst_sync)
);

always_ff @(posedge clk) begin
    if (!locked_sync || btn_rst_sync) rst_cnt <= '0;
    else if (!rst_cnt[3])             rst_cnt <= rst_cnt + 1;
end

assign rst_n = rst_cnt[3];

//=============================================================================
// GENERAL PURPOSE I/O
//=============================================================================

logic   [7:0]   gpio_o;
logic   [7:0]   gpio_oe;
logic   [7:0]   gpio_i;

genvar i;
generate
    for (i = 0; i < 8; i = i + 1) begin : g_pmod
        IOBUF pmod_buf (
            .O(gpio_i[i]),
            .IO(PMOD_JE[i]),
            .I(gpio_o[i]),
            .T(!gpio_oe[i])     // T high puts the pin in high impedance
        );
    end
endgenerate

//=============================================================================
// MCU
//=============================================================================

toplevel #(
    .CLK_HZ(CLK_HZ),
    .BAUD(BAUD)
) mcu (
    .clk(clk),
    .rst_n(rst_n),

    .term_uart_rx(TERM_UART_RX),
    .term_uart_tx(TERM_UART_TX),

    .dbg_uart_rx(DBG_UART_RX),
    .dbg_uart_tx(DBG_UART_TX),

    .gpio_o(gpio_o),
    .gpio_oe(gpio_oe),
    .gpio_i(gpio_i),

    .status_led(LED)
);

endmodule

`default_nettype wire
