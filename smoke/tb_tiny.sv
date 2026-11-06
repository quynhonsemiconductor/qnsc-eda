// Self-checking testbench for tiny_core.  Runs under `verilator --binary
// --timing`; prints SMOKE PASS only when the counter reached the expected
// value after reset release.
`timescale 1ns/1ps

module tb_tiny;

  logic       clk   = 1'b0;
  logic       rst_n = 1'b0;
  logic [7:0] count;

  tiny_core dut (
      .clk  (clk),
      .rst_n(rst_n),
      .count(count)
  );

  always #5 clk = ~clk;

  initial begin
    repeat (2) @(posedge clk);
    @(negedge clk);
    rst_n <= 1'b1;

    repeat (10) @(posedge clk);
    #1;

    if (count !== 8'd10) begin
      $display("SMOKE FAIL: count=%0d, expected 10", count);
      $fatal(1);
    end

    $display("SMOKE PASS: count=%0d after 10 clocks", count);
    $finish;
  end

endmodule
