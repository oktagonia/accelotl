`timescale 1ns/1ps

module weight_store_tb;

   localparam int WIDTH = 8;
   localparam int COLS = 9;
   localparam int ROWS = 3;

   logic          clk = 0;
   
   logic          we = 0;
   logic [$clog2(COLS)-1:0] wcol;
   logic [ROWS*WIDTH-1:0]   wdata;

   logic                    re = 0, reset, empty;
   logic [ROWS*WIDTH-1:0]   rdata;

   weight_store #(ROWS, COLS, WIDTH) dut(clk, we, wcol, wdata, re, reset, rdata, empty);

   always #5 clk = ~clk;

   initial 
     begin
        wcol  = 0;
        wdata = {8'd1, 8'd1, 8'd1};
        we    = 1;
        @(posedge clk);
        @(posedge clk);
        we    = 0; 

        wcol  = 1;
        wdata = {8'd2, 8'd2, 8'd2};
        we    = 1;
        @(posedge clk);
        @(posedge clk);
        we    = 0;

        wcol  = 2;
        wdata = {8'd3, 8'd3, 8'd3};
        we    = 1;
        @(posedge clk);
        @(posedge clk);
        we    = 0;

        reset = 1;
        @(posedge clk);
        reset = 0;
        re = 1;
        @(posedge clk);  // rdata has mat[0]
        
        @(posedge clk);  // rdata has mat[0]
        $display("Column 0:");
        for (int r=0; r<ROWS; r++) $display("  rdata[%0d] = %0d", r, rdata[r*WIDTH+:WIDTH]);

        @(posedge clk);  // rcol increments 0→1, rdata gets mat[1]
        $display("Column 1:");
        for (int r=0; r<ROWS; r++) $display("  rdata[%0d] = %0d", r, rdata[r*WIDTH+:WIDTH]);

        @(posedge clk);  // rcol increments 0→1, rdata gets mat[1]
        $display("Column 3:");
        for (int r=0; r<ROWS; r++) $display("  rdata[%0d] = %0d", r, rdata[r*WIDTH+:WIDTH]);
        
        $finish;
     end // initial begin

endmodule // weight_store_tb
