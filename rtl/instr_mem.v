module instr_mem #(
    parameter ADDR_WIDTH = 16,              // 16-bit address = 64KB memory
    parameter MEM_SIZE   = 1024             // Number of 32-bit instruction words
) (
    input wire clk,                         // Clock (for synchronous read, optional)
    input wire rst_n,                       // Reset

    // Instruction fetch interface
    input wire [63:0] pc,                   // Program counter (byte address)
    output reg [31:0] instr                 // Instruction output
);

    // ================================================================
    // Memory Array: Store 32-bit instructions
    // ================================================================
    // Memory is organized as array of 32-bit words
    // PC is byte-addressed, so we divide by 4 to get word address
    reg [31:0] mem [0:MEM_SIZE-1];

    // Word address from byte-addressed PC
    wire [ADDR_WIDTH-1:0] word_addr = pc[ADDR_WIDTH+1:2];

    // ================================================================
    // Instruction Fetch (Combinational Read)
    // ================================================================
    // For simplicity, use asynchronous read for combinational path
    // Can be changed to synchronous if needed for FPGA timing
    always @(*) begin
        if (word_addr < MEM_SIZE) begin
            instr = mem[word_addr];
        end else begin
            // Out of bounds: return NOP (ADDI x0, x0, 0)
            instr = 32'h00000013;
        end
    end

    // ================================================================
    // Memory Initialization
    // ================================================================
    // Option 1: Initialize with a program from file
    // Uncomment and use $readmemh to load hex file
    /*
    initial begin
        $readmemh("program.hex", mem);
    end
    */

    // Option 2: Initialize with inline test program
    // For testing, load a simple program directly
    initial begin
        // Initialize all memory to NOP
        integer i;
        for (i = 0; i < MEM_SIZE; i = i + 1) begin
            mem[i] = 32'h00000013;  // NOP (ADDI x0, x0, 0)
        end

        // Example test program:
        // Simple program to test basic operations

        // Address 0x00: ADDI x1, x0, 10    (x1 = 10)
        mem[0] = 32'h00A00093;

        // Address 0x04: ADDI x2, x0, 20    (x2 = 20)
        mem[1] = 32'h01400113;

        // Address 0x08: ADD x3, x1, x2     (x3 = x1 + x2 = 30)
        mem[2] = 32'h002081B3;

        // Address 0x0C: SUB x4, x2, x1     (x4 = x2 - x1 = 10)
        mem[3] = 32'h40110233;

        // Address 0x10: ADDI x5, x0, 5     (x5 = 5)
        mem[4] = 32'h00500293;

        // Address 0x14: MUL x6, x3, x5     (x6 = x3 * x5 = 150)
        mem[5] = 32'h025183B3;

        // Address 0x18: ADDI x7, x0, 2     (x7 = 2)
        mem[6] = 32'h00200393;

        // Address 0x1C: DIV x8, x6, x7     (x8 = x6 / x7 = 75)
        mem[7] = 32'h0271C433;

        // Address 0x20: SLLI x9, x1, 2     (x9 = x1 << 2 = 40)
        mem[8] = 32'h00209493;

        // Address 0x24: SRLI x10, x2, 1    (x10 = x2 >> 1 = 10)
        mem[9] = 32'h00115513;

        // Address 0x28: AND x11, x1, x2    (x11 = x1 & x2)
        mem[10] = 32'h002075B3;

        // Address 0x2C: OR x12, x1, x2     (x12 = x1 | x2)
        mem[11] = 32'h00206633;

        // Address 0x30: XOR x13, x1, x2    (x13 = x1 ^ x2)
        mem[12] = 32'h002046B3;

        // Address 0x34: Infinite loop (JAL x0, -4)
        // Jump back to same instruction (PC = PC - 4)
        mem[13] = 32'hFFDFF06F;

        $display("Instruction memory initialized with test program");
        $display("Memory size: %0d words (%0d bytes)", MEM_SIZE, MEM_SIZE * 4);
    end

    // ================================================================
    // Optional: Memory access monitoring (for debugging)
    // ================================================================
    `ifdef DEBUG_INSTR_MEM
    always @(*) begin
        if (word_addr < MEM_SIZE) begin
            $display("[IMEM] PC=0x%016X, word_addr=0x%04X, instr=0x%08X",
                     pc, word_addr, mem[word_addr]);
        end
    end
    `endif

endmodule
