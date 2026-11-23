`timescale 1ns / 1ps
/*****************************************************************************
 *  Author: Piotr Kadziela
 *  Description:
 *      AXI4-Lite response codes, shared by masters, slaves and monitors.
 *****************************************************************************/

package axil_pkg;

    // Response codes, shared by the B and R channels
    typedef enum logic [1:0] {
        AXIL_RESP_OKAY   = 2'b00,
        AXIL_RESP_EXOKAY = 2'b01,       // exclusive access, not used in AXI4-Lite
        AXIL_RESP_SLVERR = 2'b10,       // slave reached, slave refused
        AXIL_RESP_DECERR = 2'b11        // no slave at this address
    } axil_resp_t;

endpackage
