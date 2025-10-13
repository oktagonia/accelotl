module matmul
  #(parameter N = 2,
    parameter M = 2,
    parameter WIDTH = 8,
    parameter OUT_WIDTH = 2*WIDTH + $clog2(M))
   (input logic                      clk, reset,
    input logic [N*WIDTH - 1:0]      A,
    input logic [WIDTH - 1:0]        b,
    output logic [N*OUT_WIDTH - 1:0] C,
    output logic                     done);

   logic [(N+1)*WIDTH - 1:0] S, E;
   logic [$clog2(M+1)-1:0]   count;

   assign S[0+:WIDTH] = b;
   
   generate
      for (genvar i = 0; i < N; i = i + 1) begin : fa_loop
         logic [WIDTH-1:0] n, w, s, e;
         logic [OUT_WIDTH-1:0] c;
         
         assign n = S[i * WIDTH+:WIDTH];
         assign w = A[i * WIDTH+:WIDTH];
         
         mac #(.WIDTH(WIDTH), .OUT_WIDTH(OUT_WIDTH)) pe(clk, reset, n, w, s, e, c);
         
         assign S[(i+1) * WIDTH+:WIDTH] = s;
         assign E[(i+1) * WIDTH+:WIDTH] = e;
         assign C[i * OUT_WIDTH+:OUT_WIDTH] = c;
      end
   endgenerate

   always_ff @(posedge clk, posedge reset)
     begin
        done <= reset ? 0 : (count == M);
        count <= reset ? 0 : (count == M ? 0 : count + 1);
     end
   
endmodule // matmul
