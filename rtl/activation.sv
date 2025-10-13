module activation
  #(parameter N = 2,
    parameter WIDTH = 8,
    parameter OUT_WIDTH = 2*WIDTH + $clog2(N))
   (input logic                      clk, reset,
    input logic [N*OUT_WIDTH - 1:0]  C,
    output logic [N*OUT_WIDTH - 1:0] Z);
   
   logic [$clog2(N)-1:0] state;
   logic [OUT_WIDTH - 1:0] s;
   
   always_ff @(posedge clk, posedge reset)
     state <= reset || (state == N-1) ? 0 : (state + 1);

   assign s = S[state * OUT_WIDTH+:OUT_WIDTH];
   assign Z[state * OUT_WIDTH+:OUT_WIDTH] = s >= 0 ? s : 0;
   
endmodule
