`timescale 1ns / 1ps
`default_nettype none
/*****************************************************************************
 *  Author: Piotr Kadziela
 *  Description:
 *      RV32I_Zmmul_Zicsr core, multicycle with a variable-length instruction
 *      cycle - the number of clock ticks depends on the instruction class.
 *      Instruction fetch uses a dedicated port into port A of the instruction
 *      memory. Data accesses go through axil_lsu, which is the core's only bus
 *      master.
 *      The core can be halted only on an instruction boundary. A halt request
 *      is latched, the current instruction and its bus transaction are
 *      finished, and then the core reports CORE_HALTED on the dbg bus.
 *****************************************************************************/

// TODO - JALR writes pc + 4 into rd; RIVER masked rs1 + imm with 2 instead
// TODO - wait for regfile rst_ready before the first fetch
// TODO - pc and instr_en belong in the reset list
// TODO - unsupported opcodes have to land in CORE_ERROR, not spin

module core #(
    parameter RESET_VECTOR = 32'h4000_0000
) (
    input wire              clk,
    input wire              rst_n,

    // Instruction fetch port, wired to port A of the instruction memory
    output logic            instr_en,       // read enable
    output logic [31:0]     instr_addr,     // 32-bit address, follows PC
    input wire   [31:0]     instr_data,     // 32-bits of data
    input wire              instr_valid,    // instr_data is valid this cycle

    // Data bus
    axil_if.master          data_axi,

    // Debug bus
    debug_if.target         dbg
);

// TODO

endmodule

`default_nettype wire
