module mac
  #(parameter WIDTH = 8, parameter OUT_WIDTH)
   (input logic                         clk, reset,
    input logic                         acce,
    input logic signed [WIDTH-1:0]      n, w,
    output logic signed [WIDTH-1:0]     s, e,
    output logic signed [OUT_WIDTH-1:0] p);
   
   always_ff @(posedge clk, posedge reset)
     begin
        if (acce && !reset)
          begin
             p <= p + n*w;
             s <= n;
             e <= w;
          end
        
        if (reset)
          begin
             p <= 0;
             s <= 0;
             e <= 0;
          end
     end
   
endmodule // mac
