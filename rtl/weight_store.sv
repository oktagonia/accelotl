module weight_store
  #(parameter ROWS = 8,
    parameter COLS = 16,
    parameter WIDTH = 8)
   (input logic                    clk, 
    // write ports
    input logic                    we,
    input logic [$clog2(COLS)-1:0] wcol,
    input logic [ROWS*WIDTH-1:0]   wdata,
    // read ports
    input logic                   re, reset,
    output logic [ROWS*WIDTH-1:0] rdata,
    output logic                  empty);

   logic [ROWS*COLS*WIDTH-1:0] mat;
   logic [$clog2(COLS)-1:0]    rcol;
   
   always_ff @(posedge clk)
     begin
        if (reset)
          rcol <= 0;
        else if (re && !empty)
          rcol <= rcol + 1;
        
        if (we)
          for (int i = 0; i < ROWS; i++)
            mat[(i*COLS + wcol)*WIDTH+:WIDTH] <= wdata[i*WIDTH+:WIDTH];

        for (int i = 0; i < ROWS; i++)
          rdata[i*WIDTH+:WIDTH] <= mat[(i*COLS + rcol)*WIDTH+:WIDTH];
     end

   assign empty = rcol == COLS;

endmodule // weight_store
