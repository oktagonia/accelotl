`timescale 1ns/1ps

module accel_tb;
   parameter int WIDTH = 8;
   parameter int NEURONS = 4;
   parameter int LAYERS = 2;
   parameter int SHIFT_WIDTH = 5;
   parameter int TEST_VECTORS = 1;
   parameter int TIMEOUT_NS = 200000;
   localparam int ROWS = NEURONS;
   localparam int STREAM_CYCLES = 2*NEURONS - 1;
   localparam int COLS = STREAM_CYCLES * LAYERS;
   localparam int OUT_WIDTH = 2*WIDTH + $clog2(NEURONS);

   string weights_file = "build/model/weights.hex";
   string biases_file = "build/model/biases.hex";
   string shifts_file = "build/model/shifts.hex";
   string inputs_file = "build/model/inputs.hex";
   string expected_file = "build/model/expected.hex";

   logic clk = 0;
   logic reset = 0;
   logic start = 0;
   logic we = 0;
   logic bwe = 0;
   logic breset = 0;
   logic [$clog2(COLS)-1:0] wcol = 0;
   logic [ROWS*WIDTH-1:0] wdata = 0;
   logic [$clog2(LAYERS)-1:0] wlayer = 0;
   logic signed [ROWS*OUT_WIDTH-1:0] bdata = 0;
   logic [$clog2(LAYERS+1)-1:0] nlayers = LAYERS;
   logic [LAYERS*SHIFT_WIDTH-1:0] shifts = '0;
   logic signed [NEURONS*WIDTH-1:0] init_qin = 0;
   logic signed [NEURONS*WIDTH-1:0] result;
   logic done;

   logic [ROWS*WIDTH-1:0] weight_cols[COLS];
   logic signed [ROWS*OUT_WIDTH-1:0] bias_rows[LAYERS];
   logic [SHIFT_WIDTH-1:0] shift_rows[LAYERS];
   logic signed [NEURONS*WIDTH-1:0] input_rows[TEST_VECTORS];
   logic signed [NEURONS*WIDTH-1:0] expected_rows[TEST_VECTORS];

   accel #(
      .WIDTH(WIDTH),
      .NEURONS(NEURONS),
      .LAYERS(LAYERS),
      .SHIFT_WIDTH(SHIFT_WIDTH)
   ) dut (
      .clk(clk),
      .reset(reset),
      .start(start),
      .we(we),
      .bwe(bwe),
      .breset(breset),
      .wcol(wcol),
      .wdata(wdata),
      .wlayer(wlayer),
      .bdata(bdata),
      .nlayers(nlayers),
      .shifts(shifts),
      .init_qin(init_qin),
      .result(result),
      .done(done)
   );

   always #5 clk = ~clk;

   task automatic load_col(
      input logic [$clog2(COLS)-1:0] col,
      input logic [ROWS*WIDTH-1:0] col_data
   );
      begin
         @(negedge clk);
         wcol = col;
         wdata = col_data;
         we = 1;
         @(posedge clk);
         @(negedge clk);
         we = 0;
      end
   endtask

   task automatic load_bias(
      input int layer_idx,
      input logic signed [ROWS*OUT_WIDTH-1:0] bias_vec
   );
      begin
         @(negedge clk);
         wlayer = layer_idx[$clog2(LAYERS)-1:0];
         bdata = bias_vec;
         bwe = 1;
         @(posedge clk);
         @(negedge clk);
         bwe = 0;
      end
   endtask

   task automatic load_model;
      begin
         for (int layer = 0; layer < LAYERS; layer++)
           shifts[layer*SHIFT_WIDTH +: SHIFT_WIDTH] = shift_rows[layer];

         for (int col = 0; col < COLS; col++)
           load_col(col[$clog2(COLS)-1:0], weight_cols[col]);

         for (int layer = 0; layer < LAYERS; layer++)
           load_bias(layer, bias_rows[layer]);
      end
   endtask

   task automatic run_vector(input int vector_idx);
      begin
         @(negedge clk);
         init_qin = input_rows[vector_idx];
         start = 1;
         @(posedge clk);
         @(negedge clk);
         start = 0;

         wait (done);
         @(negedge clk);

         $display("vector %0d accelerator = 0x%0h", vector_idx, result);
         $display("vector %0d expected    = 0x%0h", vector_idx, expected_rows[vector_idx]);

         if (result !== expected_rows[vector_idx]) begin
            $display("ERROR: vector %0d mismatch", vector_idx);
            $display("  got      = 0x%0h", result);
            $display("  expected = 0x%0h", expected_rows[vector_idx]);
            $fatal(1);
         end
      end
   endtask

   initial begin
      if ($value$plusargs("weights=%s", weights_file)) begin end
      if ($value$plusargs("biases=%s", biases_file)) begin end
      if ($value$plusargs("shifts=%s", shifts_file)) begin end
      if ($value$plusargs("inputs=%s", inputs_file)) begin end
      if ($value$plusargs("expected=%s", expected_file)) begin end

      $display("=== accel_tb: file-driven test ===");
      $display("weights:  %s", weights_file);
      $display("biases:   %s", biases_file);
      $display("shifts:   %s", shifts_file);
      $display("inputs:   %s", inputs_file);
      $display("expected: %s", expected_file);

      $readmemh(weights_file, weight_cols);
      $readmemh(biases_file, bias_rows);
      $readmemh(shifts_file, shift_rows);
      $readmemh(inputs_file, input_rows);
      $readmemh(expected_file, expected_rows);

      reset = 1;
      breset = 1;
      start = 0;
      we = 0;
      bwe = 0;
      init_qin = 0;
      repeat (2) @(posedge clk);
      @(negedge clk);
      reset = 0;
      breset = 0;

      load_model();

      for (int vector_idx = 0; vector_idx < TEST_VECTORS; vector_idx++)
        run_vector(vector_idx);

      $display("accel file-driven test complete");
      $finish;
   end

   initial begin
      #TIMEOUT_NS;
      $error("timeout waiting for done");
      $finish;
   end
endmodule
