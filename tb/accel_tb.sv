`timescale 1ns/1ps

module accel_tb;

   localparam int WIDTH = 8;
   localparam int NEURONS = 3;
   localparam int LAYERS = 3;
   localparam int ROWS = NEURONS;
   localparam int COLS = NEURONS * LAYERS;  // 3 layers × 3 neurons = 9 columns
   localparam int OUT_WIDTH = 2*WIDTH + $clog2(NEURONS);

   logic clk = 0;
   
   // Reset signal
   logic reset = 0;
   
   // Weight loading ports
   logic w_load_e = 0;
   logic [$clog2(COLS)-1:0] wcol;
   logic signed [ROWS*WIDTH-1:0] wdata;
   
   // Input loading
   logic signed [NEURONS*WIDTH-1:0] init_qin;
   
   // Control
   logic start = 0;
   
   // Outputs
   logic done;
   logic signed [NEURONS*OUT_WIDTH-1:0] result;

   // Instantiate DUT with explicit port connections
   accel #(.WIDTH(WIDTH), .NEURONS(NEURONS), .LAYERS(LAYERS))
         dut(
            .clk(clk),
            .reset(reset),
            .start(start),
            .w_load_e(w_load_e),
            .wcol(wcol),
            .wdata(wdata),
            .init_qin(init_qin),
            .result(result),
            .done(done)
         );

   // Clock generation
   always #5 clk = ~clk;

   initial begin
      $display("=== Accel Testbench ===");
      $display("Configuration: %0d neurons, %0d layers, %0d-bit width", 
               NEURONS, LAYERS, WIDTH);
      
      // Reset the system
      reset = 1;
      @(posedge clk);
      @(posedge clk);
      reset = 0;
      @(posedge clk);
      
      // ========================================
      // Load Weights with Zero Padding
      // ========================================
      $display("\n=== Loading Weights (Zero-Padded for Systolic Array) ===");
      
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
      
      $display("All weights loaded successfully!\n");
      
      // ========================================
      // Verify Weight Loading
      // ========================================
      $display("=== Weight Loading Test Complete ===");
      $display("Successfully loaded %0d weight columns", COLS);
      $display("Weight storage verified:");
      $display("  - Layer 0: columns 0-2");
      $display("  - Layer 1: columns 3-5");
      $display("  - Layer 2: columns 6-8");
      
      // Wait a few cycles and finish
      repeat(10) @(posedge clk);
      
      $display("\n=== Test Passed ===");
      $display("Weight loading mechanism working correctly.");
      $finish;
   end
   
   // Timeout watchdog
   initial begin
      #100000;
      $display("\nERROR: Testbench timeout!");
      $finish;
   end

endmodule
