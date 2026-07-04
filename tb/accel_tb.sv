`timescale 1ns/1ps

module accel_tb;
   localparam int WIDTH = 8;
   localparam int NEURONS = 2;
   localparam int LAYERS = 2;
   localparam int ROWS = NEURONS;
   localparam int STREAM_CYCLES = 2*NEURONS - 1;
   localparam int COLS = STREAM_CYCLES * LAYERS;
   localparam int OUT_WIDTH = 2*WIDTH + $clog2(NEURONS);

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

   task automatic load_col(
      input logic [$clog2(COLS)-1:0] col,
      input logic signed [WIDTH-1:0] row0,
      input logic signed [WIDTH-1:0] row1
   );
      begin
         @(negedge clk);
         wcol = col;
         wdata = {row1, row0};
         we = 1;
         @(posedge clk);
         @(negedge clk);
         we = 0;
      end
   endtask

   initial begin
      $display("=== accel_tb: two-layer run ===");

      reset = 1;
      start = 0;
      we = 0;
      init_qin = 0;
      repeat (2) @(posedge clk);
      @(negedge clk);
      reset = 0;

      // Layer 0 matrix:
      //   [1 2]
      //   [3 4]
      // x = [5,6], expected layer0 = [17,39]
      load_col(0, 8'sd1, 8'sd0);
      load_col(1, 8'sd2, 8'sd3);
      load_col(2, 8'sd0, 8'sd4);

      // Layer 1 matrix:
      //   [1 1]
      //   [2 1]
      // expected final = [56,73]
      load_col(3, 8'sd1, 8'sd0);
      load_col(4, 8'sd1, 8'sd2);
      load_col(5, 8'sd0, 8'sd1);

      // Queue emits high lane first, so pack {x0,x1}.
      @(negedge clk);
      init_qin = {8'sd5, 8'sd6};
      start = 1;
      @(posedge clk);
      @(negedge clk);
      start = 0;

      wait (done);
      @(negedge clk);

      $display("Final result: {%0d,%0d} expected {56,73}",
               $signed(result[0*OUT_WIDTH +: OUT_WIDTH]),
               $signed(result[1*OUT_WIDTH +: OUT_WIDTH]));

      if ($signed(result[0*OUT_WIDTH +: OUT_WIDTH]) !== 56 ||
          $signed(result[1*OUT_WIDTH +: OUT_WIDTH]) !== 73) begin
         $error("Unexpected accel result");
      end

      $finish;
   end

   initial begin
      #2000;
      $error("timeout waiting for done");
      $finish;
   end
endmodule
