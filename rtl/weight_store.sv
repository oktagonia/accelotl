module weight_store
  #(parameter ROWS = 8,
    parameter COLS = 16,
    parameter WIDTH = 8)
   (input logic                        clk, we,
    input logic [$clog2(COLS)-1:0]     wcol,
    input logic [ROWS*WIDTH-1:0]       wdata,
    output logic [ROWS*COLS*WIDTH-1:0] mat);
   
   always_ff @(posedge clk)
     if (we)
       for (int i = 0; i < ROWS; i++)
         mat[(i*COLS + wcol)*WIDTH+:WIDTH] <= wdata[i*WIDTH+:WIDTH];

endmodule // weight_store
