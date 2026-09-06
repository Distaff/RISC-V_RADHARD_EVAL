`timescale 1ns / 1ps
/*****************************************************************************
 *  Author: Piotr Kadziela
 *  Description:
 *      Core state encoding shared between the core and the debug unit.
 *****************************************************************************/

package debug_pkg;

    typedef enum logic [1:0] {
        CORE_RUNNING = 2'b00,   // executing
        CORE_HALTED  = 2'b01,   // stopped on request, on a step, or on an ebreak
        CORE_ERROR   = 2'b10    // stopped on something it cannot continue past
    } core_state_t;

    localparam REG_SEL_PC = 6'd32;  // reg_sel value that addresses the program counter

endpackage
