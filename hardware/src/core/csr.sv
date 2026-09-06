`timescale 1ns / 1ps
`default_nettype none
/*****************************************************************************
 *  Author: Piotr Kadziela
 *  Description:
 *      Control and status registers for the Zicsr extension.
 *      Implements the CSR access instructions and the machine-mode counters:
 *      mcycle, minstret and their high halves, plus mhartid and the read-only
 *      mvendorid, marchid, mimpid and misa.
 *****************************************************************************/

// TODO - trap CSRs: mtvec, mepc, mcause, mstatus, mtval, plus interrupts
// CSRRW with rd = x0 must not perform the read, and CSRRS/CSRRC with rs1 = x0 must not perform the write.

`include "opcodes.svh"

module csr #(
    parameter HART_ID = 32'h0000_0000
) (
    input wire              clk,
    input wire              rst_n,

    // Access from the core
    input wire              csr_en,         // an OP_SYSTEM instruction with a CSR funct3
    input wire  [11:0]      csr_addr,       // instr[31:20]
    input wire   [2:0]      funct3,         // selects read/write, set, clear and the immediate forms
    input wire   [4:0]      rd_sel,         // needed to suppress the read side effect when rd is x0
    input wire   [4:0]      rs1_sel,        // needed to suppress the write side effect when rs1 is x0
    input wire  [31:0]      wdata,          // rs1 contents, or the zero-extended 5-bit immediate
    output logic [31:0]     rdata,          // previous contents of the addressed CSR
    output logic            illegal,        // no such CSR, or a write to a read-only one

    // Counter events
    input wire              instr_retired   // one-cycle pulse per completed instruction
);

// TODO

endmodule

`default_nettype wire
