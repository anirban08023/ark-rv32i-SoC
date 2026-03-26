module pc (
    input wire clk,
    input wire rst_n,

    // Control signals from decoder
    input wire        branch,         // Branch instruction flag
    input wire        jump,           // Jump instruction flag (JAL or JALR)
    input wire [2:0]  branch_type,    // Branch condition type
    input wire [31:0] instr,          // Instruction (to detect JALR)
    input wire [63:0] imm,            // Immediate offset for branch/jump

    // Branch condition flags from ALU
    input wire        alu_eq,         // Equal flag
    input wire        alu_lt,         // Less than (signed) flag
    input wire        alu_ltu,        // Less than unsigned flag
    input wire        alu_ready,      // ALU ready (for multi-cycle ops)

    // For JALR: target = (rs1 + imm) & ~1
    input wire [63:0] alu_result,     // ALU result (rs1 + imm for JALR)

    // PC outputs
    output reg [63:0] pc,             // Current program counter
    output wire [63:0] pc_next,       // Next PC value
    output wire [63:0] pc_plus_4      // PC + 4 (for link register)
);

    // ================================================================
    // Opcode and Branch Type Encoding
    // ================================================================
    localparam JALR_OPCODE = 7'b1100111;

    localparam BEQ  = 3'b000;
    localparam BNE  = 3'b001;
    localparam BLT  = 3'b100;
    localparam BGE  = 3'b101;
    localparam BLTU = 3'b110;
    localparam BGEU = 3'b111;

    // Detect JALR instruction
    wire is_jalr = (instr[6:0] == JALR_OPCODE) && jump;

    // ================================================================
    // Branch Condition Evaluation
    // ================================================================
    reg branch_taken;
    always @(*) begin
        case (branch_type)
            BEQ:     branch_taken = alu_eq;       // Branch if equal
            BNE:     branch_taken = ~alu_eq;      // Branch if not equal
            BLT:     branch_taken = alu_lt;       // Branch if less than (signed)
            BGE:     branch_taken = ~alu_lt;      // Branch if greater/equal (signed)
            BLTU:    branch_taken = alu_ltu;      // Branch if less than (unsigned)
            BGEU:    branch_taken = ~alu_ltu;     // Branch if greater/equal (unsigned)
            default: branch_taken = 1'b0;
        endcase
    end

    // ================================================================
    // Next PC Calculation
    // ================================================================
    assign pc_plus_4 = pc + 64'd4;

    reg [63:0] pc_target;
    always @(*) begin
        if (is_jalr) begin
            // JALR: PC = (rs1 + imm) & ~1
            // ALU already computed rs1 + imm, just clear LSB
            pc_target = {alu_result[63:1], 1'b0};
        end else if (jump) begin
            // JAL: PC = PC + imm (signed offset)
            pc_target = pc + imm;
        end else if (branch && branch_taken) begin
            // Branch: PC = PC + imm (signed offset)
            pc_target = pc + imm;
        end else begin
            // Sequential: PC = PC + 4
            pc_target = pc_plus_4;
        end
    end

    assign pc_next = pc_target;

    // ================================================================
    // PC Update Logic
    // ================================================================
    // PC updates only when ALU is ready (important for multi-cycle ops)
    // This prevents PC from advancing during MUL/DIV operations
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc <= 64'h0000_0000_0000_0000;  // Reset vector (configurable)
        end else if (alu_ready) begin
            pc <= pc_target;
        end
        // If ALU is busy (MUL/DIV), PC stays unchanged
    end

endmodule
