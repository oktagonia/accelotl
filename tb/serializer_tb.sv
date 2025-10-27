`timescale 1ns/1ps

module serializer_tb;
   localparam int WIDTH = 8;
   localparam int N = 3;
   localparam int M = 2;
   localparam int OUT_WIDTH = 2*WIDTH + $clog2(M);
   
   logic clk = 0, reset = 1;
   logic signed [N*WIDTH-1:0] A;
   logic signed [WIDTH-1:0] b;
   logic signed [N*OUT_WIDTH-1:0] C;
   logic done;
   
   logic [$clog2(N) - 1:0] length, buffer;
   logic signed [OUT_WIDTH-1:0] z;
   
   // Instantiate matmul
   matmul #(.WIDTH(WIDTH), .N(N), .M(M)) matmul_inst(
      .clk(clk), 
      .reset(reset),
      .A(A), 
      .b(b), 
      .C(C), 
      .done(done)
   );
   
   // Instantiate serializer
   serializer #(.WIDTH(OUT_WIDTH), .N(N)) dut(
      .clk(clk),
      .reset(reset),
      .length(length),
      .buffer(buffer),
      .S(C),
      .z(z)
   );
   
   always #5 clk = ~clk;  // 10ns clock
   
   // Log serializer output
   always @(posedge clk) begin
      $display("[t=%0t] state=%0d idx=%0d z=%0d | C=[%0d,%0d,%0d]",
               $time,
               dut.state,
               dut.index,
               $signed(z),
               $signed(C[0*OUT_WIDTH +: OUT_WIDTH]),
               $signed(C[1*OUT_WIDTH +: OUT_WIDTH]),
               $signed(C[2*OUT_WIDTH +: OUT_WIDTH]));
   end
   
   initial begin
      $dumpfile("serializer_tb.vcd");
      $dumpvars(0, serializer_tb);
      
      $display("=== Matmul + Serializer Test ===");
      $display("Matrix: [[1,2],[3,4],[5,6]] * [7,8]");
      $display("Expected C: [23, 53, 83]");
      $display("Serializer: length=3, buffer=1 (M-1)");
      $display("");
      
      length = 3;   // N rows
      buffer = 3;   // M-1
      
      // Hold reset
      reset = 1;
      A = 0;
      b = 0;

      @(negedge clk);
      reset = 0;
      
      // Feed matrix row-wise
      @(posedge clk);
      A[0*WIDTH +: WIDTH] = 8'd1;
      A[1*WIDTH +: WIDTH] = 8'd0;
      A[2*WIDTH +: WIDTH] = 8'd0;
      b = 8'd7;
      @(posedge clk);
      
      A[0*WIDTH +: WIDTH] = 8'd2;
      A[1*WIDTH +: WIDTH] = 8'd3;
      A[2*WIDTH +: WIDTH] = 8'd0;
      b = 8'd8;
      @(posedge clk);
      
      A[0*WIDTH +: WIDTH] = 8'd0;
      A[1*WIDTH +: WIDTH] = 8'd4;
      A[2*WIDTH +: WIDTH] = 8'd5;
      b = 8'd0;
      @(posedge clk);
      
      A[0*WIDTH +: WIDTH] = 8'd0;
      A[1*WIDTH +: WIDTH] = 8'd0;
      A[2*WIDTH +: WIDTH] = 8'd6;
      b = 8'd0;
      @(posedge clk);
      
      A = 0;
      b = 0;
      repeat(5) @(posedge clk);
      
      $display("");
      $display("Matmul C: [%0d, %0d, %0d]",
               $signed(C[0*OUT_WIDTH +: OUT_WIDTH]),
               $signed(C[1*OUT_WIDTH +: OUT_WIDTH]),
               $signed(C[2*OUT_WIDTH +: OUT_WIDTH]));
      $display("Expected serializer: 0 (buffer), 23, 53, 83");
      $display("");
      
      $finish;
   end
endmodule
