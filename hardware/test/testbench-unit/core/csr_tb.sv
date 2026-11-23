`timescale 1ns / 1ps
`default_nettype none
/*****************************************************************************
 *  Author: Piotr Kadziela
 *  Description:
 *      Unit testbench for csr. Expected values are worked out by hand.
 *      minstret only moves on instr_retired, so it is used for the access
 *      semantics; mcycle is checked with exact cycle counts.
 *****************************************************************************/

`include "opcodes.svh"
`include "csr_addrs.svh"
`include "tb_utils.svh"

module csr_tb;

`TB_VARS
`TB_TIMEOUT(20000)

localparam HART_ID = 32'h0000_0007;

logic           clk;
logic           rst_n;
logic           csr_en;
logic [11:0]    csr_addr;
logic  [2:0]    funct3;
logic           rs_is_x0;
logic [31:0]    wdata;
logic [31:0]    rdata;
logic           illegal;
logic           instr_retired;

csr #(
    .HART_ID(HART_ID)
) dut (
    .clk(clk),
    .rst_n(rst_n),
    .csr_en(csr_en),
    .csr_addr(csr_addr),
    .funct3(funct3),
    .rd_is_x0(1'b0),
    .rs_is_x0(rs_is_x0),
    .wdata(wdata),
    .rdata(rdata),
    .illegal(illegal),
    .instr_retired(instr_retired)
);

initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
end

// One CSR instruction. Called on a falling edge, returns on the next one,
// after the rising edge that performs the write.
task automatic access(
    input  logic  [2:0] f3,
    input  logic [11:0] addr,
    input  logic        rs0,
    input  logic [31:0] data,
    output logic [31:0] old,
    output logic        ill
);
    funct3   = f3;
    csr_addr = addr;
    rs_is_x0 = rs0;
    wdata    = data;
    csr_en   = 1'b1;
    #1;
    old = rdata;
    ill = illegal;
    @(negedge clk);
    csr_en = 1'b0;
endtask

// csrr: CSRRS with rs1 = x0
task automatic csr_read(input logic [11:0] addr, output logic [31:0] old, output logic ill);
    access(`FUNCT3_CSRRS, addr, 1'b1, 32'd0, old, ill);
endtask

