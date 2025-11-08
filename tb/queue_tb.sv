`timescale 1ns/1ps

module queue_tb;

   localparam int WIDTH = 8;
   localparam int LENGTH = 4;

   logic                           clk = 0;
   logic                           reset = 0;
   logic signed [WIDTH-1:0]        north;
   logic signed [WIDTH-1:0]        south;
   logic                           le;
   logic signed [LENGTH*WIDTH-1:0] data;

   // Instantiate DUT
   queue #(.WIDTH(WIDTH), .LENGTH(LENGTH)) 
         dut(.*);

   // Clock generation
   always #5 clk = ~clk;

   initial begin
      // Test 1: Reset functionality
      $display("=== Test 1: Reset ===");
      reset = 1;
      le = 0;
      north = 0;
      @(posedge clk);
      reset = 0;
      // @(posedge clk);
      $display("After reset, south = %0d (expect 0)", south);
      
      // Test 2: Load all stages at once
      $display("\n=== Test 2: Load Operation ===");
      data = {8'd4, 8'd3, 8'd2, 8'd1};  // Load stages with 1,2,3,4
      le = 1;
      @(posedge clk);
      le = 0;
      // @(posedge clk);  // Give time for data to propagate
      $display("After load, south = %0d (expect 4)", south);
      
      // Test 3: Shift operation (single value through queue)
      $display("\n=== Test 3: Shift Operation ===");
      north = 8'd10;
      $display("Cycle 1: south = %0d (expect 4)", south);
      
      @(posedge clk);
      $display("Cycle 2: south = %0d (expect 3)", south);
      
      @(posedge clk);
      $display("Cycle 3: south = %0d (expect 2)", south);
      
      @(posedge clk);
      $display("Cycle 4: south = %0d (expect 1)", south);
      
      @(posedge clk);
      $display("Cycle 5: south = %0d (expect 10)", south);
      
      // Test 4: Continuous stream of values
      $display("\n=== Test 4: Continuous Stream ===");
      for (int i = 20; i < 24; i++) begin
         north = i;
         @(posedge clk);
         $display("Input: %0d, Output: %0d", i, south);
      end
      
      // Test 5: Load while shifting (load should take priority)
      $display("\n=== Test 5: Load Priority ===");
      north = 8'd99;
      data = {8'd44, 8'd33, 8'd22, 8'd11};
      le = 1;
      @(posedge clk);
      le = 0;
      $display("After load (north=99, but loaded), south = %0d (expect 44)", south);
      
      // Test 6: Negative numbers (signed test)
      $display("\n=== Test 6: Signed Values ===");
      north = -8'd5;
      @(posedge clk);
      @(posedge clk);
      @(posedge clk);
      @(posedge clk);
      @(posedge clk);
      $display("After shifting -5 through, south = %d (expect -5)", $signed(south));
      
      // Test 7: Reset during operation
      $display("\n=== Test 7: Reset During Operation ===");
      north = 8'd77;
      @(posedge clk);
      reset = 1;
      @(posedge clk);
      reset = 0;
      @(posedge clk);
      $display("After reset during shift, south = %0d (expect 0)", south);
      
      $display("\n=== All Tests Complete ===");
      $finish;
   end

endmodule // queue_tb
