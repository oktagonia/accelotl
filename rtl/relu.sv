module relu
  #(parameter WIDTH = 8,
    parameter NEURONS = 3)
   (input logic signed [NEURONS*WIDTH-1:0]  z,
    output logic signed [NEURONS*WIDTH-1:0] a);

   logic signed [WIDTH-1:0] x;

   always_comb
     for (int i = 0; i < NEURONS; i++)
       begin
          x = z[i*WIDTH+:WIDTH];
          a[i*WIDTH+:WIDTH] = x > 0 ? x : '0;
       end
   
endmodule // relu


