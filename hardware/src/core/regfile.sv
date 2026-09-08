`timescale 1ns / 1ps
`default_nettype none
/*****************************************************************************
 *  Author: Piotr Kadziela
 *  Description:
 *      Register file for RISC-V core.
 *      Resetting the register file causes all the registers to be zeroed
 *      sequentially. After that, the rst_ready signal goes high.
 *****************************************************************************/

module regfile (
    input wire          clk,
    input wire          rst_n,
    output logic        rst_ready,      // high when reset is finished (after zeroing all registers)

    input wire   [4:0]  r_sel_1,        // number of the first register to read
    input wire   [4:0]  r_sel_2,        // number of the second register to read
    output logic [31:0] r_data_1,       // data from the first register
    output logic [31:0] r_data_2,       // data from the second register

    input wire          w_en,           // write enable
    input wire   [4:0]  w_sel,          // number of the register to write
    input wire  [31:0]  w_data          // data to write
);

(* ram_style = "distributed" *)
logic   [31:0]  reg_data [0:31];        // 32 registers of 32 bits each

logic    [4:0]  rst_cnt;                // clearing counter
logic           rst_busy = 1'b1;      // high while the file is being cleared; starts set so
                                        // that readiness is never claimed before the first reset

logic           ram_we;
logic    [4:0]  ram_waddr;
logic   [31:0]  ram_wdata;

assign r_data_1  = reg_data[r_sel_1];
assign r_data_2  = reg_data[r_sel_2];
assign rst_ready = !rst_busy;

// Single write port, shared by the clearing sequence and by normal writes.
// x0 is skipped during normal operation but still cleared on reset.
assign ram_we    = rst_busy || (w_en && w_sel != 5'b00000);
assign ram_waddr = rst_busy ? rst_cnt : w_sel;
assign ram_wdata = rst_busy ? 32'b0   : w_data;

always_ff @(posedge clk) begin
    if (ram_we) reg_data[ram_waddr] <= ram_wdata;
end

always_ff @(posedge clk) begin
    if (!rst_n) begin
        rst_cnt  <= 5'b00000;
        rst_busy <= 1'b1;
    end
    else if (rst_busy) begin
        rst_cnt <= rst_cnt + 1;
        if (rst_cnt == 5'b11111) rst_busy <= 1'b0;
    end
end


endmodule

`default_nettype wire
