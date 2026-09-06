`timescale 1ns / 1ps
`default_nettype none
/*****************************************************************************
 *  Author: Piotr Kadziela
 *  Description:
 *      Simple timer peripheral with a register interface.
 *      Provides a 32-bit counter register, that is incremented every cycle
 *      and can be read and written. It also provides a control register to
 *      enable/disable the timer.
 *      Reads and writes are assumed to be aligned and of word size. Bus
 *      decoding and handshaking are left to the AXI wrapper.
 *****************************************************************************/

module timer (
    input wire          clk,
    input wire          rst_n,

    // Register interface
    input wire          reg_r_en,       // read enable
    input wire   [3:0]  reg_addr,       // register address within the peripheral
    output logic [31:0] reg_r_data,     // 32-bits of data

    input wire          reg_w_en,       // write enable
    input wire  [31:0]  reg_w_data      // 32-bits of data
);

localparam ADDR_COUNTER = 4'h0;
localparam ADDR_CONTROL = 4'h4;

logic   [31:0]  counter;    // 32-bit counter register
logic           control;    // control register: high = enabled, low = disabled

always_ff @(posedge clk) begin
    if (!rst_n) begin
        counter <= 32'b0;
        control <= 1'b1;    // enabled by default
    end
    else begin
        counter <= counter + control;

        if (reg_w_en) begin
            case (reg_addr)
                ADDR_COUNTER: counter <= reg_w_data;         // Write to counter register
                ADDR_CONTROL: control <= reg_w_data[0];      // Write to control register (only LSB used)
                default: ;                                   // Ignore writes to other addresses
            endcase
        end
    end
end

always_comb begin
    if (reg_r_en) begin
        case (reg_addr)
            ADDR_COUNTER: reg_r_data = counter;
            ADDR_CONTROL: reg_r_data = {31'b0, control};
            default:      reg_r_data = 32'b0;
        endcase
    end
    else reg_r_data = 32'b0;
end

endmodule

`default_nettype wire
