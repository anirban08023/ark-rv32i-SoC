module decoder (
    input wire [31:0] instr,          // 32-bit instruction

    // Register addresses
    output wire [4:0]  rs1_addr,      // Source register 1
    output wire [4:0]  rs2_addr,      // Source register 2
    output wire [4:0]  rd_addr,       // Destination register

    // Immediate value
    output reg  [63:0] imm,           // Sign-extended immediate

    // ALU control
    output reg  [5:0]  alu_ctrl,      // ALU operation control
    output reg         alu_src,       // ALU operand B: 0=rs2, 1=imm
    output reg         alu_start,     // ALU start (for mul/div)

    // Register file control
    output reg         reg_write,     // Register write enable

    // Memory control (for future use)
    output reg         mem_read,      // Memory read enable
    output reg         mem_write,     // Memory write enable
    output reg  [2:0]  mem_size,      // Memory access size (byte/half/word/dword)
    output reg         mem_unsigned,  // Unsigned load

    // Branch/Jump control (for future use)
    output reg         branch,        // Branch instruction
    output reg         jump,          // Jump instruction (JAL/JALR)
    output reg  [2:0]  branch_type,   // Branch condition type

    // Instruction type
    output reg         is_valid       // Valid instruction flag
);

    // ================================================================
    // Instruction Field Extraction
    // ================================================================
    wire [6:0] opcode = instr[6:0];
    wire [2:0] funct3 = instr[14:12];
    wire [6:0] funct7 = instr[31:25];
    wire [4:0] shamt  = instr[24:20];  // Shift amount for immediate shifts

    assign rs1_addr = instr[19:15];
    assign rs2_addr = instr[24:20];
    assign rd_addr  = instr[11:7];

    // ================================================================
    // Instruction Format Detection
    // ================================================================
    wire is_r_type = (opcode == 7'b0110011) || (opcode == 7'b0111011); // OP, OP-32
    wire is_i_type = (opcode == 7'b0010011) || (opcode == 7'b0011011) || // OP-IMM, OP-IMM-32
                     (opcode == 7'b0000011) || (opcode == 7'b1100111) || // LOAD, JALR
                     (opcode == 7'b1110011);                              // SYSTEM
    wire is_s_type = (opcode == 7'b0100011);                              // STORE
    wire is_b_type = (opcode == 7'b1100011);                              // BRANCH
    wire is_u_type = (opcode == 7'b0110111) || (opcode == 7'b0010111);   // LUI, AUIPC
    wire is_j_type = (opcode == 7'b1101111);                              // JAL

    // ================================================================
    // Immediate Generation (Sign-Extended to 64 bits)
    // ================================================================
    wire [63:0] imm_i = {{52{instr[31]}}, instr[31:20]};
    wire [63:0] imm_s = {{52{instr[31]}}, instr[31:25], instr[11:7]};
    wire [63:0] imm_b = {{51{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};
    wire [63:0] imm_u = {{32{instr[31]}}, instr[31:12], 12'b0};
    wire [63:0] imm_j = {{43{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};

    // Special: shift immediate (zero-extended for RV64I)
    wire [63:0] imm_shamt = {58'b0, instr[25:20]};  // 6-bit shift for 64-bit
    wire [63:0] imm_shamt32 = {59'b0, instr[24:20]}; // 5-bit shift for 32-bit

    // ================================================================
    // Opcode Categories
    // ================================================================
    localparam OP_IMM    = 7'b0010011;  // I-type integer register-immediate
    localparam OP_IMM_32 = 7'b0011011;  // I-type 32-bit register-immediate (RV64I)
    localparam OP        = 7'b0110011;  // R-type integer register-register
    localparam OP_32     = 7'b0111011;  // R-type 32-bit register-register (RV64I)
    localparam LOAD      = 7'b0000011;  // I-type load
    localparam STORE     = 7'b0100011;  // S-type store
    localparam BRANCH    = 7'b1100011;  // B-type branch
    localparam JAL       = 7'b1101111;  // J-type jump and link
    localparam JALR      = 7'b1100111;  // I-type jump and link register
    localparam LUI       = 7'b0110111;  // U-type load upper immediate
    localparam AUIPC     = 7'b0010111;  // U-type add upper immediate to PC

    // ================================================================
    // Funct3 Codes
    // ================================================================
    localparam F3_ADD_SUB = 3'b000;
    localparam F3_SLL     = 3'b001;
    localparam F3_SLT     = 3'b010;
    localparam F3_SLTU    = 3'b011;
    localparam F3_XOR     = 3'b100;
    localparam F3_SRL_SRA = 3'b101;
    localparam F3_OR      = 3'b110;
    localparam F3_AND     = 3'b111;

    // Branch funct3
    localparam F3_BEQ  = 3'b000;
    localparam F3_BNE  = 3'b001;
    localparam F3_BLT  = 3'b100;
    localparam F3_BGE  = 3'b101;
    localparam F3_BLTU = 3'b110;
    localparam F3_BGEU = 3'b111;

    // ================================================================
    // ALU Control Encoding (matches alu.v opcodes)
    // ================================================================
    // Bit [5]: Word operation flag (1 for 32-bit ops)
    // Bits [4:0]: Operation code
    localparam ALU_ADD    = 5'b00000;
    localparam ALU_SUB    = 5'b01000;
    localparam ALU_SLL    = 5'b00001;
    localparam ALU_SRL    = 5'b00101;
    localparam ALU_SRA    = 5'b01101;
    localparam ALU_AND    = 5'b00111;
    localparam ALU_OR     = 5'b00110;
    localparam ALU_XOR    = 5'b00100;

    // M Extension (Multiply/Divide)
    localparam ALU_MUL    = 5'b10000;
    localparam ALU_MULH   = 5'b10001;
    localparam ALU_MULHSU = 5'b10010;
    localparam ALU_MULHU  = 5'b10011;
    localparam ALU_DIV    = 5'b10100;
    localparam ALU_DIVU   = 5'b10101;
    localparam ALU_REM    = 5'b10110;
    localparam ALU_REMU   = 5'b10111;

    // Zba Extension (Address generation)
    localparam ALU_SH1ADD = 5'b00010;
    localparam ALU_SH2ADD = 5'b00011;
    localparam ALU_SH3ADD = 5'b01110;

    // Zbb Extension (Basic bit manipulation)
    localparam ALU_ANDN   = 5'b11001;
    localparam ALU_ORN    = 5'b11010;
    localparam ALU_XNOR   = 5'b01111;
    localparam ALU_ROL    = 5'b11011;
    localparam ALU_ROR    = 5'b11100;
    localparam ALU_CLZ    = 5'b11101;
    localparam ALU_CTZ    = 5'b11110;
    localparam ALU_CPOP   = 5'b11111;

    // Zbs Extension (Single-bit manipulation)
    localparam ALU_BSET   = 5'b01100;
    localparam ALU_BCLR   = 5'b01011;
    localparam ALU_BINV   = 5'b01010;
    localparam ALU_BEXT   = 5'b01001;

    // ================================================================
    // Main Decoder Logic
    // ================================================================
    always @(*) begin
        // Default values
        alu_ctrl     = 6'b0;
        alu_src      = 1'b0;
        alu_start    = 1'b0;
        reg_write    = 1'b0;
        mem_read     = 1'b0;
        mem_write    = 1'b0;
        mem_size     = 3'b0;
        mem_unsigned = 1'b0;
        branch       = 1'b0;
        jump         = 1'b0;
        branch_type  = 3'b0;
        is_valid     = 1'b1;
        imm          = 64'b0;

        case (opcode)
            // ================================================================
            // OP-IMM: Integer Register-Immediate Instructions (64-bit)
            // ================================================================
            OP_IMM: begin
                alu_src   = 1'b1;  // Use immediate
                reg_write = 1'b1;

                case (funct3)
                    F3_ADD_SUB: begin
                        alu_ctrl = {1'b0, ALU_ADD};
                        imm = imm_i;
                    end
                    F3_SLL: begin
                        alu_ctrl = {1'b0, ALU_SLL};
                        imm = imm_shamt;
                    end
                    F3_SLT: begin
                        // SLT: set if rs1 < imm (signed)
                        alu_ctrl = {1'b0, ALU_SUB};  // Compare via subtraction
                        imm = imm_i;
                    end
                    F3_SLTU: begin
                        // SLTU: set if rs1 < imm (unsigned)
                        alu_ctrl = {1'b0, ALU_SUB};
                        imm = imm_i;
                    end
                    F3_XOR: begin
                        alu_ctrl = {1'b0, ALU_XOR};
                        imm = imm_i;
                    end
                    F3_SRL_SRA: begin
                        if (funct7[5]) alu_ctrl = {1'b0, ALU_SRA};  // SRAI
                        else           alu_ctrl = {1'b0, ALU_SRL};  // SRLI
                        imm = imm_shamt;
                    end
                    F3_OR: begin
                        alu_ctrl = {1'b0, ALU_OR};
                        imm = imm_i;
                    end
                    F3_AND: begin
                        alu_ctrl = {1'b0, ALU_AND};
                        imm = imm_i;
                    end
                    default: is_valid = 1'b0;
                endcase
            end

            // ================================================================
            // OP-IMM-32: 32-bit Register-Immediate Instructions (RV64I)
            // ================================================================
            OP_IMM_32: begin
                alu_src   = 1'b1;
                reg_write = 1'b1;

                case (funct3)
                    F3_ADD_SUB: begin
                        alu_ctrl = {1'b1, ALU_ADD};  // Word operation
                        imm = imm_i;
                    end
                    F3_SLL: begin
                        alu_ctrl = {1'b1, ALU_SLL};
                        imm = imm_shamt32;
                    end
                    F3_SRL_SRA: begin
                        if (funct7[5]) alu_ctrl = {1'b1, ALU_SRA};
                        else           alu_ctrl = {1'b1, ALU_SRL};
                        imm = imm_shamt32;
                    end
                    default: is_valid = 1'b0;
                endcase
            end

            // ================================================================
            // OP: Integer Register-Register Instructions (64-bit)
            // ================================================================
            OP: begin
                alu_src   = 1'b0;  // Use rs2
                reg_write = 1'b1;

                // M Extension Detection
                if (funct7 == 7'b0000001) begin
                    alu_start = 1'b1;  // Mul/Div requires start signal
                    case (funct3)
                        3'b000: alu_ctrl = {1'b0, ALU_MUL};
                        3'b001: alu_ctrl = {1'b0, ALU_MULH};
                        3'b010: alu_ctrl = {1'b0, ALU_MULHSU};
                        3'b011: alu_ctrl = {1'b0, ALU_MULHU};
                        3'b100: alu_ctrl = {1'b0, ALU_DIV};
                        3'b101: alu_ctrl = {1'b0, ALU_DIVU};
                        3'b110: alu_ctrl = {1'b0, ALU_REM};
                        3'b111: alu_ctrl = {1'b0, ALU_REMU};
                        default: is_valid = 1'b0;
                    endcase
                end
                // Zba Extension
                else if (funct7 == 7'b0010000 && funct3 == F3_ADD_SUB) begin
                    alu_ctrl = {1'b0, ALU_SH1ADD};
                end
                else if (funct7 == 7'b0010000 && funct3 == 3'b100) begin
                    alu_ctrl = {1'b0, ALU_SH2ADD};
                end
                else if (funct7 == 7'b0010000 && funct3 == 3'b110) begin
                    alu_ctrl = {1'b0, ALU_SH3ADD};
                end
                // Zbb Extension
                else if (funct7 == 7'b0100000 && funct3 == F3_AND) begin
                    alu_ctrl = {1'b0, ALU_ANDN};
                end
                else if (funct7 == 7'b0100000 && funct3 == F3_OR) begin
                    alu_ctrl = {1'b0, ALU_ORN};
                end
                else if (funct7 == 7'b0100000 && funct3 == F3_XOR) begin
                    alu_ctrl = {1'b0, ALU_XNOR};
                end
                else if (funct7 == 7'b0110000 && funct3 == F3_SLL) begin
                    alu_ctrl = {1'b0, ALU_ROL};
                end
                else if (funct7 == 7'b0110000 && funct3 == F3_SRL_SRA) begin
                    alu_ctrl = {1'b0, ALU_ROR};
                end
                else if (funct7 == 7'b0110000 && funct3 == F3_ADD_SUB && rs2_addr == 5'b00000) begin
                    alu_ctrl = {1'b0, ALU_CLZ};
                end
                else if (funct7 == 7'b0110000 && funct3 == F3_ADD_SUB && rs2_addr == 5'b00001) begin
                    alu_ctrl = {1'b0, ALU_CTZ};
                end
                else if (funct7 == 7'b0110000 && funct3 == F3_ADD_SUB && rs2_addr == 5'b00010) begin
                    alu_ctrl = {1'b0, ALU_CPOP};
                end
                // Zbs Extension
                else if (funct7 == 7'b0010100 && funct3 == F3_SLL) begin
                    alu_ctrl = {1'b0, ALU_BSET};
                end
                else if (funct7 == 7'b0100100 && funct3 == F3_SLL) begin
                    alu_ctrl = {1'b0, ALU_BCLR};
                end
                else if (funct7 == 7'b0110100 && funct3 == F3_SLL) begin
                    alu_ctrl = {1'b0, ALU_BINV};
                end
                else if (funct7 == 7'b0100100 && funct3 == F3_SRL_SRA) begin
                    alu_ctrl = {1'b0, ALU_BEXT};
                end
                // Base RV64I
                else begin
                    case (funct3)
                        F3_ADD_SUB: begin
                            if (funct7[5]) alu_ctrl = {1'b0, ALU_SUB};
                            else           alu_ctrl = {1'b0, ALU_ADD};
                        end
                        F3_SLL:     alu_ctrl = {1'b0, ALU_SLL};
                        F3_SLT:     alu_ctrl = {1'b0, ALU_SUB};  // Set less than (signed)
                        F3_SLTU:    alu_ctrl = {1'b0, ALU_SUB};  // Set less than (unsigned)
                        F3_XOR:     alu_ctrl = {1'b0, ALU_XOR};
                        F3_SRL_SRA: begin
                            if (funct7[5]) alu_ctrl = {1'b0, ALU_SRA};
                            else           alu_ctrl = {1'b0, ALU_SRL};
                        end
                        F3_OR:      alu_ctrl = {1'b0, ALU_OR};
                        F3_AND:     alu_ctrl = {1'b0, ALU_AND};
                        default:    is_valid = 1'b0;
                    endcase
                end
            end

            // ================================================================
            // OP-32: 32-bit Register-Register Instructions (RV64I)
            // ================================================================
            OP_32: begin
                alu_src   = 1'b0;
                reg_write = 1'b1;

                // M Extension (32-bit)
                if (funct7 == 7'b0000001) begin
                    alu_start = 1'b1;
                    case (funct3)
                        3'b000: alu_ctrl = {1'b1, ALU_MUL};   // MULW
                        3'b100: alu_ctrl = {1'b1, ALU_DIV};   // DIVW
                        3'b101: alu_ctrl = {1'b1, ALU_DIVU};  // DIVUW
                        3'b110: alu_ctrl = {1'b1, ALU_REM};   // REMW
                        3'b111: alu_ctrl = {1'b1, ALU_REMU};  // REMUW
                        default: is_valid = 1'b0;
                    endcase
                end
                // Zbb (32-bit)
                else if (funct7 == 7'b0110000 && funct3 == F3_SLL) begin
                    alu_ctrl = {1'b1, ALU_ROL};  // ROLW
                end
                else if (funct7 == 7'b0110000 && funct3 == F3_SRL_SRA) begin
                    alu_ctrl = {1'b1, ALU_ROR};  // RORW
                end
                // Base RV64I word ops
                else begin
                    case (funct3)
                        F3_ADD_SUB: begin
                            if (funct7[5]) alu_ctrl = {1'b1, ALU_SUB};  // SUBW
                            else           alu_ctrl = {1'b1, ALU_ADD};  // ADDW
                        end
                        F3_SLL:     alu_ctrl = {1'b1, ALU_SLL};  // SLLW
                        F3_SRL_SRA: begin
                            if (funct7[5]) alu_ctrl = {1'b1, ALU_SRA};  // SRAW
                            else           alu_ctrl = {1'b1, ALU_SRL};  // SRLW
                        end
                        default: is_valid = 1'b0;
                    endcase
                end
            end

            // ================================================================
            // LUI: Load Upper Immediate
            // ================================================================
            LUI: begin
                alu_ctrl  = {1'b0, ALU_ADD};  // Pass through immediate
                alu_src   = 1'b1;
                reg_write = 1'b1;
                imm = imm_u;
            end

            // ================================================================
            // AUIPC: Add Upper Immediate to PC
            // ================================================================
            AUIPC: begin
                // TODO: Requires PC value
                alu_ctrl  = {1'b0, ALU_ADD};
                alu_src   = 1'b1;
                reg_write = 1'b1;
                imm = imm_u;
            end

            // ================================================================
            // BRANCH: Conditional Branch
            // ================================================================
            BRANCH: begin
                branch = 1'b1;
                branch_type = funct3;
                imm = imm_b;
                // ALU used for comparison (not writing back)
                alu_src = 1'b0;  // Compare rs1 and rs2
                case (funct3)
                    F3_BEQ, F3_BNE:  alu_ctrl = {1'b0, ALU_SUB};  // Use eq flag
                    F3_BLT, F3_BGE:  alu_ctrl = {1'b0, ALU_SUB};  // Use lt flag
                    F3_BLTU, F3_BGEU: alu_ctrl = {1'b0, ALU_SUB}; // Use ltu flag
                    default: is_valid = 1'b0;
                endcase
            end

            // ================================================================
            // JAL: Jump and Link
            // ================================================================
            JAL: begin
                jump      = 1'b1;
                reg_write = 1'b1;
                imm = imm_j;
                // rd = PC + 4 (handled outside ALU)
            end

            // ================================================================
            // JALR: Jump and Link Register
            // ================================================================
            JALR: begin
                jump      = 1'b1;
                reg_write = 1'b1;
                alu_src   = 1'b1;
                imm = imm_i;
                alu_ctrl = {1'b0, ALU_ADD};  // Target = rs1 + imm
            end

            // ================================================================
            // LOAD: Load from Memory
            // ================================================================
            LOAD: begin
                mem_read  = 1'b1;
                reg_write = 1'b1;
                alu_src   = 1'b1;
                alu_ctrl  = {1'b0, ALU_ADD};  // Address = rs1 + offset
                imm = imm_i;

                case (funct3)
                    3'b000: begin mem_size = 3'b000; mem_unsigned = 1'b0; end  // LB
                    3'b001: begin mem_size = 3'b001; mem_unsigned = 1'b0; end  // LH
                    3'b010: begin mem_size = 3'b010; mem_unsigned = 1'b0; end  // LW
                    3'b011: begin mem_size = 3'b011; mem_unsigned = 1'b0; end  // LD
                    3'b100: begin mem_size = 3'b000; mem_unsigned = 1'b1; end  // LBU
                    3'b101: begin mem_size = 3'b001; mem_unsigned = 1'b1; end  // LHU
                    3'b110: begin mem_size = 3'b010; mem_unsigned = 1'b1; end  // LWU
                    default: is_valid = 1'b0;
                endcase
            end

            // ================================================================
            // STORE: Store to Memory
            // ================================================================
            STORE: begin
                mem_write = 1'b1;
                alu_src   = 1'b1;
                alu_ctrl  = {1'b0, ALU_ADD};  // Address = rs1 + offset
                imm = imm_s;

                case (funct3)
                    3'b000: mem_size = 3'b000;  // SB
                    3'b001: mem_size = 3'b001;  // SH
                    3'b010: mem_size = 3'b010;  // SW
                    3'b011: mem_size = 3'b011;  // SD
                    default: is_valid = 1'b0;
                endcase
            end

            // ================================================================
            // Invalid Opcode
            // ================================================================
            default: begin
                is_valid = 1'b0;
            end
        endcase
    end

endmodule
