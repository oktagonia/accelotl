`timescale 1ns/1ps

module bias_store_tb;
   localparam int ROWS = 4;
   localparam int LAYERS = 3;
   localparam int OUT_WIDTH = 18;
   localparam int LAYER_BITS = (LAYERS <= 1) ? 1 : $clog2(LAYERS);

   logic clk = 0;
   logic reset = 0;
   logic we = 0;
   logic re = 0;
   logic [LAYER_BITS-1:0] wlayer = 0;
   logic [LAYER_BITS-1:0] rlayer = 0;
   logic signed [ROWS*OUT_WIDTH-1:0] wdata = '0;
   logic signed [ROWS*OUT_WIDTH-1:0] rdata;

   bias_store #(
      .ROWS(ROWS),
      .LAYERS(LAYERS),
      .OUT_WIDTH(OUT_WIDTH)
   ) dut (
      .clk(clk),
      .reset(reset),
      .we(we),
      .re(re),
      .wlayer(wlayer),
      .rlayer(rlayer),
      .wdata(wdata),
      .rdata(rdata)
   );

   always #5 clk = ~clk;

   function automatic int signed lane(
      input logic signed [ROWS*OUT_WIDTH-1:0] vec,
      input int idx
   );
      logic signed [OUT_WIDTH-1:0] raw;
      begin
         raw = vec[idx*OUT_WIDTH+:OUT_WIDTH];
         lane = raw;
      end
   endfunction

   task automatic set_lane(
      inout logic signed [ROWS*OUT_WIDTH-1:0] vec,
      input int idx,
      input int signed value
   );
      logic signed [OUT_WIDTH-1:0] raw;
      begin
         raw = value;
         vec[idx*OUT_WIDTH+:OUT_WIDTH] = raw;
      end
   endtask

   task automatic expect_lane(
      input logic signed [ROWS*OUT_WIDTH-1:0] vec,
      input int idx,
      input int signed expected
   );
      int signed got;
      begin
         got = lane(vec, idx);
         if (got !== expected) begin
            $display("ERROR: lane %0d got %0d, expected %0d", idx, got, expected);
            $fatal(1);
         end
      end
   endtask

   task automatic expect_vector(
      input logic signed [ROWS*OUT_WIDTH-1:0] vec,
      input int signed v0,
      input int signed v1,
      input int signed v2,
      input int signed v3
   );
      begin
         expect_lane(vec, 0, v0);
         expect_lane(vec, 1, v1);
         expect_lane(vec, 2, v2);
         expect_lane(vec, 3, v3);
      end
   endtask

   task automatic write_layer(
      input int layer,
      input logic signed [ROWS*OUT_WIDTH-1:0] vec
   );
      begin
         @(negedge clk);
         wlayer = layer[LAYER_BITS-1:0];
         wdata = vec;
         we = 1;
         @(posedge clk);
         @(negedge clk);
         we = 0;
      end
   endtask

   task automatic read_layer(input int layer);
      begin
         @(negedge clk);
         rlayer = layer[LAYER_BITS-1:0];
         re = 1;
         @(posedge clk);
         #1;
         @(negedge clk);
         re = 0;
      end
   endtask

   initial begin
      logic signed [ROWS*OUT_WIDTH-1:0] layer0;
      logic signed [ROWS*OUT_WIDTH-1:0] layer2;

      layer0 = '0;
      layer2 = '0;
      set_lane(layer0, 0, 100);
      set_lane(layer0, 1, -200);
      set_lane(layer0, 2, 300);
      set_lane(layer0, 3, -400);

      set_lane(layer2, 0, -1);
      set_lane(layer2, 1, 0);
      set_lane(layer2, 2, 131071);
      set_lane(layer2, 3, -131072);

      $display("=== bias_store_tb ===");

      reset = 1;
      repeat (2) @(posedge clk);
      #1;
      expect_vector(rdata, 0, 0, 0, 0);

      reset = 0;
      write_layer(0, layer0);
      write_layer(2, layer2);

      read_layer(0);
      expect_vector(rdata, 100, -200, 300, -400);

      read_layer(2);
      expect_vector(rdata, -1, 0, 131071, -131072);

      @(negedge clk);
      rlayer = 0;
      re = 0;
      repeat (2) @(posedge clk);
      #1;
      expect_vector(rdata, -1, 0, 131071, -131072);

      reset = 1;
      @(posedge clk);
      #1;
      expect_vector(rdata, 0, 0, 0, 0);

      reset = 0;
      read_layer(0);
      expect_vector(rdata, 0, 0, 0, 0);

      $display("bias_store_tb complete");
      $finish;
   end
endmodule
