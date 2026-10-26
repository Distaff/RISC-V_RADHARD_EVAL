`timescale 1ns / 1ps
`default_nettype none
/*****************************************************************************
 *  Author: Piotr Kadziela
 *  Description:
 *      AXI4-Lite front end for the memory module, driving port B.
 *      While write_lock is high, writes are refused with SLVERR. Reads are
 *      unaffected.
 *      One transaction at a time, write before read. A write waits for both
 *      AW and W. Read data comes straight from the memory output register.
 *****************************************************************************/

module memory_axil (
    input wire              clk,
    input wire              rst_n,

    input wire              write_lock, // high refuses writes with SLVERR

    axil_if.slave           axi,

    // Port B of the memory instance
    output logic            mem_en,
    output logic [31:0]     mem_addr,
    input wire   [31:0]     mem_rdata,
    output logic [31:0]     mem_wdata,
    output logic  [3:0]     mem_wstrb
);

import axil_pkg::*;

typedef enum logic [1:0] {IDLE, WRITE_RESP, READ_DATA} state_t;

state_t state;
logic   write_start;
logic   read_start;

assign write_start = (state == IDLE) && axi.awvalid && axi.wvalid;
assign read_start  = (state == IDLE) && axi.arvalid && !write_start;

assign axi.awready = write_start;
assign axi.wready  = write_start;
assign axi.arready = read_start;

assign mem_en    = (write_start && !write_lock) || read_start;
assign mem_addr  = write_start ? axi.awaddr : axi.araddr;
assign mem_wdata = axi.wdata;
assign mem_wstrb = write_start ? axi.wstrb : 4'b0000;

// mem_rdata holds until the next mem_en, which cannot come before rready
assign axi.rvalid = (state == READ_DATA);
assign axi.rdata  = mem_rdata;
assign axi.rresp  = RESP_OKAY;
assign axi.bvalid = (state == WRITE_RESP);

always_ff @(posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
    end
    else begin
        case (state)
            IDLE: begin
                if (write_start) begin
                    axi.bresp <= write_lock ? RESP_SLVERR : RESP_OKAY;
                    state     <= WRITE_RESP;
                end
                else if (read_start) begin
                    state     <= READ_DATA;
                end
            end
            WRITE_RESP: if (axi.bready) state <= IDLE;
            READ_DATA:  if (axi.rready) state <= IDLE;
            default:    state <= IDLE;
        endcase
    end
end

endmodule

`default_nettype wire
