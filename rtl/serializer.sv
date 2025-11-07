module serializer
  #(parameter N = 3,
    parameter WIDTH = 8)
   (input logic               clk, reset,
    input logic [N*WIDTH-1:0] z,
    output logic [WIDTH-1:0]  out);

   logic [$clog2(N-1):0] state;

   always_ff @(posedge clk, posedge reset)
     state <= (reset || state == N - 1) ? 0 : state + 1;
   
   assign out = reset ? 0 : z[state*WIDTH+:WIDTH];
   
endmodule // serializer
