`timescale 1ns/1ps

module matmul_tb;
   localparam int WIDTH = 8;
   localparam int N = 2;
   localparam int M = 4;
   localparam int OUT_WIDTH = 2*WIDTH + $clog2(M);
   
   logic clk = 0, reset = 1;
   logic signed [N*WIDTH-1:0] A;
   logic signed [WIDTH-1:0] b;
   logic signed [N*OUT_WIDTH-1:0] C;
   logic done;
   
   matmul #(.WIDTH(WIDTH), .N(N), .M(M)) dut(
      .clk(clk), .reset(reset),
      .A(A), .b(b), .C(C), .done(done)
   );
   
   always #5 clk = ~clk;  // 10ns clock
   
   initial begin
      $dumpfile("matmul_tb.vcd");
      $dumpvars(0, matmul_tb);
      
      // Matrix-vector multiply:
      // A = [[1, 2, 3, 4],      b = [1]
      //      [5, 6, 7, 8]]          [2]
      //                             [3]
      //                             [4]
      //
      // Expected result:
      // C[0] = 1*1 + 2*2 + 3*3 + 4*4 = 30
      // C[1] = 5*1 + 6*2 + 7*3 + 8*4 = 70
      
      $display("=== 2x4 Matrix-Vector Multiply ===");
      $display("Matrix A:");
      $display("  [1, 2, 3, 4]");
      $display("  [5, 6, 7, 8]");
      $display("Vector b: [1, 2, 3, 4]");
      $display("Expected C: [30, 70]");
      $display("");
      
      // Hold reset
      reset = 1;
      A = 0;
      b = 0;
      #20;
      
      @(posedge clk);
      reset = 0;
      
      // Time step 0
      A[0*WIDTH +: WIDTH] = 8'd1;
      A[1*WIDTH +: WIDTH] = 8'd0;
      b = 8'd1;
      @(posedge clk);
      
      // Time step 1
      A[0*WIDTH +: WIDTH] = 8'd2;
      A[1*WIDTH +: WIDTH] = 8'd5;
      b = 8'd2;
      @(posedge clk);
      
      // Time step 2
      A[0*WIDTH +: WIDTH] = 8'd3;
      A[1*WIDTH +: WIDTH] = 8'd6;
      b = 8'd3;
      @(posedge clk);
      
      // Time step 3
      A[0*WIDTH +: WIDTH] = 8'd4;
      A[1*WIDTH +: WIDTH] = 8'd7;
      b = 8'd4;
      @(posedge clk);
      
      // Time step 4 - drain
      A[0*WIDTH +: WIDTH] = 8'd0;
      A[1*WIDTH +: WIDTH] = 8'd8;
      b = 8'd0;
      @(posedge clk);
      
      A = 0;
      b = 0;
      @(posedge clk);
      
      $display("Results:");
      $display("  C[0] = %0d (expected 30)", $signed(C[0*OUT_WIDTH +: OUT_WIDTH]));
      $display("  C[1] = %0d (expected 70)", $signed(C[1*OUT_WIDTH +: OUT_WIDTH]));
      $display("");
      
      // Test 2: Matrix-vector multiply with negative values
      // A = [[-1,  2, -3,  4],      b = [ 1]
      //      [ 5, -6,  7, -8]]          [-2]
      //                                 [ 3]
      //                                 [-4]
      //
      // Expected result:
      // C[0] = -1*1 + 2*(-2) + (-3)*3 + 4*(-4) = -1 - 4 - 9 - 16 = -30
      // C[1] = 5*1 + (-6)*(-2) + 7*3 + (-8)*(-4) = 5 + 12 + 21 + 32 = 70
      
      $display("=== Test 2: 2x4 Matrix-Vector Multiply with Negatives ===");
      $display("Matrix A:");
      $display("  [-1,  2, -3,  4]");
      $display("  [ 5, -6,  7, -8]");
      $display("Vector b: [1, -2, 3, -4]");
      $display("Expected C: [-30, 70]");
      $display("");
      
      // Reset
      @(posedge clk);
      reset = 1;
      A = 0;
      b = 0;
      @(posedge clk);
      reset = 0;
      
      // Time step 0
      A[0*WIDTH +: WIDTH] = -8'd1;
      A[1*WIDTH +: WIDTH] = 8'd0;
      b = 8'd1;
      @(posedge clk);
      
      // Time step 1
      A[0*WIDTH +: WIDTH] = 8'd2;
      A[1*WIDTH +: WIDTH] = 8'd5;
      b = -8'd2;
      @(posedge clk);
      
      // Time step 2
      A[0*WIDTH +: WIDTH] = -8'd3;
      A[1*WIDTH +: WIDTH] = -8'd6;
      b = 8'd3;
      @(posedge clk);
      
      // Time step 3
      A[0*WIDTH +: WIDTH] = 8'd4;
      A[1*WIDTH +: WIDTH] = 8'd7;
      b = -8'd4;
      @(posedge clk);
      
      // Time step 4 - drain
      A[0*WIDTH +: WIDTH] = 8'd0;
      A[1*WIDTH +: WIDTH] = -8'd8;
      b = 8'd0;
      @(posedge clk);
      
      A = 0;
      b = 0;
      @(posedge clk);
      
      $display("Results:");
      $display("  C[0] = %0d (expected -30)", $signed(C[0*OUT_WIDTH +: OUT_WIDTH]));
      $display("  C[1] = %0d (expected 70)", $signed(C[1*OUT_WIDTH +: OUT_WIDTH]));
      $display("");
      
      $finish;
   end
endmodule
