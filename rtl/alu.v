module alu (
    input wire clk,
    input wire rst_n,
    input wire [63:0] a,
    input wire [63:0] b,
    input wire [5:0] alu_ctrl,
    input wire start,         
    output reg [63:0] result,
    output wire ready,        
    output wire zero,
    output wire eq,
    output wire lt,
    output wire ltu
);

    // Control Decoding
    wire is_word = alu_ctrl[5];
    wire [4:0] opcode = alu_ctrl[4:0];
    wire is_mul_instr = (opcode[4:1] == 4'b1000);
    wire is_div_instr = (opcode[4:2] == 3'b101);  // 0x14-0x17: DIV, DIVU, REM, REMU
    wire is_slow_instr = is_mul_instr || is_div_instr;

    // Comparison flags (Fast Path)
    assign eq  = (a == b);
    assign lt  = ($signed(a) < $signed(b));
    assign ltu = (a < b);
    assign zero = (result == 64'b0);

    // ---------------------------------------------------------
    // BITMANIP HELPERS
    // ---------------------------------------------------------
    function [6:0] count_leading_zeros(input [63:0] data);
        integer i;
        begin
            count_leading_zeros = 64;
            for (i = 63; i >= 0; i = i - 1) begin
                if (data[i]) begin
                    count_leading_zeros = 7'(63 - i);
                    i = -1; 
                end
            end
        end
    endfunction

    function [6:0] count_trailing_zeros(input [63:0] data);
        integer i;
        begin
            count_trailing_zeros = 64;
            for (i = 0; i < 64; i = i + 1) begin
                if (data[i]) begin
                    count_trailing_zeros = i[6:0];
                    i = 64; 
                end
            end
        end
    endfunction

    function [6:0] count_population(input [63:0] data);
        integer i;
        begin
            count_population = 0;
            for (i = 0; i < 64; i = i + 1) begin
                if (data[i]) count_population = count_population + 1;
            end
        end
    endfunction

    // ---------------------------------------------------------
    // FAST PATH: Single-cycle combinational operations
    // ---------------------------------------------------------
    wire [31:0] sum_w  = a[31:0] + b[31:0];
    wire [31:0] diff_w = a[31:0] - b[31:0];
    wire [5:0]  shamt  = is_word ? {1'b0, b[4:0]} : b[5:0];
    
    // Rotate Logic
    wire [63:0] ror_64 = (a >> shamt) | (a << (64 - shamt));
    wire [31:0] ror_32 = (a[31:0] >> b[4:0]) | (a[31:0] << (32 - b[4:0]));
    wire [31:0] rol_32 = (a[31:0] << b[4:0]) | (a[31:0] >> (32 - b[4:0]));

    reg [63:0] fast_result;
    always @(*) begin
        if (is_word) begin
            case (opcode)
                5'b00000: fast_result = {{32{sum_w[31]}}, sum_w};           
                5'b01000: fast_result = {{32{diff_w[31]}}, diff_w};         
                5'b00001: fast_result = {{32{1'b0}}, a[31:0]} << b[4:0];    
                5'b00101: fast_result = {{32{1'b0}}, a[31:0] >> b[4:0]};    
                5'b01101: fast_result = {{32{a[31]}}, ($signed(a[31:0]) >>> b[4:0])}; 
                
                // Zbb Word
                5'b11011: fast_result = {{32{rol_32[31]}}, rol_32};         // ROLW
                5'b11100: fast_result = {{32{ror_32[31]}}, ror_32};         // RORW
                5'b11101: fast_result = {57'd0, count_leading_zeros({a[31:0], 32'b0})}; 
                5'b11110: fast_result = {57'd0, count_trailing_zeros({32'b1, a[31:0]})}; 
                5'b11111: fast_result = {57'd0, count_population({32'b0, a[31:0]})};    
                
                default:  fast_result = 64'd0;
            endcase
            // Normalize sign extension for shifts
            if (opcode == 5'b00001 || opcode == 5'b00101 || opcode == 5'b01101) 
                fast_result = {{32{fast_result[31]}}, fast_result[31:0]};
        end else begin
            case (opcode)
                5'b00000: fast_result = a + b;
                5'b01000: fast_result = a - b;
                5'b00111: fast_result = a & b;
                5'b00110: fast_result = a | b;
                5'b00100: fast_result = a ^ b;
                5'b00001: fast_result = a << b[5:0];
                5'b00101: fast_result = a >> b[5:0];
                5'b01101: fast_result = $signed(a) >>> b[5:0];

                // Zba (relocated to free opcodes to avoid division conflict)
                5'b00010: fast_result = (a << 1) + b;  // SH1ADD (0x02)
                5'b00011: fast_result = (a << 2) + b;  // SH2ADD (0x03)
                5'b01110: fast_result = (a << 3) + b;  // SH3ADD (0x0E)

                // Zbb
                5'b11001: fast_result = a & ~b;        // ANDN (0x19)
                5'b11010: fast_result = a | ~b;        // ORN (0x1A)       
                5'b01111: fast_result = ~(a ^ b);     
                5'b11011: fast_result = (a << shamt) | (a >> (64 - shamt)); 
                5'b11100: fast_result = ror_64;       
                5'b11101: fast_result = {57'd0, count_leading_zeros(a)};    
                5'b11110: fast_result = {57'd0, count_trailing_zeros(a)};   
                5'b11111: fast_result = {57'd0, count_population(a)};       
                
                // Zbs
                5'b01100: fast_result = a | (64'b1 << shamt);    
                5'b01011: fast_result = a & ~(64'b1 << shamt);   
                5'b01010: fast_result = a ^ (64'b1 << shamt);    
                5'b01001: fast_result = (a >> shamt) & 64'b1;    

                default:  fast_result = 64'd0;
            endcase
        end
    end

    // ---------------------------------------------------------
    // SLOW PATH: Pipelined Multiplier (3-Stage)
    // ---------------------------------------------------------
    reg [127:0] mul_stage1, mul_stage2;
    reg [63:0] mul_stage3;
    reg mul_v1, mul_v2, mul_v3;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mul_v1 <= 0; mul_v2 <= 0; mul_v3 <= 0;
            mul_stage1 <= 0; mul_stage2 <= 0; mul_stage3 <= 0;
        end else begin
            mul_v1 <= start && is_mul_instr;
            if (opcode == 5'b10001) mul_stage1 <= $signed(a) * $signed(b); 
            else if (opcode == 5'b10010) mul_stage1 <= $signed(a) * $signed({1'b0, b}); 
            else mul_stage1 <= a * b; 

            mul_v2 <= mul_v1;
            mul_stage2 <= mul_stage1;

            mul_v3 <= mul_v2;
            if (is_word) mul_stage3 <= {{32{mul_stage2[31]}}, mul_stage2[31:0]};
            else if (opcode[1:0] == 2'b00) mul_stage3 <= mul_stage2[63:0]; 
            else mul_stage3 <= mul_stage2[127:64]; 
        end
    end

    // ---------------------------------------------------------
    // SLOW PATH: Iterative Divider (64-Cycle Restoring)
    // Supports: DIV, DIVU, REM, REMU, DIVW, DIVUW, REMW, REMUW
    // ---------------------------------------------------------

    // Division control signals
    wire div_is_signed = !opcode[0];  // DIV/REM are signed, DIVU/REMU are unsigned

    // Prepare operands (handle word and signed cases)
    wire [63:0] div_a_raw = is_word ? {{32{div_is_signed & a[31]}}, a[31:0]} : a;
    wire [63:0] div_b_raw = is_word ? {{32{div_is_signed & b[31]}}, b[31:0]} : b;

    // Sign handling for signed division
    wire div_a_neg = div_is_signed & div_a_raw[63];
    wire div_b_neg = div_is_signed & div_b_raw[63];
    wire [63:0] div_a_abs = div_a_neg ? (~div_a_raw + 1'b1) : div_a_raw;
    wire [63:0] div_b_abs = div_b_neg ? (~div_b_raw + 1'b1) : div_b_raw;

    // Special case detection
    wire div_by_zero = (div_b_raw == 64'd0);
    wire [63:0] min_signed = is_word ? {{32{1'b1}}, 32'h80000000} : 64'h8000000000000000;
    wire div_overflow = div_is_signed && (div_a_raw == min_signed) && (div_b_raw == {64{1'b1}});

    // Divider state
    reg [5:0] div_count;
    reg [63:0] div_q, div_r, div_b_reg;
    reg div_busy, div_done;
    reg div_q_neg, div_r_neg;  // Sign flags for result adjustment
    reg div_special;           // Special case flag (div by zero or overflow)
    reg [63:0] div_special_q, div_special_r;  // Special case results

    wire [64:0] div_sub = {div_r[62:0], div_q[63]} - div_b_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            div_busy <= 0; div_done <= 0;
            div_count <= 0; div_q <= 0; div_r <= 0; div_b_reg <= 0;
            div_q_neg <= 0; div_r_neg <= 0;
            div_special <= 0; div_special_q <= 0; div_special_r <= 0;
        end else if (start && is_div_instr && !div_busy) begin
            // Handle special cases immediately
            if (div_by_zero) begin
                div_special <= 1;
                div_special_q <= {64{1'b1}};  // -1 for quotient
                div_special_r <= div_a_raw;   // dividend for remainder
                div_done <= 1;
            end else if (div_overflow) begin
                div_special <= 1;
                div_special_q <= min_signed;  // -2^63 or -2^31
                div_special_r <= 64'd0;       // 0 for remainder
                div_done <= 1;
            end else begin
                div_special <= 0;
                div_busy <= 1;
                div_done <= 0;
                div_count <= is_word ? 6'd31 : 6'd63;
                div_b_reg <= div_b_abs;
                div_q <= is_word ? {32'd0, div_a_abs[31:0]} : div_a_abs;
                div_r <= 0;
                // Quotient is negative if signs differ
                div_q_neg <= div_a_neg ^ div_b_neg;
                // Remainder has same sign as dividend
                div_r_neg <= div_a_neg;
            end
        end else if (div_busy) begin
            if (div_sub[64]) begin
                div_r <= {div_r[62:0], div_q[63]};
                div_q <= {div_q[62:0], 1'b0};
            end else begin
                div_r <= div_sub[63:0];
                div_q <= {div_q[62:0], 1'b1};
            end

            if (div_count == 0) begin
                div_busy <= 0;
                div_done <= 1;
            end else begin
                div_count <= div_count - 1;
            end
        end else begin
            div_done <= 0;
        end
    end

    // Final quotient and remainder with sign correction
    wire [63:0] div_q_unsigned = div_q;
    wire [63:0] div_r_unsigned = div_r;
    wire [63:0] div_q_signed = div_q_neg ? (~div_q + 1'b1) : div_q;
    wire [63:0] div_r_signed = div_r_neg ? (~div_r + 1'b1) : div_r;

    wire [63:0] div_q_final = div_special ? div_special_q :
                              (div_is_signed ? div_q_signed : div_q_unsigned);
    wire [63:0] div_r_final = div_special ? div_special_r :
                              (div_is_signed ? div_r_signed : div_r_unsigned);

    // Sign-extend for word operations
    wire [63:0] div_q_result = is_word ? {{32{div_q_final[31]}}, div_q_final[31:0]} : div_q_final;
    wire [63:0] div_r_result = is_word ? {{32{div_r_final[31]}}, div_r_final[31:0]} : div_r_final;

    // ---------------------------------------------------------
    // Result Multiplexer and Ready Logic
    // ---------------------------------------------------------
    wire div_ready = is_div_instr ? div_done : 1'b0;
    wire mul_ready = is_mul_instr ? mul_v3 : 1'b0;
    
    assign ready = is_slow_instr ? (div_ready || mul_ready) : 1'b1;

    always @(*) begin
        if (is_mul_instr) result = mul_stage3[63:0];
        else if (is_div_instr) result = (opcode[1]) ? div_r_result : div_q_result;
        else result = fast_result;
    end

endmodule
