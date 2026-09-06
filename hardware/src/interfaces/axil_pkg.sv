`timescale 1ns / 1ps
/*****************************************************************************
 *  Author: Piotr Kadziela
 *  Description:
 *      AXI4-Lite response codes, shared by masters, slaves and monitors.
 *****************************************************************************/

package axil_pkg;

    // Response codes, shared by the B and R channels
    localparam RESP_OKAY   = 2'b00;
    localparam RESP_EXOKAY = 2'b01;     // exclusive access, not used in AXI4-Lite
    localparam RESP_SLVERR = 2'b10;     // slave reached, slave refused
    localparam RESP_DECERR = 2'b11;     // no slave at this address

endpackage
