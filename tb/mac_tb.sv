`timescale 1ns/1ps

module mac_tb;
   localparam WIDTH = 8;
   localparam OUT_WIDTH = 32;
   
   logic clk = 0;
   logic reset = 1;
   logic acce = 1;
   
   logic signed [WIDTH-1:0] n, w;
   logic signed [WIDTH-1:0] s, e;
   logic signed [OUT_WIDTH-1:0] p;
   
   mac #(.WIDTH(WIDTH), .OUT_WIDTH(OUT_WIDTH)) dut(
      .clk(clk), .reset(reset), .acce(acce),
      .n(n), .w(w), .s(s), .e(e), .p(p)
   );
   
   always #5 clk = ~clk;
   
   initial begin
      $dumpfile("mac_tb.vcd");
      $dumpvars(0, mac_tb);
      
      $display("=== MAC Cell Testbench (with negative int8 support) ===");
      
      reset = 1;
      n = 0;
      w = 0;
      #20;
      
      @(posedge clk);
      reset = 0;
      
      // Test 1: Positive values
      @(posedge clk);
      n = 8'd3;
      w = 8'd4;
      
      @(posedge clk);
      $display("Test 1 - After n=3, w=4: p=%0d (expect 12), s=%0d, e=%0d", p, s, e);
      
      // Test 2: One negative value
      n = -8'd5;  // -5 in signed 8-bit
      w = 8'd6;
      
      @(posedge clk);
      $display("Test 2 - After n=-5, w=6: p=%0d (expect -18), s=%0d, e=%0d", p, s, e);
      
      // Test 3: Both negative values
      n = -8'd2;  // -2 in signed 8-bit
      w = -8'd7;  // -7 in signed 8-bit
      
      @(posedge clk);
      $display("Test 3 - After n=-2, w=-7: p=%0d (expect -4), s=%0d, e=%0d", p, s, e);
      
      // Test 4: Large negative values
      n = -8'd10; // -10 in signed 8-bit
      w = -8'd10; // -10 in signed 8-bit
      
      @(posedge clk);
      $display("Test 4 - After n=-10, w=-10: p=%0d (expect 96), s=%0d, e=%0d", p, s, e);
      
      // Test 5: Mixed positive and negative
      n = -8'd8;  // -8 in signed 8-bit
      w = 8'd3;    // 3 in unsigned 8-bit
      
      @(posedge clk);
      $display("Test 5 - After n=-8, w=3: p=%0d (expect 72), s=%0d, e=%0d", p, s, e);
      
      // Test 6: Edge case - maximum negative values
      n = -8'd128; // -128 (minimum int8)
      w = -8'd1;   // -1
      
      @(posedge clk);
      $display("Test 6 - After n=-128, w=-1: p=%0d (expect 200), s=%0d, e=%0d", p, s, e);
      
      // Test 7: Reset and verify
      @(posedge clk);
      reset = 1;
      
      @(posedge clk);
      $display("Test 7 - After reset: p=%0d (expect 0)", p);
      
      // Test 8: Post-reset with positive values
      @(posedge clk);
      reset = 0;
      n = 8'd10;
      w = 8'd10;
      
      @(posedge clk);
      $display("Test 8 - After reset, n=10, w=10: p=%0d (expect 100)", p);

      // Hold test
      acce = 0;
      n = 8'd7;
      w = 8'd7;
      @(posedge clk);
      $display("Hold test: p=%0d (expect unchanged)", p);
      acce = 1;
      
      #50;
      $display("=== MAC Test Complete ===");
      $finish;
   end
endmodule
