`timescale 1ns/1ps

module accel_tb;
   localparam int WIDTH = 8;
   localparam int NEURONS = 64;
   localparam int LAYERS = 2;
   localparam int ROWS = NEURONS;
   localparam int STREAM_CYCLES = 2*NEURONS - 1;
   localparam int COLS = STREAM_CYCLES * LAYERS;
   localparam int OUT_WIDTH = 2*WIDTH + $clog2(NEURONS);
   localparam int NONZERO_PER_ROW = 4;

   logic clk = 0;
   logic reset = 0;
   logic start = 0;
   logic we = 0;
   logic [$clog2(COLS)-1:0] wcol = 0;
   logic [ROWS*WIDTH-1:0] wdata = 0;
   logic [$clog2(LAYERS+1)-1:0] nlayers = LAYERS;
   logic signed [NEURONS*WIDTH-1:0] init_qin = 0;
   logic signed [NEURONS*OUT_WIDTH-1:0] result;
   logic done;

   int signed x[NEURONS];
   int signed w0[NEURONS][NEURONS];
   int signed w1[NEURONS][NEURONS];
   int signed y0[NEURONS];
   int signed y0_trunc[NEURONS];
   int signed y1[NEURONS];

   accel #(
      .WIDTH(WIDTH),
      .NEURONS(NEURONS),
      .LAYERS(LAYERS)
   ) dut (
      .clk(clk),
      .reset(reset),
      .start(start),
      .we(we),
      .wcol(wcol),
      .wdata(wdata),
      .nlayers(nlayers),
      .init_qin(init_qin),
      .result(result),
      .done(done)
   );

   always #5 clk = ~clk;

   function automatic int signed int8(input int value);
      int wrapped;
      begin
         wrapped = value & 8'hff;
         int8 = (wrapped >= 128) ? wrapped - 256 : wrapped;
      end
   endfunction

   function automatic logic signed [WIDTH-1:0] to_width(input int value);
      to_width = int8(value);
   endfunction

   task automatic build_matrices;
      int row;
      int k;
      int col;
      begin
         for (int i = 0; i < NEURONS; i++) begin
            x[i] = 1 + (i % 3);
            y0[i] = 0;
            y0_trunc[i] = 0;
            y1[i] = 0;
            for (int j = 0; j < NEURONS; j++) begin
               w0[i][j] = 0;
               w1[i][j] = 0;
            end
         end

         for (row = 0; row < NEURONS; row++) begin
            for (k = 0; k < NONZERO_PER_ROW; k++) begin
               col = (row*13 + k*17 + 5) % NEURONS;
               w0[row][col] = ((row + 3*k) % 3) - 1;

               col = (row*7 + k*11 + 3) % NEURONS;
               w1[row][col] = ((2*row + k) % 3) - 1;
            end
         end

         for (row = 0; row < NEURONS; row++) begin
            for (col = 0; col < NEURONS; col++)
              y0[row] += w0[row][col] * x[col];

            y0_trunc[row] = int8(y0[row]);
         end

         for (row = 0; row < NEURONS; row++)
           for (col = 0; col < NEURONS; col++)
             y1[row] += w1[row][col] * y0_trunc[col];
      end
   endtask

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

   task automatic load_layer(input int layer_idx);
      logic [ROWS*WIDTH-1:0] col_data;
      int stream_col;
      int row;
      int logical_col;
      int signed weight;
      begin
         for (stream_col = 0; stream_col < STREAM_CYCLES; stream_col++) begin
            col_data = '0;

            for (row = 0; row < NEURONS; row++) begin
               logical_col = stream_col - row;
               weight = 0;

               if (logical_col >= 0 && logical_col < NEURONS) begin
                  if (layer_idx == 0)
                    weight = w0[row][logical_col];
                  else
                    weight = w1[row][logical_col];
               end

               col_data[row*WIDTH +: WIDTH] = to_width(weight);
            end

            load_col(layer_idx*STREAM_CYCLES + stream_col, col_data);
         end
      end
   endtask

   initial begin
      $display("=== accel_tb: two random sparse 64x64 matmuls ===");

      build_matrices();

      reset = 1;
      start = 0;
      we = 0;
      init_qin = 0;
      repeat (2) @(posedge clk);
      @(negedge clk);
      reset = 0;

      load_layer(0);
      load_layer(1);

      @(negedge clk);
      for (int i = 0; i < NEURONS; i++)
        init_qin[(NEURONS-1-i)*WIDTH +: WIDTH] = to_width(x[i]);

      start = 1;
      @(posedge clk);
      @(negedge clk);
      start = 0;

      wait (done);
      @(negedge clk);

      for (int i = 0; i < NEURONS; i++) begin
         int got;
         got = $signed(result[i*OUT_WIDTH +: OUT_WIDTH]);

         if (got !== y1[i])
           $error("row %0d result %0d expected %0d", i, got, y1[i]);
      end

      $display("random sparse 64x64 two-layer accel test complete");
      $finish;
   end

   initial begin
      #20000;
      $error("timeout waiting for done");
      $finish;
   end
endmodule
