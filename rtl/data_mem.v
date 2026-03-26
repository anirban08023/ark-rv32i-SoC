module data_mem #(
    parameter ADDR_WIDTH = 16,              // 16-bit address = 64KB memory
    parameter MEM_SIZE   = 4096             // Number of bytes (4KB default)
) (
    input wire clk,
    input wire rst_n,

    // Memory interface from decoder/ALU
    input wire [63:0] addr,                 // Byte address from ALU result
    input wire [63:0] write_data,           // Data to write (from rs2)
    input wire        mem_read,             // Read enable
    input wire        mem_write,            // Write enable
    input wire [2:0]  mem_size,             // Access size: 000=byte, 001=half, 010=word, 011=dword
    input wire        mem_unsigned,         // Unsigned load flag

    // Memory output
    output reg [63:0] read_data,            // Data read from memory
    output reg        mem_ready             // Memory operation complete
);

    // ================================================================
    // Memory Array: Byte-addressable RAM
    // ================================================================
    reg [7:0] mem [0:MEM_SIZE-1];

    // Extract byte address within bounds
    wire [ADDR_WIDTH-1:0] byte_addr = addr[ADDR_WIDTH-1:0];

    // ================================================================
    // Memory Size Encoding
    // ================================================================
    localparam SIZE_BYTE  = 3'b000;  // LB/LBU/SB  - 8 bits
    localparam SIZE_HALF  = 3'b001;  // LH/LHU/SH  - 16 bits
    localparam SIZE_WORD  = 3'b010;  // LW/LWU/SW  - 32 bits
    localparam SIZE_DWORD = 3'b011;  // LD/SD      - 64 bits

    // ================================================================
    // Memory Read Logic
    // ================================================================
    always @(*) begin
        read_data = 64'b0;

        if (mem_read && byte_addr < MEM_SIZE) begin
            case (mem_size)
                SIZE_BYTE: begin
                    // Load byte
                    if (mem_unsigned)
                        read_data = {56'b0, mem[byte_addr]};  // Zero-extend
                    else
                        read_data = {{56{mem[byte_addr][7]}}, mem[byte_addr]};  // Sign-extend
                end

                SIZE_HALF: begin
                    // Load halfword (16 bits, little-endian)
                    if (byte_addr + 1 < MEM_SIZE) begin
                        if (mem_unsigned)
                            read_data = {48'b0, mem[byte_addr+1], mem[byte_addr]};
                        else
                            read_data = {{48{mem[byte_addr+1][7]}}, mem[byte_addr+1], mem[byte_addr]};
                    end
                end

                SIZE_WORD: begin
                    // Load word (32 bits, little-endian)
                    if (byte_addr + 3 < MEM_SIZE) begin
                        if (mem_unsigned)
                            read_data = {32'b0, mem[byte_addr+3], mem[byte_addr+2],
                                               mem[byte_addr+1], mem[byte_addr]};
                        else
                            read_data = {{32{mem[byte_addr+3][7]}}, mem[byte_addr+3], mem[byte_addr+2],
                                               mem[byte_addr+1], mem[byte_addr]};
                    end
                end

                SIZE_DWORD: begin
                    // Load doubleword (64 bits, little-endian)
                    if (byte_addr + 7 < MEM_SIZE) begin
                        read_data = {mem[byte_addr+7], mem[byte_addr+6], mem[byte_addr+5], mem[byte_addr+4],
                                    mem[byte_addr+3], mem[byte_addr+2], mem[byte_addr+1], mem[byte_addr]};
                    end
                end

                default: read_data = 64'b0;
            endcase
        end
    end

    // ================================================================
    // Memory Write Logic (Synchronous)
    // ================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Optional: Initialize memory to zero on reset
            // Note: This is slow in simulation for large memories
            // Comment out for faster simulation if not needed
            /*
            integer i;
            for (i = 0; i < MEM_SIZE; i = i + 1) begin
                mem[i] <= 8'b0;
            end
            */
        end else if (mem_write && byte_addr < MEM_SIZE) begin
            case (mem_size)
                SIZE_BYTE: begin
                    // Store byte
                    mem[byte_addr] <= write_data[7:0];
                end

                SIZE_HALF: begin
                    // Store halfword (little-endian)
                    if (byte_addr + 1 < MEM_SIZE) begin
                        mem[byte_addr]   <= write_data[7:0];
                        mem[byte_addr+1] <= write_data[15:8];
                    end
                end

                SIZE_WORD: begin
                    // Store word (little-endian)
                    if (byte_addr + 3 < MEM_SIZE) begin
                        mem[byte_addr]   <= write_data[7:0];
                        mem[byte_addr+1] <= write_data[15:8];
                        mem[byte_addr+2] <= write_data[23:16];
                        mem[byte_addr+3] <= write_data[31:24];
                    end
                end

                SIZE_DWORD: begin
                    // Store doubleword (little-endian)
                    if (byte_addr + 7 < MEM_SIZE) begin
                        mem[byte_addr]   <= write_data[7:0];
                        mem[byte_addr+1] <= write_data[15:8];
                        mem[byte_addr+2] <= write_data[23:16];
                        mem[byte_addr+3] <= write_data[31:24];
                        mem[byte_addr+4] <= write_data[39:32];
                        mem[byte_addr+5] <= write_data[47:40];
                        mem[byte_addr+6] <= write_data[55:48];
                        mem[byte_addr+7] <= write_data[63:56];
                    end
                end
            endcase
        end
    end

    // ================================================================
    // Memory Ready Signal
    // ================================================================
    // For simple single-cycle memory, always ready
    // Can be extended for multi-cycle or cached memory
    always @(*) begin
        mem_ready = 1'b1;  // Single-cycle memory access
    end

    // ================================================================
    // Memory Initialization (Optional)
    // ================================================================
    initial begin
        // Initialize memory with test data or load from file
        // Example: Initialize with zeros
        integer i;
        for (i = 0; i < MEM_SIZE; i = i + 1) begin
            mem[i] = 8'h00;
        end

        // Example: Initialize stack pointer area (high memory)
        // Useful if you want to test stack operations
        // mem[MEM_SIZE-1] = 8'h00;
        // mem[MEM_SIZE-2] = 8'h10;
        // mem[MEM_SIZE-3] = 8'h00;
        // mem[MEM_SIZE-4] = 8'h00;  // Stack starts at 0x00001000

        $display("Data memory initialized: %0d bytes", MEM_SIZE);
    end

    // ================================================================
    // Optional: Memory access monitoring (for debugging)
    // ================================================================
    `ifdef DEBUG_DATA_MEM
    always @(posedge clk) begin
        if (mem_read && byte_addr < MEM_SIZE) begin
            $display("[DMEM READ ] addr=0x%016X, size=%0d, unsigned=%0b, data=0x%016X",
                     addr, mem_size, mem_unsigned, read_data);
        end
        if (mem_write && byte_addr < MEM_SIZE) begin
            $display("[DMEM WRITE] addr=0x%016X, size=%0d, data=0x%016X",
                     addr, mem_size, write_data);
        end
    end
    `endif

endmodule
