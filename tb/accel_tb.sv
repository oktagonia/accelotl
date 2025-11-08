`timescale 1ns/1ps

module accel_tb;

   localparam int WIDTH = 8;
   localparam int NEURONS = 3;
   localparam int LAYERS = 3;
   localparam int ROWS = NEURONS;
   localparam int COLS = NEURONS * LAYERS;
   localparam int OUT_WIDTH = 2*WIDTH + $clog2(NEURONS);

   logic clk = 0;
   
   // Weight loading ports
   logic w_load_e = 0;
   logic wreset = 0;
   logic [$clog2(COLS)-1:0] wcol;
   logic signed [ROWS*WIDTH-1:0] wdata;
   
   // Input loading
   logic signed [NEURONS*WIDTH-1:0] init_qin;
   
   // Control
   logic start = 0;
   logic mreset = 0;
   
   // Outputs (assume these would be added to accel module)
   // logic done;
   // logic signed [NEURONS*OUT_WIDTH-1:0] result;

   // Instantiate DUT (commented out until accel is complete)
   // accel #(.WIDTH(WIDTH), .NEURONS(NEURONS), .LAYERS(LAYERS))
   //       dut(.*);

   // Clock generation
   always #5 clk = ~clk;

   initial begin
      $display("=== Accel Testbench ===");
      $display("Configuration: %0d neurons, %0d layers, %0d-bit width", 
               NEURONS, LAYERS, WIDTH);
      
      // ========================================
      // Load Weights with Zero Padding
      // ========================================
      $display("\n=== Loading Weights (Zero-Padded for Systolic Array) ===");
      
      // Reset weight store
      wreset = 1;
      @(posedge clk);
      wreset = 0;
      @(posedge clk);
      
      // For a systolic array processing NEURONS inputs over NEURONS cycles,
      // we need to zero-pad the weight matrix so each column processes
      // sequentially as inputs stream through
      
      // Layer 0 Weight Matrix (3x3):
      // Column 0: weights for neuron 0 when processing 3 input elements
      //   [w00, w01, w02] where w0i is weight from input i to neuron 0
      
      $display("Loading Layer 0 weights...");
      
      // Layer 0, Column 0 (for neuron 0)
      wcol = 0;
      wdata = {8'sd2, 8'sd1, 8'sd3};  // [w00=2, w10=1, w20=3]
      w_load_e = 1;
      @(posedge clk);
      @(posedge clk);
      w_load_e = 0;
      $display("  Column 0: weights = [%0d, %0d, %0d]", 
               $signed(wdata[0+:8]), $signed(wdata[8+:8]), $signed(wdata[16+:8]));
      
      // Layer 0, Column 1 (for neuron 1)
      wcol = 1;
      wdata = {8'sd1, 8'sd2, 8'sd1};  // [w01=1, w11=2, w21=1]
      w_load_e = 1;
      @(posedge clk);
      @(posedge clk);
      w_load_e = 0;
      $display("  Column 1: weights = [%0d, %0d, %0d]", 
               $signed(wdata[0+:8]), $signed(wdata[8+:8]), $signed(wdata[16+:8]));
      
      // Layer 0, Column 2 (for neuron 2)
      wcol = 2;
      wdata = {8'sd3, 8'sd1, 8'sd2};  // [w02=3, w12=1, w22=2]
      w_load_e = 1;
      @(posedge clk);
      @(posedge clk);
      w_load_e = 0;
      $display("  Column 2: weights = [%0d, %0d, %0d]", 
               $signed(wdata[0+:8]), $signed(wdata[8+:8]), $signed(wdata[16+:8]));
      
      $display("Loading Layer 1 weights...");
      
      // Layer 1, Column 0
      wcol = 3;
      wdata = {8'sd1, 8'sd1, 8'sd1};
      w_load_e = 1;
      @(posedge clk);
      @(posedge clk);
      w_load_e = 0;
      
      // Layer 1, Column 1
      wcol = 4;
      wdata = {8'sd2, 8'sd2, 8'sd2};
      w_load_e = 1;
      @(posedge clk);
      @(posedge clk);
      w_load_e = 0;
      
      // Layer 1, Column 2
      wcol = 5;
      wdata = {8'sd1, 8'sd1, 8'sd1};
      w_load_e = 1;
      @(posedge clk);
      @(posedge clk);
      w_load_e = 0;
      
      $display("Loading Layer 2 weights...");
      
      // Layer 2, Column 0
      wcol = 6;
      wdata = {8'sd1, 8'sd2, 8'sd1};
      w_load_e = 1;
      @(posedge clk);
      @(posedge clk);
      w_load_e = 0;
      
      // Layer 2, Column 1
      wcol = 7;
      wdata = {8'sd2, 8'sd1, 8'sd2};
      w_load_e = 1;
      @(posedge clk);
      @(posedge clk);
      w_load_e = 0;
      
      // Layer 2, Column 2
      wcol = 8;
      wdata = {8'sd1, 8'sd1, 8'sd3};
      w_load_e = 1;
      @(posedge clk);
      @(posedge clk);
      w_load_e = 0;
      
      $display("All weights loaded successfully\n");
      
      // ========================================
      // Test 1: Forward Pass with Simple Input
      // ========================================
      $display("=== Test 1: Forward Pass ===");
      $display("Input vector: [5, 3, 7]");
      
      init_qin = {8'sd5, 8'sd3, 8'sd7};
      
      // Manual calculation for verification:
      // Layer 0 output[0] = 2*5 + 1*3 + 3*7 = 10 + 3 + 21 = 34
      // Layer 0 output[1] = 1*5 + 2*3 + 1*7 = 5 + 6 + 7 = 18
      // Layer 0 output[2] = 3*5 + 1*3 + 2*7 = 15 + 3 + 14 = 32
      $display("Expected Layer 0 output: [34, 18, 32]");
      
      // Start computation
      start = 1;
      @(posedge clk);
      start = 0;
      
      // Wait for computation (would use wait(done) with complete module)
      repeat(100) @(posedge clk);
      
      // $display("Final output:");
      // for (int i = 0; i < NEURONS; i++) begin
      //    $display("  Output[%0d] = %0d", i, 
      //             $signed(result[i*OUT_WIDTH +: OUT_WIDTH]));
      // end
      
      // ========================================
      // Test 2: Zero Input
      // ========================================
      $display("\n=== Test 2: Zero Input ===");
      $display("Input vector: [0, 0, 0]");
      
      init_qin = {8'sd0, 8'sd0, 8'sd0};
      $display("Expected output: [0, 0, 0]");
      
      start = 1;
      @(posedge clk);
      start = 0;
      
      repeat(100) @(posedge clk);
      
      // ========================================
      // Test 3: Negative Input
      // ========================================
      $display("\n=== Test 3: Negative Input ===");
      $display("Input vector: [-2, 4, -1]");
      
      init_qin = {-8'sd2, 8'sd4, -8'sd1};
      
      // Layer 0 output[0] = 2*(-2) + 1*4 + 3*(-1) = -4 + 4 - 3 = -3
      // Layer 0 output[1] = 1*(-2) + 2*4 + 1*(-1) = -2 + 8 - 1 = 5
      // Layer 0 output[2] = 3*(-2) + 1*4 + 2*(-1) = -6 + 4 - 2 = -4
      $display("Expected Layer 0 output: [-3, 5, -4]");
      
      start = 1;
      @(posedge clk);
      start = 0;
      
      repeat(100) @(posedge clk);
      
      // ========================================
      // Test 4: Identity-like Test
      // ========================================
      $display("\n=== Test 4: Unit Vector [1, 0, 0] ===");
      $display("Input vector: [1, 0, 0]");
      
      init_qin = {8'sd1, 8'sd0, 8'sd0};
      
      // Layer 0 output[0] = 2*1 + 1*0 + 3*0 = 2
      // Layer 0 output[1] = 1*1 + 2*0 + 1*0 = 1
      // Layer 0 output[2] = 3*1 + 1*0 + 2*0 = 3
      $display("Expected Layer 0 output: [2, 1, 3]");
      
      start = 1;
      @(posedge clk);
      start = 0;
      
      repeat(100) @(posedge clk);
      
      $display("\n=== All Tests Complete ===");
      $display("Note: Actual result verification requires complete accel module");
      $finish;
   end
   
   // Timeout watchdog
   initial begin
      #100000;
      $display("\nERROR: Testbench timeout!");
      $finish;
   end

endmodule
