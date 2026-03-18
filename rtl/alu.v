module alu (
    input wire [31:0] a,
    input wire [31:0] b,
    input wire [3:0] alu_ctrl
    output reg [31:0] result,
    output wire  zero;   
);
// Combinational logic for the alu operations
    always @(*) begin
        case (alu_ctrl)
            // Arithmetic operations
            4'b0000: result = a + b; // ADD
            4'b1000: result = a - b; // SUB
            // Logical operations
            4'b0111: result = a & b; // AND
            4'b0110: result = a | b; // OR
            4'b0100: result = a ^ b; // XOR
            // Shift operations
            4'b0001: result = a << b[4:0]; // Shift left logical
            4'b0101: result = a >> b[4:0]; // Shift right logical
            4'b1101: result = $signed(a) >>> b[4:0]; // Shift right arithmetic
            // Comparison operations
            4'b0010: result = (&signed(a) < &signed(b)) ? 32'd1 : 32'd0; // SLT
            4'b0011: result = (a < b) ? 32'd1 : 32'd0; // SLTU

            default: result = 32'd0; // Default case
            
        endcase
    end
    // Status flag of branching
    assign zero = (result == 32'b0);

endmodule

