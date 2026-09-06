`timescale 1ns / 1ps
`default_nettype none
/*****************************************************************************
 *  Author: Piotr Kadziela
 *  Description:
 *      Sideband between the debug unit and the core, carrying run control and
 *      register file access. Everything that reaches memory or peripherals
 *      goes over AXI instead.
 *      Run control is request based. The core only stops on an instruction
 *      boundary, so a request is latched and acted on at the next cycle_end.
 *      Register access reuses the rs1 read port of the register file, which is
 *      idle whenever the core is not running. reg_sel is six bits wide: 0-31
 *      select x0-x31, 32 selects the program counter.
 *      Register writes are only honoured while the core is stopped. Enforcing
 *      that is the core's job.
 *****************************************************************************/

interface debug_if;

import debug_pkg::*;

// Run control, driven by the debug unit
logic           halt_req;       // one-cycle pulse, stop at the next instruction boundary
logic           resume_req;     // one-cycle pulse, leave the stopped state
logic           step_req;       // one-cycle pulse, execute one instruction and stop again
logic           core_rst_req;   // level, resets the core without touching the memories

// Status, driven by the core
core_state_t    state;
logic           cycle_end;      // high on the last tick of an instruction cycle

// Register file access, driven by the debug unit
logic    [5:0]  reg_sel;        // 0-31 select x0-x31, REG_SEL_PC selects the program counter
logic   [31:0]  reg_wdata;
logic           reg_we;         // one-cycle pulse, ignored unless the core is stopped

// Register file access, driven by the core
logic   [31:0]  reg_rdata;

modport target (
    input   halt_req, resume_req, step_req, core_rst_req, reg_sel, reg_wdata, reg_we,
    output  state, cycle_end, reg_rdata
);

modport host (
    output  halt_req, resume_req, step_req, core_rst_req, reg_sel, reg_wdata, reg_we,
    input   state, cycle_end, reg_rdata
);

endinterface

`default_nettype wire
