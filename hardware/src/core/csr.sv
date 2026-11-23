`timescale 1ns / 1ps
`default_nettype none
/*****************************************************************************
 *  Author: Piotr Kadziela
 *  Description:
 *      Control and status registers for the Zicsr extension.
 *      Implements selected CSRs from the RISC-V privileged spec.
 *      Implemented CSRs:
 *          - mcycle, mcycleh
 *          - minstret, minstreth
 *          - mvendorid, marchid, mimpid, mhartid
 *          - misa
 *****************************************************************************/

`include "opcodes.svh"
`include "csr_addrs.svh"

module csr #(
    parameter HART_ID = 32'h0000_0000
) (
    input wire              clk,
    input wire              rst_n,

    // Access from the core
    input wire              csr_en,         // an OP_SYSTEM instruction with a CSR funct3
    input wire      [11:0]  csr_addr,       // instr[31:20]
    input wire      [2:0]   funct3,         // selects read/write, set, clear and the immediate forms
    input wire              rd_is_x0,       // suppress read, unused for now
    input wire              rs_is_x0,       // suppress write
    input wire      [31:0]  wdata,          // rs1 contents, or the zero-extended 5-bit immediate
    output logic    [31:0]  rdata,          // previous contents of the addressed CSR
    output logic            illegal,        // no such CSR, a write to a read-only one, wrong funct3

    // Counter events
    input wire              instr_retired   // one-cycle pulse per completed instruction
);

// ================
//       CSRs
// ================

logic [63:0] mcycle;
logic [63:0] minstret;
const logic [31:0] mvendorid = 32'h0000_0000;
const logic [31:0] marchid   = 32'h0000_0000;
const logic [31:0] mimpid    = 32'h0000_0000;
const logic [31:0] mhartid   = HART_ID;
const logic [31:0] misa      = 32'h4000_0100;  // RV32I, no extensions

// ================
// READ/WRITE LOGIC
// ================

logic [31:0] new_csr_data;

// Select value to be read
always_comb begin
    case (csr_addr)
        `CSR_ADDR_MCYCLE:
            rdata = mcycle[31:0];
        `CSR_ADDR_MCYCLEH:
            rdata = mcycle[63:32];
        `CSR_ADDR_MINSTRET:
            rdata = minstret[31:0];
        `CSR_ADDR_MINSTRETH:
            rdata = minstret[63:32];
        `CSR_ADDR_MVENDORID:
            rdata = mvendorid;
        `CSR_ADDR_MARCHID:
            rdata = marchid;
        `CSR_ADDR_MIMPID:   
            rdata = mimpid;
        `CSR_ADDR_MHARTID: 
            rdata = mhartid;
        `CSR_ADDR_MISA:
            rdata = misa;
        default: begin
            rdata = 32'b0;
        end
    endcase
end

// Compute the new value to be written
always_comb begin
    case (funct3)
        `FUNCT3_CSRRW, `FUNCT3_CSRRWI:
            new_csr_data = wdata;
        `FUNCT3_CSRRS, `FUNCT3_CSRRSI:
            new_csr_data = rdata | wdata;
        `FUNCT3_CSRRC, `FUNCT3_CSRRCI:
            new_csr_data = rdata & ~wdata;
        default:
            new_csr_data = rdata;
    endcase
end

// ================
//      HELPERS
// ================

logic illegal_addr;
assign illegal_addr = (csr_addr != `CSR_ADDR_MCYCLE) &&
                    (csr_addr != `CSR_ADDR_MCYCLEH) &&
                    (csr_addr != `CSR_ADDR_MINSTRET) &&
                    (csr_addr != `CSR_ADDR_MINSTRETH) &&
                    (csr_addr != `CSR_ADDR_MVENDORID) &&
                    (csr_addr != `CSR_ADDR_MARCHID) &&
                    (csr_addr != `CSR_ADDR_MIMPID) &&
                    (csr_addr != `CSR_ADDR_MHARTID) &&
                    (csr_addr != `CSR_ADDR_MISA);

logic op_writes;            // Operation is not a read-only one
assign op_writes = (funct3 == `FUNCT3_CSRRW) || (funct3 == `FUNCT3_CSRRWI) || !(rs_is_x0);

logic addr_read_only;       // Address points to a read-only CSR
assign addr_read_only = (csr_addr == `CSR_ADDR_MVENDORID) ||
                      (csr_addr == `CSR_ADDR_MARCHID) ||
                      (csr_addr == `CSR_ADDR_MIMPID) ||
                      (csr_addr == `CSR_ADDR_MHARTID);
                      // MISA is not read-only, although writes are ignored

logic bad_op;               // Invalid funct3
assign bad_op = (funct3 != `FUNCT3_CSRRW) && 
                (funct3 != `FUNCT3_CSRRS) && 
                (funct3 != `FUNCT3_CSRRC) &&
                (funct3 != `FUNCT3_CSRRWI) && 
                (funct3 != `FUNCT3_CSRRSI) && 
                (funct3 != `FUNCT3_CSRRCI);

// output illegal
assign illegal = illegal_addr || (op_writes && addr_read_only) || bad_op;

logic write_performed;  // Should a write be performed?
assign write_performed = csr_en && op_writes && !illegal;

logic minstret_write;   // Is the instruction writing to minstret or minstreth?
assign minstret_write = write_performed && (csr_addr == `CSR_ADDR_MINSTRET || csr_addr == `CSR_ADDR_MINSTRETH);

logic mcycle_write;     // Is the instruction writing to mcycle or mcycleh?
assign mcycle_write = write_performed && (csr_addr == `CSR_ADDR_MCYCLE || csr_addr == `CSR_ADDR_MCYCLEH);

always_ff @(posedge clk) begin
    if (!rst_n) begin
        minstret <= 64'b0;
        mcycle <= 64'b0;
    end
    else begin
        if (write_performed) begin
            case (csr_addr)
                `CSR_ADDR_MCYCLE:
                    mcycle[31:0] <= new_csr_data;
                `CSR_ADDR_MCYCLEH:
                    mcycle[63:32] <= new_csr_data;
                `CSR_ADDR_MINSTRET:
                    minstret[31:0] <= new_csr_data;
                `CSR_ADDR_MINSTRETH:
                    minstret[63:32] <= new_csr_data;
            endcase
        end

        if (!minstret_write && instr_retired)
            minstret <= minstret + 1;

        if (!mcycle_write)
            mcycle <= mcycle + 1;
    end
end

endmodule

`default_nettype wire