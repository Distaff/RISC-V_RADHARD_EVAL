`timescale 1ns / 1ps
`default_nettype none
/*****************************************************************************
 *  Author: Piotr Kadziela
 *  Description:
 *      AXI4-Lite interconnect with one master active at a time.
 *      There are multiple slaves, but one master at a time - either the core
 *      or the debug module.
 *      An address matching no slave is answered locally with DECERR and the
 *      slaves are left untouched.
 *****************************************************************************/

// TODO - check that Vivado elaborates the slave interface array. AMD
//        documents arrays of interfaces as unsupported; if it fails,
//        unroll it into five named ports.

module axil_xbar #(
    parameter NUM_SLV  = 5,
    parameter SLV_BASE = {NUM_SLV*32{1'b0}},    // per-slave base address, flattened
    parameter SLV_MASK = {NUM_SLV*32{1'b0}}     // per-slave address mask, flattened
) (
    input wire              clk,
    input wire              rst_n,

    input wire              dbg_active,         // high when the debug unit owns the bus

    axil_if.slave           core_axi,           // upstream: core load/store unit
    axil_if.slave           dbg_axi,            // upstream: debug unit
    axil_if.master          slv_axi [NUM_SLV]   // downstream: peripherals and memories
);

// TODO

endmodule

`default_nettype wire
