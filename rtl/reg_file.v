module reg_file (
    input wire clk,
    input wire rst_n,
    
    input wire [4:0] rs1_addr,
    input wire [4:0] rs2_addr,
    input wire [4:0] rd_addr,
    input wire [63:0] rd_data,
    input wire reg_write,
    
    output wire [63:0] rs1_data,
    output wire [63:0] rs2_data
);

    reg [63:0] regs [31:0];
    integer i;

    // Synchronous Write
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 32; i = i + 1) begin
                regs[i] <= 64'd0;
            end
        end else if (reg_write && rd_addr != 5'd0) begin
            regs[rd_addr] <= rd_data;
        end
    end

    // Asynchronous Read
    // x0 is hardwired to 0
    assign rs1_data = (rs1_addr == 5'd0) ? 64'd0 : regs[rs1_addr];
    assign rs2_data = (rs2_addr == 5'd0) ? 64'd0 : regs[rs2_addr];

endmodule
