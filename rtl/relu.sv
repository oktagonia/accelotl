module relu
  #(parameter WIDTH = 8)
   (input logic signed [WIDTH - 1:0]  z,
    output logic signed [WIDTH - 1:0] a);
   assign a = z > 0 ? z : 0;
endmodule // relu


