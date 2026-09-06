`timescale 1ns / 1ps
`default_nettype none
/*****************************************************************************
 *  Author: Piotr Kadziela
 *  Description:
 *      Basic BRAM-based, word-addressable dual-port memory module for RISC-V
 *      core. Only 32-bit word aligned access is supported. Strobe writes are
 *      supported on port B.
 *      Port A is read-only and drives instruction fetch. Port B is read/write
 *      and hangs off the system bus. The data memory leaves port A unused.
 *      Both ports read in read-first mode: a read issued in the same cycle as
 *      a write to the same address returns the old contents.
 *****************************************************************************/

module memory #(
    parameter MEMORY_SIZE_WORDS = 1024,                     // Memory size in 32-bit words, must be a power of two
    parameter INIT_FILE         = ""                        // Path to memory initialization file. Zero-initialized if none is provided.
) (
    input wire                  clk,

    // Port A - read only, instruction fetch
    input wire                  a_en,       // read enable
    input wire      [31:0]      a_addr,     // 32-bit byte address
    output logic    [31:0]      a_data,     // 32-bits of data

    // Port B - read/write, system bus
    input wire                  b_en,       // access enable
    input wire      [31:0]      b_addr,     // 32-bit byte address
    output logic    [31:0]      b_data,     // 32-bits of data
    input wire      [31:0]      b_wdata,    // 32-bits of data to write
    input wire      [3:0]       b_wstrb     // write strobe - which bytes are to be written, zero for a read
);

localparam ADDR_BITS = $clog2(MEMORY_SIZE_WORDS);

(* ram_style = "block" *)
logic   [31:0]  mem [0:MEMORY_SIZE_WORDS-1];

logic   [ADDR_BITS-1:0] a_addr_wrd;
logic   [ADDR_BITS-1:0] b_addr_wrd;

assign a_addr_wrd = a_addr[ADDR_BITS+1:2];
assign b_addr_wrd = b_addr[ADDR_BITS+1:2];

always_ff @(posedge clk) begin
    if (a_en) begin
        a_data <= mem[a_addr_wrd];
    end
end

always_ff @(posedge clk) begin
    if (b_en) begin
        b_data <= mem[b_addr_wrd];

        if (b_wstrb[0]) mem[b_addr_wrd][7:0]   <= b_wdata[7:0];
        if (b_wstrb[1]) mem[b_addr_wrd][15:8]  <= b_wdata[15:8];
        if (b_wstrb[2]) mem[b_addr_wrd][23:16] <= b_wdata[23:16];
        if (b_wstrb[3]) mem[b_addr_wrd][31:24] <= b_wdata[31:24];
    end
end

initial begin
    if (INIT_FILE != "") begin
        $readmemh(INIT_FILE, mem);
    end
end

endmodule

`default_nettype wire
