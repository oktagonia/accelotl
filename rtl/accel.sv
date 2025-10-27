module accel
  #(parameter N = 2,
    parameter WIDTH = 8,
    parameter OUT_WIDTH = 2*WIDTH + $clog2(N))
   (input logic                           clk, reset,
    input logic signed [N*WIDTH - 1:0]    A,
    input logic signed [WIDTH - 1:0]      init_x,
    input logic [$clog2(N) - 1:0]         rate,
    input logic [$clog2(N) - 1:0]         buffer,
    input logic                           first_layer,
    input logic [$clog2(2*WIDTH+1) + 1:0] rescale,
    output logic signed [N*OUT_WIDTH - 1:0] out);
   
   logic signed [WIDTH - 1:0]       b_in;
   logic signed [OUT_WIDTH - 1:0]   z, a;
   logic signed [N*OUT_WIDTH - 1:0] y;
   logic signed [N*OUT_WIDTH - 1:0] stored_layer;
   logic                            done;
   
   // Store Layer 1 output when first_layer=1
   always_ff @(posedge clk) begin
      if (first_layer)
         stored_layer <= y;
   end

   // Mux: select init_x for first layer, otherwise feedback from serializer (truncated)
   assign b_in = first_layer ? init_x : z[WIDTH-1:0];
   
   // Perform matrix-vector multiply
   matmul #(.WIDTH(WIDTH), .N(N), .M(N)) matmul_unit(
      .clk(clk),
      .reset(reset),
      .A(A),
      .b(b_in),
      .C(y),
      .done(done)
   );
   
   // Serialize output to feed back (one element at a time)
   // For Layer 2, use stored Layer 1 output
   serializer #(.WIDTH(OUT_WIDTH), .N(N)) output_serializer(
      .clk(clk),
      .reset(reset),
      .length(rate),
      .buffer(buffer),
      .S(first_layer ? y : stored_layer),
      .z(z)
   );
   
   assign out = y;
   
   // TODO: Add activation and requantization for feedback path
   // relu #(.WIDTH(OUT_WIDTH)) relu(z, a);
   // requantizer #(.WIDTH(OUT_WIDTH), .OUT_WIDTH(WIDTH)) requantizer(a, b_feedback, rescale);
   
endmodule // accel

