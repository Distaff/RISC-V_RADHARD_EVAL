`timescale 1ns / 1ps
`default_nettype none
/*****************************************************************************
 *  Author: Piotr Kadziela
 *  Description:
 *      AXI4-Lite interconnect with one master active at a time.
 *      There are multiple slaves, but one master at a time - either the core
 *      or the debug module. The master changes only when the bus is idle.
 *      Read and write paths are independent, each with one transaction in
 *      flight. The address is decoded and registered before the transaction
 *      is passed on, which costs one cycle.
 *      An address matching no slave is answered locally with DECERR and the
 *      slaves are left untouched.
 *
 *      Adds 1 cycle of latency due to using registers to hold the address and 
 *      select the slave. This is avoidable, but would complicate the design.
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

    input wire              dbg_override_sel,   // high when the debug unit owns the bus

    axil_if.slave           core_axi,           // upstream: core load/store unit
    axil_if.slave           dbg_axi,            // upstream: debug unit
    axil_if.master          slv_axi [NUM_SLV]   // downstream: peripherals and memories
);

import axil_pkg::*;

localparam SEL_W = (NUM_SLV > 1) ? $clog2(NUM_SLV) : 1;

typedef enum logic [1:0] {W_IDLE, W_DATA, W_RESP} wr_state_t;
typedef enum logic [1:0] {R_IDLE, R_ADDR, R_RESP} rd_state_t;

wr_state_t  wr_state;
rd_state_t  rd_state;

//=============================================================================
// MASTER SELECT
//=============================================================================

logic           dbg_in_progress;
logic           master_mux_ok;  // no new transaction until the selection follows dbg_override_sel

logic  [31:0]   m_awaddr, m_wdata, m_araddr, m_rdata;
logic   [3:0]   m_wstrb;
axil_resp_t     m_bresp, m_rresp;
logic           m_awvalid, m_wvalid, m_bready, m_arvalid, m_rready;
logic           m_awready, m_wready, m_bvalid, m_arready, m_rvalid;

assign master_mux_ok = (dbg_in_progress == dbg_override_sel);

always_ff @(posedge clk) begin
    if (!rst_n)
        dbg_in_progress <= 1'b0;
    else if (wr_state == W_IDLE && rd_state == R_IDLE)
        dbg_in_progress <= dbg_override_sel;
end

assign m_awaddr  = dbg_in_progress ? dbg_axi.awaddr  : core_axi.awaddr;
assign m_awvalid = dbg_in_progress ? dbg_axi.awvalid : core_axi.awvalid;
assign m_wdata   = dbg_in_progress ? dbg_axi.wdata   : core_axi.wdata;
assign m_wstrb   = dbg_in_progress ? dbg_axi.wstrb   : core_axi.wstrb;
assign m_wvalid  = dbg_in_progress ? dbg_axi.wvalid  : core_axi.wvalid;
assign m_bready  = dbg_in_progress ? dbg_axi.bready  : core_axi.bready;
assign m_araddr  = dbg_in_progress ? dbg_axi.araddr  : core_axi.araddr;
assign m_arvalid = dbg_in_progress ? dbg_axi.arvalid : core_axi.arvalid;
assign m_rready  = dbg_in_progress ? dbg_axi.rready  : core_axi.rready;

assign core_axi.awready = !dbg_in_progress && m_awready;
assign core_axi.wready  = !dbg_in_progress && m_wready;
assign core_axi.bvalid  = !dbg_in_progress && m_bvalid;
assign core_axi.arready = !dbg_in_progress && m_arready;
assign core_axi.rvalid  = !dbg_in_progress && m_rvalid;
assign core_axi.bresp   = m_bresp;
assign core_axi.rresp   = m_rresp;
assign core_axi.rdata   = m_rdata;

assign dbg_axi.awready  = dbg_in_progress && m_awready;
assign dbg_axi.wready   = dbg_in_progress && m_wready;
assign dbg_axi.bvalid   = dbg_in_progress && m_bvalid;
assign dbg_axi.arready  = dbg_in_progress && m_arready;
assign dbg_axi.rvalid   = dbg_in_progress && m_rvalid;
assign dbg_axi.bresp    = m_bresp;
assign dbg_axi.rresp    = m_rresp;
assign dbg_axi.rdata    = m_rdata;

//=============================================================================
// SLAVE PORTS
//=============================================================================

// An interface array takes only constant indices, so the slave side is
// copied into plain arrays that the paths below can index by register.
logic [NUM_SLV-1:0] s_awvalid, s_awready, s_wvalid, s_wready, s_bvalid, s_bready;
logic [NUM_SLV-1:0] s_arvalid, s_arready, s_rvalid, s_rready;
axil_resp_t         s_bresp [NUM_SLV];
axil_resp_t         s_rresp [NUM_SLV];
logic       [31:0]  s_rdata [NUM_SLV];

generate
    for (genvar i = 0; i < NUM_SLV; i++) begin : g_slv
        assign slv_axi[i].awaddr  = m_awaddr;
        assign slv_axi[i].awvalid = s_awvalid[i];
        assign slv_axi[i].wdata   = m_wdata;
        assign slv_axi[i].wstrb   = m_wstrb;
        assign slv_axi[i].wvalid  = s_wvalid[i];
        assign slv_axi[i].bready  = s_bready[i];
        assign slv_axi[i].araddr  = m_araddr;
        assign slv_axi[i].arvalid = s_arvalid[i];
        assign slv_axi[i].rready  = s_rready[i];

        assign s_awready[i] = slv_axi[i].awready;
        assign s_wready[i]  = slv_axi[i].wready;
        assign s_bvalid[i]  = slv_axi[i].bvalid;
        assign s_bresp[i]   = slv_axi[i].bresp;
        assign s_arready[i] = slv_axi[i].arready;
        assign s_rvalid[i]  = slv_axi[i].rvalid;
        assign s_rresp[i]   = slv_axi[i].rresp;
        assign s_rdata[i]   = slv_axi[i].rdata;
    end
endgenerate

//=============================================================================
// ADDRESS DECODER
//=============================================================================

logic               aw_hit, ar_hit;
logic [SEL_W-1:0]   aw_idx, ar_idx;

always_comb begin
    aw_hit = 1'b0;
    aw_idx = '0;
    ar_hit = 1'b0;
    ar_idx = '0;
    for (int i = 0; i < NUM_SLV; i++) begin
        if ((m_awaddr & SLV_MASK[i*32 +: 32]) == SLV_BASE[i*32 +: 32]) begin
            aw_hit = 1'b1;
            aw_idx = i;
        end
        if ((m_araddr & SLV_MASK[i*32 +: 32]) == SLV_BASE[i*32 +: 32]) begin
            ar_hit = 1'b1;
            ar_idx = i;
        end
    end
end

//=============================================================================
// WRITE PATH
//=============================================================================

// With no slave selected (hit low) the transaction is accepted here and
// answered with DECERR.

logic               wr_hit;
logic [SEL_W-1:0]   wr_sel;
logic               aw_done, w_done;
logic               aw_hs, w_hs;

assign aw_hs = m_awvalid && m_awready;
assign w_hs  = m_wvalid && m_wready;

always_comb begin
    s_awvalid = '0;
    s_wvalid  = '0;
    s_bready  = '0;
    m_awready = 1'b0;
    m_wready  = 1'b0;
    m_bvalid  = 1'b0;
    m_bresp   = AXIL_RESP_OKAY;

    case (wr_state)
        W_DATA: begin
            s_awvalid[wr_sel] = wr_hit && m_awvalid && !aw_done;
            s_wvalid[wr_sel]  = wr_hit && m_wvalid && !w_done;
            m_awready = !aw_done && (wr_hit ? s_awready[wr_sel] : 1'b1);
            m_wready  = !w_done  && (wr_hit ? s_wready[wr_sel]  : 1'b1);
        end
        W_RESP: begin
            s_bready[wr_sel] = wr_hit && m_bready;
            m_bvalid = wr_hit ? s_bvalid[wr_sel] : 1'b1;
            m_bresp  = wr_hit ? s_bresp[wr_sel]  : AXIL_RESP_DECERR;
        end
        default: ;
    endcase
end

always_ff @(posedge clk) begin
    if (!rst_n) begin
        wr_state <= W_IDLE;
    end
    else begin
        case (wr_state)
            W_IDLE: if (m_awvalid && master_mux_ok) begin
                wr_hit   <= aw_hit;
                wr_sel   <= aw_idx;
                aw_done  <= 1'b0;
                w_done   <= 1'b0;
                wr_state <= W_DATA;
            end
            W_DATA: begin
                if (aw_hs) aw_done <= 1'b1;
                if (w_hs)  w_done  <= 1'b1;
                if ((aw_done || aw_hs) && (w_done || w_hs))
                    wr_state <= W_RESP;
            end
            W_RESP: if (m_bvalid && m_bready)
                wr_state <= W_IDLE;
            default:
                wr_state <= W_IDLE;
        endcase
    end
end

//=============================================================================
// READ PATH
//=============================================================================

logic               rd_hit;
logic [SEL_W-1:0]   rd_sel;

always_comb begin
    s_arvalid = '0;
    s_rready  = '0;
    m_arready = 1'b0;
    m_rvalid  = 1'b0;
    m_rresp   = AXIL_RESP_OKAY;
    m_rdata   = 32'd0;

    case (rd_state)
        R_ADDR: begin
            s_arvalid[rd_sel] = rd_hit && m_arvalid;
            m_arready = rd_hit ? s_arready[rd_sel] : 1'b1;
        end
        R_RESP: begin
            s_rready[rd_sel] = rd_hit && m_rready;
            m_rvalid = rd_hit ? s_rvalid[rd_sel] : 1'b1;
            m_rresp  = rd_hit ? s_rresp[rd_sel]  : AXIL_RESP_DECERR;
            m_rdata  = rd_hit ? s_rdata[rd_sel]  : 32'd0;
        end
        default: ;
    endcase
end

always_ff @(posedge clk) begin
    if (!rst_n) begin
        rd_state <= R_IDLE;
    end
    else begin
        case (rd_state)
            R_IDLE: if (m_arvalid && master_mux_ok) begin
                rd_hit   <= ar_hit;
                rd_sel   <= ar_idx;
                rd_state <= R_ADDR;
            end
            R_ADDR: if (m_arvalid && m_arready)
                rd_state <= R_RESP;
            R_RESP: if (m_rvalid && m_rready)
                rd_state <= R_IDLE;
            default:
                rd_state <= R_IDLE;
        endcase
    end
end

endmodule

`default_nettype wire
