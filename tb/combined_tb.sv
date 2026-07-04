`timescale 1ns/1ps

module combined_tb;
   localparam int WIDTH = 8;
   localparam int N = 2;
   localparam int M = 2;
   localparam int LAYERS = 2;
   localparam int ROWS = N;
   localparam int TIME = M + N - 1;
   localparam int COLS = TIME * LAYERS;
   localparam int OUT_WIDTH = 2*WIDTH + $clog2(M);

   logic clk = 0;

   // weight_store signals
   logic                      we;
   logic [$clog2(COLS)-1:0]   wcol;
   logic [ROWS*WIDTH-1:0]     wdata;
   logic                      re;
   logic                      wreset;
   logic [ROWS*WIDTH-1:0]     rdata;
   logic                      empty;

   // queue signals
   logic                      qreset;
   logic signed [WIDTH-1:0]   north;
   logic signed [WIDTH-1:0]   south;
   logic                      le;
   logic                      shifte;
   logic signed [M*WIDTH-1:0] data;

   // matmul signals
   logic                      mreset;
   logic signed [N*WIDTH-1:0] A;
   logic signed [WIDTH-1:0]   b;
   logic signed [N*OUT_WIDTH-1:0] C;
   logic                      acce;
   logic                      done;

   weight_store #(.ROWS(ROWS), .COLS(COLS), .WIDTH(WIDTH)) ws(
      .clk(clk),
      .we(we),
      .wcol(wcol),
      .wdata(wdata),
      .re(re),
      .reset(wreset),
      .rdata(rdata),
      .empty(empty)
   );

   queue #(.WIDTH(WIDTH), .LENGTH(M)) q(
      .clk(clk),
      .reset(qreset),
      .shifte(shifte),
      .north(north),
      .south(south),
      .le(le),
      .data(data)
   );

   matmul #(.N(N), .M(M), .WIDTH(WIDTH)) dut(
      .clk(clk),
      .reset(mreset),
      .acce(acce),
      .A(A),
      .b(b),
      .C(C),
      .done(done)
   );

   always #5 clk = ~clk;

   assign A = rdata;
   assign b = south;

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

   task automatic load_queue(
      input logic signed [WIDTH-1:0] x0,
      input logic signed [WIDTH-1:0] x1
   );
      begin
         @(negedge clk);
         data = {x0, x1};
         le = 1;
         @(posedge clk);
         @(negedge clk);
         le = 0;
      end
   endtask

   task automatic run_layer(input string label);
      int i;
      begin
         $display("\n--- %s ---", label);

         // Prime current weight column while holding the current activation.
         @(negedge clk);
         acce = 0;
         shifte = 0;
         re = 1;
         @(posedge clk);

         // Consume TIME aligned stream cycles. Keep re low on the final
         // consume cycle so the pointer parks at the next layer's first column.
         @(negedge clk);
         acce = 1;
         shifte = 1;
         for (i = 0; i < TIME; i++) begin
            re = (i < TIME - 1);
            @(posedge clk);
            $display("consume A={%0d,%0d} b=%0d C={%0d,%0d}",
                     $signed(A[0*WIDTH +: WIDTH]),
                     $signed(A[1*WIDTH +: WIDTH]),
                     $signed(b),
                     $signed(C[0*OUT_WIDTH +: OUT_WIDTH]),
                     $signed(C[1*OUT_WIDTH +: OUT_WIDTH]));
         end

         @(negedge clk);
         acce = 0;
         shifte = 0;
         re = 0;
      end
   endtask

   initial begin
      $display("=== combined_tb: two back-to-back matmuls ===");

      qreset = 1;
      mreset = 1;
      wreset = 1;
      we = 0;
      re = 0;
      acce = 0;
      shifte = 0;
      le = 0;
      north = 0;
      data = 0;
      wcol = 0;
      wdata = 0;

      repeat (2) @(posedge clk);

      // Layer 0 matrix:
      //   [1 2]
      //   [3 4]
      // Input x = [5,6]
      // Expected y = [17,39]
      //
      // Padded stream:
      //   col0: [1,0]
      //   col1: [2,3]
      //   col2: [0,4]
      load_col(0, 8'sd1, 8'sd0);
      load_col(1, 8'sd2, 8'sd3);
      load_col(2, 8'sd0, 8'sd4);

      // Layer 1 matrix:
      //   [1 1]
      //   [2 1]
      // Input y = [17,39]
      // Expected z = [56,73]
      //
      // Padded stream:
      //   col3: [1,0]
      //   col4: [1,2]
      //   col5: [0,1]
      load_col(3, 8'sd1, 8'sd0);
      load_col(4, 8'sd1, 8'sd2);
      load_col(5, 8'sd0, 8'sd1);

      // Start reading weights from column 0.
      @(negedge clk);
      wreset = 1;
      @(posedge clk);
      @(negedge clk);
      wreset = 0;

      // Load external input into queue, then run layer 0.
      qreset = 0;
      load_queue(8'sd5, 8'sd6);

      @(negedge clk);
      mreset = 0;
      run_layer("layer 0");

      $display("Layer 0 result: {%0d,%0d} expected {17,39}",
               $signed(C[0*OUT_WIDTH +: OUT_WIDTH]),
               $signed(C[1*OUT_WIDTH +: OUT_WIDTH]));

      // Load layer 0 output back into queue while clearing matmul accumulators.
      @(negedge clk);
      data = {C[0*OUT_WIDTH +: WIDTH], C[1*OUT_WIDTH +: WIDTH]};
      le = 1;
      mreset = 1;
      @(posedge clk);
      @(negedge clk);
      le = 0;
      mreset = 0;

      // Do not reset weight_store here. Its pointer is already at layer 1.
      run_layer("layer 1");

      $display("Layer 1 result: {%0d,%0d} expected {56,73}",
               $signed(C[0*OUT_WIDTH +: OUT_WIDTH]),
               $signed(C[1*OUT_WIDTH +: OUT_WIDTH]));

      $finish;
   end
endmodule
