module queue
  #(parameter WIDTH = 8,
    parameter LENGTH)
   (input logic                           clk, reset,
    // queue ports
    input logic signed [WIDTH-1:0]        north,
    output logic signed [WIDTH-1:0]       south,
    // load ports
    input logic                           le,
    input logic signed [LENGTH*WIDTH-1:0] data);

   logic signed [LENGTH*WIDTH-1:0] regs;

   always_ff @(posedge clk, posedge reset)
     begin
        if (reset)
          regs <= 0;
        else if (le)
          regs <= data;
        else
          begin
             regs[0+:WIDTH] <= north;
             for (int i = 1; i < LENGTH; i++)
               regs[i*WIDTH+:WIDTH] <= regs[(i-1)*WIDTH+:WIDTH];
          end
     end // always_ff @ (posedge clk, reset)

   assign south = regs[(LENGTH-1)*WIDTH+:WIDTH];
   
endmodule // queue

      
