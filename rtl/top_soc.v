module top_soc (
    input wire clk,
    input wire rst_n,
    
    // External interface to exercise the ALU
    input wire [63:0] alu_a,
    input wire [63:0] alu_b,
    input wire [5:0]  alu_ctrl,
    input wire        alu_start,
    
    output wire [63:0] alu_result,
    output wire        alu_ready,
    output wire        alu_zero
);

    // Comparison flags (unused in this SoC configuration)
    /* verilator lint_off UNUSEDSIGNAL */
    wire alu_eq, alu_lt, alu_ltu;
    /* verilator lint_on UNUSEDSIGNAL */

    // Instantiate the Optimized ALU
    alu u_alu (
        .clk      (clk),
        .rst_n    (rst_n),
        .a        (alu_a),
        .b        (alu_b),
        .alu_ctrl (alu_ctrl),
        .start    (alu_start),
        .result   (alu_result),
        .ready    (alu_ready),
        .zero     (alu_zero),
        .eq       (alu_eq),
        .lt       (alu_lt),
        .ltu      (alu_ltu)
    );

    // Placeholder for other SoC components (Decoder, Memory, etc.)

endmodule
