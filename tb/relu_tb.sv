`timescale 1ns/1ps

module relu_tb;
   localparam int WIDTH = 8;
   
   logic signed [WIDTH-1:0] z;
   logic signed [WIDTH-1:0] a;
   
   // Instantiate ReLU module
   relu #(.WIDTH(WIDTH)) dut(
      .z(z),
      .a(a)
   );
   
   initial begin
      $dumpfile("relu_tb.vcd");
      $dumpvars(0, relu_tb);
      
      $display("========================================");
      $display("=== ReLU Module Test (WIDTH=%0d) ===", WIDTH);
      $display("========================================");
      $display("");
      
      // Test 1: Positive values should pass through
      $display("=== Test 1: Positive Values ===");
      z = 8'd50;
      #10;
      $display("z=%0d, a=%0d (expected %0d)", $signed(z), $signed(a), $signed(z));
      
      z = 8'd127;
      #10;
      $display("z=%0d, a=%0d (expected %0d)", $signed(z), $signed(a), $signed(z));
      
      z = 8'd1;
      #10;
      $display("z=%0d, a=%0d (expected %0d)", $signed(z), $signed(a), $signed(z));
      $display("");
      
      // Test 2: Zero should output zero
      $display("=== Test 2: Zero ===");
      z = 8'd0;
      #10;
      $display("z=%0d, a=%0d (expected 0)", $signed(z), $signed(a));
      $display("");
      
      // Test 3: Negative values should be clamped to zero
      $display("=== Test 3: Negative Values ===");
      z = -8'd50;
      #10;
      $display("z=%0d, a=%0d (expected 0)", $signed(z), $signed(a));
      
      z = -8'd128;
      #10;
      $display("z=%0d, a=%0d (expected 0)", $signed(z), $signed(a));
      
      z = -8'd1;
      #10;
      $display("z=%0d, a=%0d (expected 0)", $signed(z), $signed(a));
      $display("");
      
      // Test 4: Sweep through range
      $display("=== Test 4: Sweep Test ===");
      for (int i = -128; i < 128; i++) begin
         z = i;
         #1;
         if (i > 0) begin
            if (a != i) $display("ERROR: z=%0d, a=%0d (expected %0d)", i, $signed(a), i);
         end else begin
            if (a != 0) $display("ERROR: z=%0d, a=%0d (expected 0)", i, $signed(a));
         end
      end
      $display("Sweep complete (checked 256 values)");
      $display("");
      
      $display("========================================");
      $display("=== Test Complete ===");
      $display("========================================");
      
      $finish;
   end
endmodule


