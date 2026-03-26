module top_soc #(
    parameter IMEM_ADDR_WIDTH = 16,  // Instruction memory address width
    parameter IMEM_SIZE       = 1024, // Instruction memory size (words)
    parameter DMEM_ADDR_WIDTH = 16,  // Data memory address width
    parameter DMEM_SIZE       = 4096 // Data memory size (bytes)
) (
    input wire clk,
    input wire rst_n,

    // Program Counter output (exposed for debugging)
    output wire [63:0] pc,           // Current program counter
    output wire [63:0] pc_next,      // Next PC value

    // Outputs
    output wire [63:0] alu_result,   // ALU result
    output wire        alu_ready,    // ALU ready signal
    output wire        alu_zero,     // Zero flag
    output wire        alu_eq,       // Equal flag (for BEQ)
    output wire        alu_lt,       // Less than flag (for BLT)
    output wire        alu_ltu,      // Less than unsigned flag (for BLTU)

    // Memory interface (for future use)
    output wire        mem_read,     // Memory read enable
    output wire        mem_write,    // Memory write enable
    output wire [2:0]  mem_size,     // Memory access size
    output wire        mem_unsigned, // Unsigned load flag

    // Control flow signals (for future use)
    output wire        branch,       // Branch instruction flag
    output wire        jump,         // Jump instruction flag
    output wire [2:0]  branch_type,  // Branch condition type
    output wire        is_valid      // Valid instruction flag
);

    // ==============================================================
    // Internal Datapath Signals
    // ==============================================================

    // Instruction from memory
    wire [31:0] instr;

    // Decoder outputs
    wire [4:0]  rs1_addr, rs2_addr, rd_addr;
    wire [63:0] imm;
    wire [5:0]  alu_ctrl;
    wire        alu_src;
    wire        alu_start;
    wire        reg_write;

    // Register File outputs
    wire [63:0] rs1_data, rs2_data;

    // ALU operand B selection: choose between rs2 data or immediate
    wire [63:0] alu_b = alu_src ? imm : rs2_data;

    // PC outputs
    wire [63:0] pc_plus_4;

    // Data memory signals
    wire [63:0] mem_read_data;
    wire        mem_ready;

    // Write-back data selection: Memory data, ALU result, or PC+4
    // Priority: LOAD > JUMP > ALU
    wire [63:0] rd_data = mem_read  ? mem_read_data :
                          jump      ? pc_plus_4 :
                                      alu_result;

    // ==============================================================
    // Instruction Memory Instance
    // ==============================================================
    instr_mem #(
        .ADDR_WIDTH (IMEM_ADDR_WIDTH),
        .MEM_SIZE   (IMEM_SIZE)
    ) u_instr_mem (
        .clk   (clk),
        .rst_n (rst_n),
        .pc    (pc),
        .instr (instr)
    );

    // ==============================================================
    // Program Counter Instance
    // ==============================================================
    pc u_pc (
        .clk         (clk),
        .rst_n       (rst_n),
        .branch      (branch),
        .jump        (jump),
        .branch_type (branch_type),
        .instr       (instr),
        .imm         (imm),
        .alu_eq      (alu_eq),
        .alu_lt      (alu_lt),
        .alu_ltu     (alu_ltu),
        .alu_ready   (alu_ready),
        .alu_result  (alu_result),
        .pc          (pc),
        .pc_next     (pc_next),
        .pc_plus_4   (pc_plus_4)
    );

    // ==============================================================
    // Instruction Decoder Instance
    // ==============================================================
    decoder u_decoder (
        .instr        (instr),
        .rs1_addr     (rs1_addr),
        .rs2_addr     (rs2_addr),
        .rd_addr      (rd_addr),
        .imm          (imm),
        .alu_ctrl     (alu_ctrl),
        .alu_src      (alu_src),
        .alu_start    (alu_start),
        .reg_write    (reg_write),
        .mem_read     (mem_read),
        .mem_write    (mem_write),
        .mem_size     (mem_size),
        .mem_unsigned (mem_unsigned),
        .branch       (branch),
        .jump         (jump),
        .branch_type  (branch_type),
        .is_valid     (is_valid)
    );

    // ==============================================================
    // Register File Instance
    // ==============================================================
    reg_file u_reg_file (
        .clk      (clk),
        .rst_n    (rst_n),
        .rs1_addr (rs1_addr),
        .rs2_addr (rs2_addr),
        .rd_addr  (rd_addr),
        .rd_data  (rd_data),           // Write back: ALU result or PC+4
        .reg_write(reg_write),
        .rs1_data (rs1_data),
        .rs2_data (rs2_data)
    );

    // ==============================================================
    // ALU Instance
    // ==============================================================
    alu u_alu (
        .clk      (clk),
        .rst_n    (rst_n),
        .a        (rs1_data),      // Operand A from register file
        .b        (alu_b),         // Operand B (rs2 or immediate)
        .alu_ctrl (alu_ctrl),
        .start    (alu_start),
        .result   (alu_result),
        .ready    (alu_ready),
        .zero     (alu_zero),
        .eq       (alu_eq),
        .lt       (alu_lt),
        .ltu      (alu_ltu)
    );

    // ==============================================================
    // Data Memory Instance
    // ==============================================================
    data_mem #(
        .ADDR_WIDTH (DMEM_ADDR_WIDTH),
        .MEM_SIZE   (DMEM_SIZE)
    ) u_data_mem (
        .clk        (clk),
        .rst_n      (rst_n),
        .addr       (alu_result),      // Address from ALU (rs1 + offset)
        .write_data (rs2_data),        // Data to write from rs2
        .mem_read   (mem_read),
        .mem_write  (mem_write),
        .mem_size   (mem_size),
        .mem_unsigned(mem_unsigned),
        .read_data  (mem_read_data),
        .mem_ready  (mem_ready)
    );

    // ==============================================================
    // Datapath Complete - All components integrated
    // ==============================================================

endmodule
