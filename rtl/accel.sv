module accel
  #(parameter WIDTH = 8,
    parameter NEURONS = 3,
    parameter LAYERS = 3
    parameter ROWS = NEURONS,
    parameter COLS = 2*NEURONS*LAYERS-2*LAYER
    parameter OUT_WIDTH = 2*WIDTH + $clog2(M))
   (input logic                      clk,
    // weight ports
    input logic                      w_load_e, wreset
    input logic [$clog2(COLS)-1:0]   wcol,
    input logic [ROWS*WIDTH-1:0]     wdata
    // queue ports
    input logic signed [N*WIDTH-1:0] init_qin
    // matmul ports
    input logic                      mreset);

   logic re, empty;
   logic [ROWS*COLS*WIDTH-1:0] weight;

   weight_store #(ROWS, COLS, WIDTH) weights
     (clk, w_load_e, wcol, wdata, re, wreset, weight, empty);

   logic done;
   logic signed [NEURONS*OUT_WIDTH-1:0] out_vec;

   matmul #(.N(NEURONS), .M(NEURONS), .WIDTH(WIDTH)) matmul
     (clk, mreset, weight, qout, out_vec, done);

   logic signed [WIDTH-1:0] qin = 0, qout;

   queue #(.WIDTH(WIDTH), .LENGTH(NEORONS)) queue
     (clk, qreset, qin, qout, q_load_e, out_vec);

endmodule // accel

   
