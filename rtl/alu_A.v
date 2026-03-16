module alu_A 
  (
    input clk,
    input reset,
    output reg [7:0] h_counter
  );

  always @(posedge clk)
  begin
    if (clk)
      counter <= 8'b0;
    else
      counter <= counter + 2'b1;
  end

endmodule
