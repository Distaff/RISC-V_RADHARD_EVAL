`timescale 1ns / 1ps
`default_nettype none
/*****************************************************************************
 *  Author: Piotr Kadziela
 *  Description:
 *      MCU top level. Takes a clean clock and a synchronous reset and exposes
 *      plain signals; everything board specific lives in 'boards/'.
 *      Uses modified Harvard Architecture: instruction fetch has a dedicated 
 *      port into port A of the IMEM, while port B of the same memory is a bus 
 *      slave. The IMEM is mapped onto the bus, but unless debug module takes 
 *      the bus, it is read-only.
 *      Address map, decoded on the two most significant bits:
 *          00  0x0000_0000 - 0x3FFF_FFFF  data memory
 *          01  0x4000_0000 - 0x7FFF_FFFF  instruction memory
 *          1x  0x8000_0000 - 0xFFFF_FFFF  peripherals
 *      Only the populated part of each window decodes. The rest answers
 *      DECERR.
 *****************************************************************************/

module toplevel #(
    parameter CLK_HZ            = 50_000_000,
    parameter BAUD              = 115200,

    parameter IMEM_SIZE_WORDS   = 8192,     // 32 KB, must be a power of two
    parameter DMEM_SIZE_WORDS   = 16384,    // 64 KB, must be a power of two
    parameter IMEM_INIT_FILE    = ""        // selftest image, runs when no debugger is attached
) (
    input wire              clk,
    input wire              rst_n,

    // Terminal UART - the only I/O the running program has
    input wire              term_uart_rx,
    output logic            term_uart_tx,

    // Debug link - transport for the debug unit, not a bus peripheral
    input wire              dbg_uart_rx,
    output logic            dbg_uart_tx,

    // PMOD general purpose I/O, tristate buffers live in the board wrapper
    output logic  [7:0]     gpio_o,
    output logic  [7:0]     gpio_oe,
    input wire    [7:0]     gpio_i,

    output logic  [3:0]     status_led  // running, stopped, debug active, error latched
);

import debug_pkg::*;
import axil_pkg::*;

//=============================================================================
// ADDRESS MAP
//=============================================================================

localparam NUM_SLV      = 5;

localparam DMEM_BASE    = 32'h0000_0000;
localparam DMEM_MASK    = 32'hFFFF_0000;    // 64 KB
localparam IMEM_BASE    = 32'h4000_0000;
localparam IMEM_MASK    = 32'hFFFF_8000;    // 32 KB
localparam TERM_BASE    = 32'h8000_0000;
localparam TERM_MASK    = 32'hFFFF_0000;
localparam TIMER_BASE   = 32'h8002_0000;
localparam TIMER_MASK   = 32'hFFFF_0000;
localparam GPIO_BASE    = 32'h8003_0000;
localparam GPIO_MASK    = 32'hFFFF_0000;

// Slave 0 occupies the low 32 bits of the flattened parameter, so the
// concatenation runs from the highest index down to the lowest.
// 0x8001_0000 is unassigned.
localparam SLV_BASE = {GPIO_BASE, TIMER_BASE, TERM_BASE, IMEM_BASE, DMEM_BASE};
localparam SLV_MASK = {GPIO_MASK, TIMER_MASK, TERM_MASK, IMEM_MASK, DMEM_MASK};

localparam SLV_DMEM  = 0;
localparam SLV_IMEM  = 1;
localparam SLV_TERM  = 2;
localparam SLV_TIMER = 3;
localparam SLV_GPIO  = 4;

//=============================================================================
// BUSES
//=============================================================================

axil_if     core_axi (.clk(clk), .rst_n(rst_n));           // core load/store unit
axil_if     dbg_axi (.clk(clk), .rst_n(rst_n));            // debug unit
axil_if     slv_axi [NUM_SLV] (.clk(clk), .rst_n(rst_n));  // one per slave

debug_if    dbg ();                 // debug sideband to the core

//=============================================================================
// CORE AND DEBUG UNIT
//=============================================================================

logic           instr_en;
logic  [31:0]   instr_addr;
logic  [31:0]   instr_data;
logic           instr_valid;

logic   [7:0]   err_flags;
logic           err_clear;

logic           dbg_active;
logic           core_rst_n;

// The bus belongs to the debug unit whenever the core is not executing.
assign dbg_active = (dbg.state != CORE_RUNNING);

// A debug-requested reset must not disturb the memories, otherwise the
// program would have to be uploaded again for every run.
assign core_rst_n = rst_n && !dbg.core_rst_req;

core #(
    .RESET_VECTOR(IMEM_BASE)
) cpu1 (
    .clk(clk),
    .rst_n(core_rst_n),

    .instr_en(instr_en),
    .instr_addr(instr_addr),
    .instr_data(instr_data),
    .instr_valid(instr_valid),

    .data_axi(core_axi),

    .dbg(dbg)
);

dbgtoplevel #(
    .CLK_HZ(CLK_HZ),
    .BAUD(BAUD)
) dbgtop (
    .clk(clk),
    .rst_n(rst_n),

    .uart_rx(dbg_uart_rx),
    .uart_tx(dbg_uart_tx),

    .dbg_axi(dbg_axi),

    .dbg(dbg),

    .err_flags(err_flags),
    .err_clear(err_clear)
);

