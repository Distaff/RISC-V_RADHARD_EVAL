`timescale 1ns / 1ps
`default_nettype none
/*****************************************************************************
 *  Author: Piotr Kadziela
 *  Description:
 *      Load/store unit for the RISC-V core. Owns the core's AXI4-Lite master
 *      port and handles byte lanes: write data is shifted into the right lane
 *      and turned into WSTRB, read data is extracted from its lane and sign-
 *      or zero-extended according to funct3.
 *      The core presents a request and waits for done, so bus handshakes stay
 *      out of the core state machine.
 *****************************************************************************/

// TODO - misaligned accesses are not detected; needs a trap once the CSRs exist

`include "opcodes.svh"

module axil_lsu (
    input wire              clk,
    input wire              rst_n,

    // Core interface
    input wire              req,        // start an access, held until done
    input wire              we,         // high for a store, low for a load
    input wire   [2:0]      funct3,     // access width and signedness
    input wire  [31:0]      addr,       // byte address
    input wire  [31:0]      wdata,      // data to store, right aligned
    output logic [31:0]     rdata,      // loaded data, extended to 32 bits
    output logic            done,       // one-cycle pulse, access finished

    // Data bus
    axil_if.master          data_axi
);

// TODO

endmodule

`default_nettype wire
