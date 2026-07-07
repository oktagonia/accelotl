module requantizer
  #(parameter WIDTH = 8,
    parameter NEURONS = 3,
    parameter SHIFT_WIDTH = 5,
    parameter OUT_WIDTH = 2*WIDTH + $clog2(NEURONS))
   (input logic [SHIFT_WIDTH-1:0]              shift,
    input logic signed [NEURONS*OUT_WIDTH-1:0] accs,
    output logic signed [NEURONS*WIDTH-1:0]    out);
   
   logic signed [OUT_WIDTH-1:0] maxval, minval, x;
   
   always_comb
     begin
        maxval = (1 <<< (WIDTH-1)) - 1;
        minval = -(1 <<< (WIDTH-1));
        out = '0;
        
        for (int i = 0; i < NEURONS; i++)
          begin
             x = $signed(accs[i*OUT_WIDTH+:OUT_WIDTH]) >>> shift;

             if (x > maxval)
               out[i*WIDTH+:WIDTH] = maxval[WIDTH-1:0];
             else if (x < minval)
               out[i*WIDTH+:WIDTH] = minval[WIDTH-1:0];
             else
               out[i*WIDTH+:WIDTH] = x[WIDTH-1:0];
          end
     end
   
endmodule // requantizer
