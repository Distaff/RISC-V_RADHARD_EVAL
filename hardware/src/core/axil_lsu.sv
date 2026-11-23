`timescale 1ns / 1ps
`default_nettype none
/*****************************************************************************
 *  Author: Piotr Kadziela
 *  Description:
 *      Load/store unit for the RISC-V core. Owns the core's AXI4-Lite master
 *      port and handles byte lanes.
 *      The core presents a request and waits for done, so bus handshakes stay
 *      out of the core state machine.
 *****************************************************************************/

// TODO - misaligned accesses are not detected; needs a trap once the CSRs exist

`include "opcodes.svh"

module axil_lsu (
    input wire              clk,
    input wire              rst_n,

    // Core interface
    input wire                  req,        // start an access, held until done
    input wire                  we,         // high for a store, low for a load
    input wire          [2:0]   funct3,     // access width and signedness
    input wire          [31:0]  addr,       // byte address
    input wire          [31:0]  wdata,      // data to store, right aligned
    output logic        [31:0]  rdata,      // loaded data, extended to 32 bits
    output logic                done,       // one-cycle pulse, access finished
    output axil_pkg::axil_resp_t resp,      // response from the AXI-Lite slave

    // Data bus
    axil_if.master          data_axi
);

import axil_pkg::*;

enum logic [2:0] {
    LSU_IDLE,
    LSU_READ_ADDR,
    LSU_READ_DATA,
    LSU_WRITE,
    LSU_WRITE_RESP
} state;

logic awready_received;
logic wready_received;

logic [1:0] offset;
assign offset = addr[1:0];
assign data_axi.awaddr = {addr[31:2], 2'b00};
assign data_axi.araddr = {addr[31:2], 2'b00};

assign data_axi.wvalid = (state == LSU_WRITE) && !wready_received;
assign data_axi.awvalid = (state == LSU_WRITE) && !awready_received;
assign data_axi.arvalid = (state == LSU_READ_ADDR);

assign data_axi.bready = (state == LSU_WRITE_RESP);
assign data_axi.rready = (state == LSU_READ_DATA);

assign done = (state == LSU_READ_DATA && data_axi.rvalid && data_axi.rready) ||
              (state == LSU_WRITE_RESP && data_axi.bvalid && data_axi.bready);

assign resp = (state == LSU_READ_DATA) ? data_axi.rresp :
              (state == LSU_WRITE_RESP) ? data_axi.bresp :
              AXIL_RESP_OKAY;

// ===============
//     WRITES
// ===============
always_comb begin
    case(funct3)
        `FUNCT3_SB: begin
            data_axi.wstrb = 4'b0001 << offset;
            data_axi.wdata = {4{wdata[7:0]}};
        end
        `FUNCT3_SH: begin
            data_axi.wstrb = 4'b0011 << offset;
            data_axi.wdata = {2{wdata[15:0]}};
        end
        `FUNCT3_SW: begin
            data_axi.wstrb = 4'b1111;
            data_axi.wdata = wdata;
        end
        default: begin
            data_axi.wstrb = 4'b0000;
            data_axi.wdata = 32'h0000_0000;
        end
    endcase
end

// ==============
//     READS
// ==============
logic [31:0] read_data;
assign read_data = data_axi.rdata >> (offset * 8);
always_comb begin
    case(funct3)
        `FUNCT3_LB:
            rdata = {{24{read_data[7]}}, read_data[7:0]};
        `FUNCT3_LH:
            rdata = {{16{read_data[15]}}, read_data[15:0]};
        `FUNCT3_LW:
            rdata = read_data;
        `FUNCT3_LBU:
            rdata = {24'b0, read_data[7:0]};
        `FUNCT3_LHU:
            rdata = {16'b0, read_data[15:0]};
        default:
            rdata = 32'h0000_0000;
    endcase
end

// ==============
//   SYNC LOGIC
// ==============
always_ff @(posedge clk) begin
    if (!rst_n) begin
        awready_received <= 1'b0;
        wready_received <= 1'b0;
        state <= LSU_IDLE;
    end 
    else begin
        case (state)
            LSU_IDLE: begin
                if (req && we)
                    state <= LSU_WRITE;
                else if (req && !we)
                    state <= LSU_READ_ADDR;
            end
            LSU_WRITE: begin
                if (data_axi.awready)
                    awready_received <= 1'b1;
                if (data_axi.wready)
                    wready_received <= 1'b1;
                if ((awready_received || data_axi.awready) && (wready_received || data_axi.wready))
                    state <= LSU_WRITE_RESP;
            end
            LSU_READ_ADDR: begin
                if (data_axi.arready)
                    state <= LSU_READ_DATA;
            end
            LSU_WRITE_RESP: begin
                if (data_axi.bvalid && data_axi.bready) begin
                    awready_received <= 1'b0;
                    wready_received <= 1'b0;
                    state <= LSU_IDLE;
                end
            end
            LSU_READ_DATA: begin
                if (data_axi.rvalid) 
                    state <= LSU_IDLE;
            end
        endcase
    end
end


endmodule

`default_nettype wire