axil_xbar #(
    .NUM_SLV(NUM_SLV),
    .SLV_BASE(SLV_BASE),
    .SLV_MASK(SLV_MASK)
) xbar1 (
    .clk(clk),
    .rst_n(rst_n),

    .dbg_active(dbg_active),

    .core_axi(core_axi),
    .dbg_axi(dbg_axi),
    .slv_axi(slv_axi)
);

//=============================================================================
// INSTRUCTION MEMORY
//=============================================================================

logic           imem_b_en;
logic  [31:0]   imem_b_addr;
logic  [31:0]   imem_b_rdata;
logic  [31:0]   imem_b_wdata;
logic    [3:0]  imem_b_wstrb;

memory #(
    .MEMORY_SIZE_WORDS(IMEM_SIZE_WORDS),
    .INIT_FILE(IMEM_INIT_FILE)
) imem (
    .clk(clk),

    .a_en(instr_en),
    .a_addr(instr_addr),
    .a_data(instr_data),

    .b_en(imem_b_en),
    .b_addr(imem_b_addr),
    .b_data(imem_b_rdata),
    .b_wdata(imem_b_wdata),
    .b_wstrb(imem_b_wstrb)
);

memory_axil imem_axi (
    .clk(clk),
    .rst_n(rst_n),

    .write_lock(!dbg_active),   // the running program may not modify its own code

    .axi(slv_axi[SLV_IMEM]),

    .mem_en(imem_b_en),
    .mem_addr(imem_b_addr),
    .mem_rdata(imem_b_rdata),
    .mem_wdata(imem_b_wdata),
    .mem_wstrb(imem_b_wstrb)
);

//=============================================================================
// DATA MEMORY
//=============================================================================

logic           dmem_b_en;
logic  [31:0]   dmem_b_addr;
logic  [31:0]   dmem_b_rdata;
logic  [31:0]   dmem_b_wdata;
logic    [3:0]  dmem_b_wstrb;

memory #(
    .MEMORY_SIZE_WORDS(DMEM_SIZE_WORDS)
) dmem (
    .clk(clk),

    .a_en(1'b0),        // port A is unused here, fetch never targets data memory
    .a_addr(32'b0),
    .a_data(),

    .b_en(dmem_b_en),
    .b_addr(dmem_b_addr),
    .b_data(dmem_b_rdata),
    .b_wdata(dmem_b_wdata),
    .b_wstrb(dmem_b_wstrb)
);

memory_axil dmem_axi (
    .clk(clk),
    .rst_n(rst_n),

    .write_lock(1'b0),

    .axi(slv_axi[SLV_DMEM]),

    .mem_en(dmem_b_en),
    .mem_addr(dmem_b_addr),
    .mem_rdata(dmem_b_rdata),
    .mem_wdata(dmem_b_wdata),
    .mem_wstrb(dmem_b_wstrb)
);

//=============================================================================
// PERIPHERALS
//=============================================================================

uart_term #(
    .CLK_HZ(CLK_HZ),
    .BAUD(BAUD)
) term0 (
    .clk(clk),
    .rst_n(rst_n),

    .axi(slv_axi[SLV_TERM]),

    .uart_rx(term_uart_rx),
    .uart_tx(term_uart_tx)
);

timer_axil tim0 (
    .clk(clk),
    .rst_n(rst_n),

    .axi(slv_axi[SLV_TIMER])
);

pmod_gpio #(
    .WIDTH(8)
) gpio0 (
    .clk(clk),
    .rst_n(rst_n),

    .axi(slv_axi[SLV_GPIO]),

    .pin_o(gpio_o),
    .pin_oe(gpio_oe),
    .pin_i(gpio_i)
);

//=============================================================================
// ERROR MANAGER
//=============================================================================

localparam ERR_CORE_BUS = 0;    // core access answered SLVERR or DECERR
localparam ERR_DBG_BUS  = 1;    // debug access answered SLVERR or DECERR
localparam ERR_CORE     = 2;    // core stopped in CORE_ERROR

logic core_bus_err;
logic dbg_bus_err;

assign core_bus_err = (core_axi.bvalid && core_axi.bready && core_axi.bresp != RESP_OKAY)
                   || (core_axi.rvalid && core_axi.rready && core_axi.rresp != RESP_OKAY);

assign dbg_bus_err  = (dbg_axi.bvalid && dbg_axi.bready && dbg_axi.bresp != RESP_OKAY)
                   || (dbg_axi.rvalid && dbg_axi.rready && dbg_axi.rresp != RESP_OKAY);

always_ff @(posedge clk) begin
    if (!rst_n || err_clear) begin
        err_flags <= 8'b0;
    end
    else begin
        if (core_bus_err)                err_flags[ERR_CORE_BUS] <= 1'b1;
        if (dbg_bus_err)                 err_flags[ERR_DBG_BUS]  <= 1'b1;
        if (dbg.state == CORE_ERROR)     err_flags[ERR_CORE]     <= 1'b1;
    end
end

//=============================================================================
// STATUS
//=============================================================================

always_comb begin
    status_led[0] = (dbg.state == CORE_RUNNING);
    status_led[1] = (dbg.state == CORE_HALTED);
    status_led[2] = dbg_active;
    status_led[3] = |err_flags;
end

endmodule

`default_nettype wire
