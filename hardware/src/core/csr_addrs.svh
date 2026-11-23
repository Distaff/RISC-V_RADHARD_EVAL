// Addresses of the Control and Status Registers (CSRs) in the RISC-V architecture
                                            // implemented?  R/W   Description
`define CSR_ADDR_MCYCLE     12'hB00         // Yes          | RW | Machine Cycle Counter
`define CSR_ADDR_MCYCLEH    12'hB80         // Yes          | RW | Machine Cycle Counter, upper 32 bits
`define CSR_ADDR_MINSTRET   12'hB02         // Yes          | RW | Machine Instructions Retired Counter
`define CSR_ADDR_MINSTRETH  12'hB82         // Yes          | RW | Machine Instructions Retired Counter, upper 32 bits

`define CSR_ADDR_MVENDORID  12'hF11         // Always Null  | RO | Vendor ID
`define CSR_ADDR_MARCHID    12'hF12         // Always Null  | RO | Architecture ID
`define CSR_ADDR_MIMPID     12'hF13         // Always Null  | RO | Implementation ID
`define CSR_ADDR_MHARTID    12'hF14         // Yes          | RO | Hardware Thread ID

`define CSR_ADDR_MISA       12'h301         // WR ignored   | RO | ISA and extensions

// Not implemented
`define CSR_ADDR_MSTATUS    12'h300         //              | RW | Machine Status
`define CSR_ADDR_MIE        12'h304         //              | RW | Machine Interrupt Enable
`define CSR_ADDR_MTVEC      12'h305         //              | RW | Machine Trap-Vector Base Address
`define CSR_ADDR_MCOUNTEREN 12'h306         //              | RW | Machine Counter Enable