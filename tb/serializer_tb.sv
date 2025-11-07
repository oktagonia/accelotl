`timescale 1ns/1ps

module serializer_tb;
   localparam int WIDTH = 8;
   localparam int N = 3;
   
   logic          clk = 0, reset = 1;
   logic signed [WIDTH-1:0] out;
   logic signed [N*WIDTH-1:0] z;

   serializer #(.WIDTH(WIDTH), .N(N)) dut(clk, reset, z, out);

   always #5 clk = ~clk;

   always @(posedge clk)
     begin
        $display("[t=%0t] clk=%0d, state=%0d, out=%0d, z=[%0d, %0d, %0d]",
                 $time,
                 clk,
                 dut.state,
                 out,
                 z[0+:WIDTH],
                 z[WIDTH+:WIDTH],
                 z[2*WIDTH+:WIDTH]);
      end

   initial begin
      reset = 0;
      reset = 1;
      @(posedge clk);
      reset = 0;
      z[0+:WIDTH] = 0;
      z[WIDTH+:WIDTH] = 1;
      z[2*WIDTH+:WIDTH] = 2;
      repeat(2) @(posedge clk);
      $finish;
      
   end
   
endmodule
