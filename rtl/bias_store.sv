module bias_store
  #(parameter ROWS = 8,
    parameter LAYERS = 3,
    parameter OUT_WIDTH = 32)
   (input logic                              clk, reset,
    input logic                              we, re,
    input logic [$clog2(LAYERS)-1:0]         wlayer, rlayer,
    input logic signed [ROWS*OUT_WIDTH-1:0]  wdata,
    output logic signed [ROWS*OUT_WIDTH-1:0] rdata);
   
   logic signed [LAYERS*ROWS*OUT_WIDTH-1:0] biases;

   always_ff @(posedge clk)
     begin
        if (reset)
          begin
             biases <= '0;
             rdata <= '0;
          end

        if (we && !reset)
          biases[wlayer*ROWS*OUT_WIDTH+:ROWS*OUT_WIDTH] <= wdata;

        if (re && !reset)
          rdata <= biases[rlayer*ROWS*OUT_WIDTH+:ROWS*OUT_WIDTH];
     end
   
endmodule // bias_store
