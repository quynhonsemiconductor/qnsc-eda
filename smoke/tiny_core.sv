// Tiny core used by the image's smoke regression (smoke/run.sh).
module tiny_core (
    input  logic       clk,
    input  logic       rst_n,
    output logic [7:0] count
);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) count <= 8'd0;
    else        count <= count + 8'd1;
  end

endmodule
