`timescale 1ns/1ps

module accel_tb;
   localparam int WIDTH = 8;
   localparam int N = 3;  // Maximum dimension
   localparam int OUT_WIDTH = 2*WIDTH + $clog2(N);
   
   logic clk = 0, reset = 1;
   logic signed [N*WIDTH-1:0] A;
   logic signed [WIDTH-1:0] init_x;
   logic [$clog2(N)-1:0] rate;
   logic [$clog2(N)-1:0] buffer;
   logic first_layer;
   logic [$clog2(2*WIDTH+1)+1:0] rescale;
   logic signed [N*OUT_WIDTH-1:0] out;
   
   // Instantiate single accel module
   accel #(.N(N), .WIDTH(WIDTH)) dut(
      .clk(clk),
      .reset(reset),
      .A(A),
      .init_x(init_x),
      .rate(rate),
      .buffer(buffer),
      .first_layer(first_layer),
      .rescale(rescale),
      .out(out)
   );
   
   always #5 clk = ~clk;  // 10ns clock
   
   // Monitor output
   always @(posedge clk) begin
      if (!reset) begin
         $display("[t=%0t] out=[%0d, %0d, %0d] b_in=%0d z=%0d stored=[%0d,%0d,%0d]",
                  $time,
                  $signed(out[0*OUT_WIDTH +: OUT_WIDTH]),
                  $signed(out[1*OUT_WIDTH +: OUT_WIDTH]),
                  $signed(out[2*OUT_WIDTH +: OUT_WIDTH]),
                  $signed(dut.b_in),
                  $signed(dut.z),
                  $signed(dut.stored_layer[0*OUT_WIDTH +: WIDTH]),
                  $signed(dut.stored_layer[1*OUT_WIDTH +: WIDTH]),
                  $signed(dut.stored_layer[2*OUT_WIDTH +: WIDTH]));
      end
   end
   
   initial begin
      $dumpfile("accel_tb.vcd");
      $dumpvars(0, accel_tb);
      
      $display("========================================");
      $display("=== Two-Layer Accelerator Test ===");
      $display("=== Layer 1: 3x2, Layer 2: 2x3 ===");
      $display("========================================");
      $display("");
      
      // ===================================
      // LAYER 1: 3x2 Matrix Multiply
      // ===================================
      // Matrix A1 (3 rows x 2 cols):
      // [[1, 2],
      //  [3, 4],
      //  [5, 6]]
      //
      // Input vector x = [7, 8]
      //
      // Expected output:
      // y[0] = 1*7 + 2*8 = 7 + 16 = 23
      // y[1] = 3*7 + 4*8 = 21 + 32 = 53
      // y[2] = 5*7 + 6*8 = 35 + 48 = 83
      
      $display("=== LAYER 1: 3x2 Matrix-Vector Multiply ===");
      $display("Matrix A1:");
      $display("  [1, 2]");
      $display("  [3, 4]");
      $display("  [5, 6]");
      $display("Input vector: [7, 8]");
      $display("Expected output: [23, 53, 83]");
      $display("");
      
      // Configure first layer
      first_layer = 1;  // Use init_x as input (auto-stores output)
      rate = 2'd3;      // 3 elements
      buffer = 2'd3;    // Wait for pipeline
      rescale = 0;
      
      // Hold reset
      reset = 1;
      A = 0;
      init_x = 0;
      #20;
      
      @(posedge clk);
      reset = 0;
      
      // Feed matrix column by column (systolic array style)
      // Time step 0: first column, first element
      A[0*WIDTH +: WIDTH] = 8'd1;
      A[1*WIDTH +: WIDTH] = 8'd0;
      A[2*WIDTH +: WIDTH] = 8'd0;
      init_x = 8'd7;
      @(posedge clk);
      
      // Time step 1: second column, second element
      A[0*WIDTH +: WIDTH] = 8'd2;
      A[1*WIDTH +: WIDTH] = 8'd3;
      A[2*WIDTH +: WIDTH] = 8'd0;
      init_x = 8'd8;
      @(posedge clk);
      
      // Time step 2: drain pipeline
      A[0*WIDTH +: WIDTH] = 8'd0;
      A[1*WIDTH +: WIDTH] = 8'd4;
      A[2*WIDTH +: WIDTH] = 8'd5;
      init_x = 8'd0;
      @(posedge clk);
      
      // Time step 3: continue draining
      A[0*WIDTH +: WIDTH] = 8'd0;
      A[1*WIDTH +: WIDTH] = 8'd0;
      A[2*WIDTH +: WIDTH] = 8'd6;
      init_x = 8'd0;
      @(posedge clk);
      
      // Clear inputs
      A = 0;
      init_x = 0;
      repeat(3) @(posedge clk);
      
      $display("");
      $display("Layer 1 Results:");
      $display("  out[0] = %0d (expected 23)", $signed(out[0*OUT_WIDTH +: OUT_WIDTH]));
      $display("  out[1] = %0d (expected 53)", $signed(out[1*OUT_WIDTH +: OUT_WIDTH]));
      $display("  out[2] = %0d (expected 83)", $signed(out[2*OUT_WIDTH +: OUT_WIDTH]));
      $display("");
      
      // ===================================
      // LAYER 2: 2x3 Matrix Multiply
      // ===================================
      // Matrix A2 (2 rows x 3 cols) - but we need to fit in 3x3
      // We'll use a 3x3 matrix with the third row as zeros
      // [[1, 2, 3],
      //  [4, 5, 6],
      //  [0, 0, 0]]
      //
      // Input vector (from Layer 1, scaled to WIDTH): [23, 53, 83]
      // This will come from the serializer feedback
      //
      // Expected output:
      // y[0] = 1*23 + 2*53 + 3*83 = 23 + 106 + 249 = 378
      // y[1] = 4*23 + 5*53 + 6*83 = 92 + 265 + 498 = 855
      // y[2] = 0 (unused row)
      
      $display("=== LAYER 2: 2x3 Matrix-Vector Multiply ===");
      $display("Matrix A2 (padded to 3x3):");
      $display("  [1, 2, 3]");
      $display("  [4, 5, 6]");
      $display("  [0, 0, 0]");
      $display("Input vector (from Layer 1 stored): [23, 53, 83]");
      $display("Expected output: [378, 855, 0]");
      $display("");
      
      // Reconfigure for second layer
      // IMPORTANT: Set first_layer=0 BEFORE reset so stored_layer is frozen!
      first_layer = 0;  // Freeze stored_layer, use serializer feedback
      rate = 2'd3;      // Serialize 3 elements
      buffer = 2'd3;    // Wait for pipeline
      rescale = 0;
      
      // Now reset to restart serializer state machine
      @(posedge clk);
      reset = 1;
      A = 0;
      @(posedge clk);
      reset = 0;
      
      // Wait for serializer buffer period (3 cycles)
      // Serializer will start outputting z after buffer cycles
      repeat(3) @(posedge clk);
      
      // NOW feed matrix - serializer is ready
      // Time step 0
      A[0*WIDTH +: WIDTH] = 8'd1;
      A[1*WIDTH +: WIDTH] = 8'd0;
      A[2*WIDTH +: WIDTH] = 8'd0;
      @(posedge clk);
      
      // Time step 1
      A[0*WIDTH +: WIDTH] = 8'd2;
      A[1*WIDTH +: WIDTH] = 8'd4;
      A[2*WIDTH +: WIDTH] = 8'd0;
      @(posedge clk);
      
      // Time step 2
      A[0*WIDTH +: WIDTH] = 8'd3;
      A[1*WIDTH +: WIDTH] = 8'd5;
      A[2*WIDTH +: WIDTH] = 8'd0;
      @(posedge clk);
      
      // Time step 3: drain
      A[0*WIDTH +: WIDTH] = 8'd0;
      A[1*WIDTH +: WIDTH] = 8'd6;
      A[2*WIDTH +: WIDTH] = 8'd0;
      @(posedge clk);
      
      // Time step 4: continue draining
      A[0*WIDTH +: WIDTH] = 8'd0;
      A[1*WIDTH +: WIDTH] = 8'd0;
      A[2*WIDTH +: WIDTH] = 8'd0;
      @(posedge clk);
      
      // Clear inputs
      A = 0;
      repeat(3) @(posedge clk);
      
      $display("");
      $display("Layer 2 Results:");
      $display("  out[0] = %0d (expected 378)", $signed(out[0*OUT_WIDTH +: OUT_WIDTH]));
      $display("  out[1] = %0d (expected 855)", $signed(out[1*OUT_WIDTH +: OUT_WIDTH]));
      $display("  out[2] = %0d (expected 0)", $signed(out[2*OUT_WIDTH +: OUT_WIDTH]));
      $display("");
      
      $display("========================================");
      $display("=== Test Complete ===");
      $display("========================================");
      
      $finish;
   end
endmodule
