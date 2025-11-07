`timescale 1ns/1ps

module weight_store_tb;

   localparam int WIDTH = 8;
   localparam int COLS = 9;
   localparam int ROWS = 3;

   logic          clk = 0;
   logic          we = 0;

   logic [$clog2(COLS)-1:0] wcol;
   logic [ROWS*WIDTH-1:0]   wdata;
   logic [ROWS*COLS*WIDTH-1:0] mat;

   weight_store #(ROWS, COLS, WIDTH) dut(clk, we, wcol, wdata, mat);

   always #5 clk = ~clk;

   initial 
     begin
        wcol  = 0;
        wdata = {8'd1, 8'd1, 8'd1};
        we    = 1;
        @(posedge clk);
        @(posedge clk);
        we    = 0; 

        $display("Column 0:");
        for (int r=0; r<ROWS; r++) $display("  row %0d = %0d", r, mat[r*COLS*WIDTH+:WIDTH]);

        wcol  = 1;
        wdata = {8'd2, 8'd2, 8'd2};
        we    = 1;
        @(posedge clk);
        @(posedge clk);
        we    = 0; 

        $display("Column 0:");
        for (int r=0; r<ROWS; r++) $display("  row %0d = %0d", r, mat[(r*COLS+1)*WIDTH+:WIDTH]);
        
        $finish;
     end // initial begin

endmodule // weight_store_tb
