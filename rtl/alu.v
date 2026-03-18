module alu (
    input wire [63:0] a,
    input wire [63:0] b,
    input wire [4:0] alu_ctrl,
    output reg [63:0] result,
    output wire  zero   
);
// Combinational logic for the alu operations
    
    // Intermediate wires for 128-bit multiplication (M-extension)
    wire [127:0] mul_full_ss = $signed(a) * $signed(b);
    wire [127:0] mul_full_su = $signed(a) * $signed({1'b0, b});
    wire [127:0] mul_full_uu = a * b;

    always @(*) begin
        case (alu_ctrl)
            // RV64I Base Integer Instructions
            5'b00000: result = a + b; // ADD
            5'b01000: result = a - b; // SUB
            5'b00111: result = a & b; // AND
            5'b00110: result = a | b; // OR
            5'b00100: result = a ^ b; // XOR
            5'b00001: result = a << b[5:0]; // SLL (6-bit shift amount for 64-bit)
            5'b00101: result = a >> b[5:0]; // SRL
            5'b01101: result = $signed(a) >>> b[5:0]; // SRA
            5'b00010: result = ($signed(a) < $signed(b)) ? 64'd1 : 64'd0; // SLT
            5'b00011: result = (a < b) ? 64'd1 : 64'd0; // SLTU

            // RV64M Multiplication and Division Extension
            5'b10000: result = a * b;               // MUL (lower 64 bits)
            5'b10001: result = mul_full_ss[127:64]; // MULH
            5'b10010: result = mul_full_su[127:64]; // MULHSU
            5'b10011: result = mul_full_uu[127:64]; // MULHU
            
            5'b10100: begin // DIV
                if (b == 64'b0) result = 64'hFFFF_FFFF_FFFF_FFFF; // -1
                else if (a == 64'h8000_0000_0000_0000 && b == 64'hFFFF_FFFF_FFFF_FFFF) result = a; // overflow
                else result = $signed(a) / $signed(b);
            end
            5'b10101: begin // DIVU
                if (b == 64'b0) result = 64'hFFFF_FFFF_FFFF_FFFF; // Max unsigned
                else result = a / b;
            end
            5'b10110: begin // REM
                if (b == 64'b0) result = a;
                else if (a == 64'h8000_0000_0000_0000 && b == 64'hFFFF_FFFF_FFFF_FFFF) result = 64'b0;
                else result = $signed(a) % $signed(b);
            end
            5'b10111: begin // REMU
                if (b == 64'b0) result = a;
                else result = a % b;
            end

            default: result = 64'd0; // Default case
            
        endcase
    end
    
    // Status flag of branching
    assign zero = (result == 64'b0);

endmodule