// csrw: CSRRW with rs1 != x0
task automatic csr_write(input logic [11:0] addr, input logic [31:0] data, output logic ill);
    logic [31:0] unused;
    access(`FUNCT3_CSRRW, addr, 1'b0, data, unused, ill);
endtask

task automatic retire(input int n);
    repeat (n) begin
        instr_retired = 1'b1;
        @(negedge clk);
        instr_retired = 1'b0;
    end
endtask

logic [31:0] old;
logic        ill;

initial begin
    rst_n         = 1'b0;
    csr_en        = 1'b0;
    csr_addr      = 12'd0;
    funct3        = 3'd0;
    rs_is_x0      = 1'b1;
    wdata         = 32'd0;
    instr_retired = 1'b0;

    repeat (4) @(negedge clk);
    rst_n = 1'b1;

    //-------------------------------------------------------------------------
    // Read-only identification registers
    //-------------------------------------------------------------------------
    csr_read(`CSR_ADDR_MHARTID, old, ill);
    `CHECK_EQ(old, HART_ID, "mhartid")
    `CHECK_EQ(ill, 1'b0, "csrr mhartid is legal")
    csr_read(`CSR_ADDR_MVENDORID, old, ill);
    `CHECK_EQ(old, 32'h0, "mvendorid")
    csr_read(`CSR_ADDR_MARCHID, old, ill);
    `CHECK_EQ(old, 32'h0, "marchid")
    csr_read(`CSR_ADDR_MIMPID, old, ill);
    `CHECK_EQ(old, 32'h0, "mimpid")

    // RV32 (MXL = 1) with the I base; M stays clear, Zmmul has no letter
    csr_read(`CSR_ADDR_MISA, old, ill);
    `CHECK_EQ(old, 32'h4000_0100, "misa")
    `CHECK_EQ(ill, 1'b0, "csrr misa is legal")

    // Any write attempt to a read-only CSR is illegal, whatever the value
    csr_write(`CSR_ADDR_MHARTID, 32'h0, ill);
    `CHECK_EQ(ill, 1'b1, "csrw mhartid is illegal")
    access(`FUNCT3_CSRRW, `CSR_ADDR_MHARTID, 1'b1, 32'd0, old, ill);
    `CHECK_EQ(ill, 1'b1, "csrrw mhartid with rs1 = x0 still writes")
    access(`FUNCT3_CSRRS, `CSR_ADDR_MHARTID, 1'b0, 32'd0, old, ill);
    `CHECK_EQ(ill, 1'b1, "csrrs mhartid with rs1 != x0 writes even zero")
    access(`FUNCT3_CSRRSI, `CSR_ADDR_MHARTID, 1'b1, 32'd0, old, ill);
    `CHECK_EQ(ill, 1'b0, "csrrsi mhartid with uimm = 0 is a read")

    // misa is read-write with every bit fixed: writes are ignored, not illegal
    csr_write(`CSR_ADDR_MISA, 32'h0000_0000, ill);
    `CHECK_EQ(ill, 1'b0, "csrw misa is legal")
    csr_read(`CSR_ADDR_MISA, old, ill);
    `CHECK_EQ(old, 32'h4000_0100, "misa ignores writes")

    //-------------------------------------------------------------------------
    // Illegal accesses
    //-------------------------------------------------------------------------
    csr_read(12'h7C0, old, ill);
    `CHECK_EQ(ill, 1'b1, "unknown CSR")
    csr_read(12'h300, old, ill);
    `CHECK_EQ(ill, 1'b1, "mstatus not implemented")
    access(3'b000, `CSR_ADDR_MINSTRET, 1'b1, 32'd0, old, ill);
    `CHECK_EQ(ill, 1'b1, "funct3 000 is not a CSR access")
    access(3'b100, `CSR_ADDR_MINSTRET, 1'b1, 32'd0, old, ill);
    `CHECK_EQ(ill, 1'b1, "funct3 100 is not a CSR access")

    //-------------------------------------------------------------------------
    // minstret - counts instr_retired, still zero after reset
    //-------------------------------------------------------------------------
    csr_read(`CSR_ADDR_MINSTRET, old, ill);
    `CHECK_EQ(old, 32'd0, "minstret after reset")
    retire(3);
    csr_read(`CSR_ADDR_MINSTRET, old, ill);
    `CHECK_EQ(old, 32'd3, "minstret counts retirements")

    //-------------------------------------------------------------------------
    // Access semantics, on minstret since it holds still
    //-------------------------------------------------------------------------
    access(`FUNCT3_CSRRW, `CSR_ADDR_MINSTRET, 1'b0, 32'hF0F0_F0F0, old, ill);
    `CHECK_EQ(old, 32'd3, "csrrw returns the old value")
    access(`FUNCT3_CSRRS, `CSR_ADDR_MINSTRET, 1'b0, 32'h0F00_000F, old, ill);
    `CHECK_EQ(old, 32'hF0F0_F0F0, "csrrw wrote")
    access(`FUNCT3_CSRRC, `CSR_ADDR_MINSTRET, 1'b0, 32'hFF00_0000, old, ill);
    `CHECK_EQ(old, 32'hFFF0_F0FF, "csrrs sets bits")
    access(`FUNCT3_CSRRWI, `CSR_ADDR_MINSTRET, 1'b0, 32'h0000_001F, old, ill);
    `CHECK_EQ(old, 32'h00F0_F0FF, "csrrc clears bits")
    access(`FUNCT3_CSRRCI, `CSR_ADDR_MINSTRET, 1'b0, 32'h0000_0001, old, ill);
    `CHECK_EQ(old, 32'h0000_001F, "csrrwi wrote")
    access(`FUNCT3_CSRRSI, `CSR_ADDR_MINSTRET, 1'b1, 32'h0000_0000, old, ill);
    `CHECK_EQ(old, 32'h0000_001E, "csrrci clears bits")

    // Not performed: csr_en low, and an illegal funct3 carrying a write
    funct3   = `FUNCT3_CSRRW;
    csr_addr = `CSR_ADDR_MINSTRET;
    rs_is_x0 = 1'b0;
    wdata    = 32'hDEAD_BEEF;
    @(negedge clk);
    access(3'b100, `CSR_ADDR_MINSTRET, 1'b0, 32'hDEAD_BEEF, old, ill);
    csr_read(`CSR_ADDR_MINSTRET, old, ill);
    `CHECK_EQ(old, 32'h0000_001E, "no write without csr_en or with a bad funct3")

    // A write in the same cycle as a retirement wins over the increment
    instr_retired = 1'b1;
    csr_write(`CSR_ADDR_MINSTRET, 32'd100, ill);
    instr_retired = 1'b0;
    csr_read(`CSR_ADDR_MINSTRET, old, ill);
    `CHECK_EQ(old, 32'd100, "write beats retirement")

    // Writing one half leaves the other alone
    csr_write(`CSR_ADDR_MINSTRETH, 32'h0000_00AB, ill);
    csr_read(`CSR_ADDR_MINSTRETH, old, ill);
    `CHECK_EQ(old, 32'h0000_00AB, "minstreth written")
    csr_read(`CSR_ADDR_MINSTRET, old, ill);
    `CHECK_EQ(old, 32'd100, "minstret untouched by minstreth write")

    //-------------------------------------------------------------------------
    // mcycle - one per clock, a write replaces that cycle's increment
    //-------------------------------------------------------------------------
    csr_write(`CSR_ADDR_MCYCLEH, 32'h0000_0000, ill);
    csr_write(`CSR_ADDR_MCYCLE, 32'h0000_0010, ill);
    csr_read(`CSR_ADDR_MCYCLE, old, ill);
    `CHECK_EQ(old, 32'h0000_0010, "mcycle holds the written value")
    csr_read(`CSR_ADDR_MCYCLE, old, ill);
    `CHECK_EQ(old, 32'h0000_0011, "csrr does not stop mcycle")

    // csrrs with a register holding zero is a write, so it swallows a tick
    access(`FUNCT3_CSRRS, `CSR_ADDR_MCYCLE, 1'b0, 32'd0, old, ill);
    `CHECK_EQ(old, 32'h0000_0012, "mcycle before a zero csrrs")
    csr_read(`CSR_ADDR_MCYCLE, old, ill);
    `CHECK_EQ(old, 32'h0000_0012, "zero csrrs rewrote mcycle")

    // Carry from the low half into the high half
    csr_write(`CSR_ADDR_MCYCLE, 32'hFFFF_FFFF, ill);
    @(negedge clk);
    csr_read(`CSR_ADDR_MCYCLEH, old, ill);
    `CHECK_EQ(old, 32'h0000_0001, "mcycle carries into mcycleh")

    `TB_FINISH
end

endmodule

`default_nettype wire
