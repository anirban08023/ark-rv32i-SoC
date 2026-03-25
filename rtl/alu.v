module alu (
    input wire [63:0] a,
    input wire [63:0] b,
    input wire [5:0] alu_ctrl, // 5-bit opcode + 1-bit Word mode flag (bit 5)
    output reg [63:0] result,
    output wire zero,
    output wire eq,          // Equal flag
    output wire lt,          // Signed Less Than flag
    output wire ltu          // Unsigned Less Than flag
);
    // Control Signal Decoding
    wire is_word = alu_ctrl[5];
    wire [4:0] opcode = alu_ctrl[4:0];

    // Comparison flags for branching
    assign eq  = (a == b);
    assign lt  = ($signed(a) < $signed(b));
    assign ltu = (a < b);
    assign zero = (result == 64'b0);

    // Intermediate wires for 128-bit multiplication (M-extension)
    /* verilator lint_off UNUSEDSIGNAL */
    wire [127:0] mul_full_ss = $signed(a) * $signed(b);
    wire [127:0] mul_full_su = $signed(a) * $signed({1'b0, b});
    wire [127:0] mul_full_uu = a * b;
    /* verilator lint_on UNUSEDSIGNAL */

    // 32-bit operations (sign-extended to 64-bit for RV64 Word instructions)
    wire [31:0] sum_w  = a[31:0] + b[31:0];
    wire [31:0] diff_w = a[31:0] - b[31:0];
    wire [31:0] sll_w  = a[31:0] << b[4:0];
    wire [31:0] srl_w  = a[31:0] >> b[4:0];
    wire [31:0] sra_w  = $signed(a[31:0]) >>> b[4:0];
    wire [31:0] mul_w  = a[31:0] * b[31:0];

    always @(*) begin
        if (is_word) begin
            // 32-bit Word Instructions (RV64I / RV64M Word variants)
            case (opcode)
                5'b00000: result = {{32{sum_w[31]}}, sum_w};           // ADDW
                5'b01000: result = {{32{diff_w[31]}}, diff_w};         // SUBW
                5'b00001: result = {{32{sll_w[31]}}, sll_w};           // SLLW
                5'b00101: result = {{32{srl_w[31]}}, srl_w};           // SRLW
                5'b01101: result = {{32{sra_w[31]}}, sra_w};           // SRAW
                
                5'b10000: result = {{32{mul_w[31]}}, mul_w};           // MULW
                5'b10100: begin // DIVW
                    if (b[31:0] == 32'b0) result = 64'hFFFF_FFFF_FFFF_FFFF;
                    else if (a[31:0] == 32'h8000_0000 && b[31:0] == 32'hFFFF_FFFF) result = 64'hFFFF_FFFF_8000_0000;
                    else begin
                        result[31:0] = $signed(a[31:0]) / $signed(b[31:0]);
                        result[63:32] = {32{result[31]}};
                    end
                end
                5'b10101: begin // DIVUW
                    if (b[31:0] == 32'b0) result = 64'hFFFF_FFFF_FFFF_FFFF;
                    else begin
                        result[31:0] = a[31:0] / b[31:0];
                        result[63:32] = {32{result[31]}};
                    end
                end
                5'b10110: begin // REMW
                    if (b[31:0] == 32'b0) result = {{32{a[31]}}, a[31:0]};
                    else if (a[31:0] == 32'h8000_0000 && b[31:0] == 32'hFFFF_FFFF) result = 64'b0;
                    else begin
                        result[31:0] = $signed(a[31:0]) % $signed(b[31:0]);
                        result[63:32] = {32{result[31]}};
                    end
                end
                5'b10111: begin // REMUW
                    if (b[31:0] == 32'b0) result = {{32{a[31]}}, a[31:0]};
                    else begin
                        result[31:0] = a[31:0] % b[31:0];
                        result[63:32] = {32{result[31]}};
                    end
                end
                
                // AMO operations for Word
                5'b01001: result = ($signed(a[31:0]) < $signed(b[31:0])) ? {{32{a[31]}}, a[31:0]} : {{32{b[31]}}, b[31:0]}; // MINW
                5'b01010: result = ($signed(a[31:0]) > $signed(b[31:0])) ? {{32{a[31]}}, a[31:0]} : {{32{b[31]}}, b[31:0]}; // MAXW
                5'b01011: result = (a[31:0] < b[31:0]) ? {{32{a[31]}}, a[31:0]} : {{32{b[31]}}, b[31:0]}; // MINUW
                5'b01100: result = (a[31:0] > b[31:0]) ? {{32{a[31]}}, a[31:0]} : {{32{b[31]}}, b[31:0]}; // MAXUW
                5'b01110: result = {{32{b[31]}}, b[31:0]}; // SWAPW
                
                default: result = 64'd0;
            endcase
        end else begin
            // 64-bit Instructions
            case (opcode)
                5'b00000: result = a + b; // ADD
                5'b01000: result = a - b; // SUB
                5'b00111: result = a & b; // AND
                5'b00110: result = a | b; // OR
                5'b00100: result = a ^ b; // XOR
                5'b00001: result = a << b[5:0]; // SLL
                5'b00101: result = a >> b[5:0]; // SRL
                5'b01101: result = $signed(a) >>> b[5:0]; // SRA
                5'b00010: result = (lt) ? 64'd1 : 64'd0; // SLT
                5'b00011: result = (ltu) ? 64'd1 : 64'd0; // SLTU

                // RV64M Multiplication and Division
                5'b10000: result = mul_full_uu[63:0];   // MUL
                5'b10001: result = mul_full_ss[127:64]; // MULH
                5'b10010: result = mul_full_su[127:64]; // MULHSU
                5'b10011: result = mul_full_uu[127:64]; // MULHU
                
                5'b10100: begin // DIV
                    if (b == 64'b0) result = 64'hFFFF_FFFF_FFFF_FFFF;
                    else if (a == 64'h8000_0000_0000_0000 && b == 64'hFFFF_FFFF_FFFF_FFFF) result = a;
                    else result = $signed(a) / $signed(b);
                end
                5'b10101: begin // DIVU
                    if (b == 64'b0) result = 64'hFFFF_FFFF_FFFF_FFFF;
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

                // AMO Operations (RV64A)
                5'b01001: result = (lt) ? a : b;   // MIN
                5'b01010: result = (lt) ? b : a;   // MAX
                5'b01011: result = (ltu) ? a : b;  // MINU
                5'b01100: result = (ltu) ? b : a;  // MAXU
                5'b01110: result = b;              // SWAP

                default: result = 64'd0;
            endcase
        end
    end

endmodule
