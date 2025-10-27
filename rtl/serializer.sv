module serializer
  #(parameter N = 2,
    parameter WIDTH = 8)
   (input logic                        clk, reset,
    input logic [$clog2(N) - 1:0]      length, buffer,
    input logic signed [N*WIDTH - 1:0] S,
    output logic signed [WIDTH - 1:0]  z);

   logic [$clog2(N) - 1:0] index, state;

   always_ff @(posedge clk, posedge reset)
     begin
        if (reset) 
          begin
             state <= buffer;
             index <= 0;
             z <= 0;
          end
        else if (state > 0)
          begin
             state <= state - 1;
             z <= 0;
          end
        else if (index < length) 
          begin
             index <= index + 1;
             z <= S[index*WIDTH+:WIDTH];
          end
        else
          z <= 0;
     end

endmodule
