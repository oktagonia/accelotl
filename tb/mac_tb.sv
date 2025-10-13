`timescale 1ns/1ps

module mac_tb;
   localparam WIDTH = 8;
   localparam OUT_WIDTH = 32;
   
   logic clk = 0;
   logic reset = 1;
   logic [WIDTH-1:0] n, w;
   logic [WIDTH-1:0] s, e;
   logic [OUT_WIDTH-1:0] p;
   
   mac #(.WIDTH(WIDTH), .OUT_WIDTH(OUT_WIDTH)) dut(
      .clk(clk), .reset(reset),
      .n(n), .w(w), .s(s), .e(e), .p(p)
   );
   
   always #5 clk = ~clk;
   
   initial begin
      $dumpfile("mac_tb.vcd");
      $dumpvars(0, mac_tb);
      
      $display("=== MAC Cell Testbench ===");
      
      reset = 1;
      n = 0;
      w = 0;
      #20;
      
      @(posedge clk);
      reset = 0;
      
      @(posedge clk);
      n = 8'd3;
      w = 8'd4;
      
      @(posedge clk);
      $display("After n=3, w=4: p=%0d (expect 12), s=%0d, e=%0d", p, s, e);
      
      n = 8'd5;
      w = 8'd6;
      
      @(posedge clk);
      $display("After n=5, w=6: p=%0d (expect 42), s=%0d, e=%0d", p, s, e);
      
      n = 8'd2;
      w = 8'd7;
      
      @(posedge clk);
      $display("After n=2, w=7: p=%0d (expect 56), s=%0d, e=%0d", p, s, e);
      
      @(posedge clk);
      reset = 1;
      
      @(posedge clk);
      $display("After reset: p=%0d (expect 0)", p);
      
      @(posedge clk);
      reset = 0;
      n = 8'd10;
      w = 8'd10;
      
      @(posedge clk);
      $display("After n=10, w=10: p=%0d (expect 100)", p);
      
      #50;
      $display("=== MAC Test Complete ===");
      $finish;
   end
endmodule
