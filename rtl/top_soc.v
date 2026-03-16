module top_soc (
    input clk,
    input reset,
    output reg [7:0] counter
  );

  always @(posedge clk)
  begin
    if (reset)
      counter <= 8'b0;
    else
      counter <= counter + 1'b1;
  end

endmodule
