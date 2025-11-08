module accel
  #(parameter WIDTH = 8,
    parameter NEURONS = 3,
    parameter LAYERS = 3
    parameter ROWS = NEURONS,
    parameter COLS = 2*NEURONS*LAYERS-2*LAYER
    parameter OUT_WIDTH = 2*WIDTH + $clog2(M))
   (input logic                             clk, reset
    // weight ports
    input logic                             w_load_e, wreset
    input logic [$clog2(COLS)-1:0]          wcol,
    input logic [ROWS*WIDTH-1:0]            wdata
    // queue ports
    input logic signed [NEURONS*WIDTH-1:0]  init_qin
    // matmul ports
    input logic                             mreset
    // output ports
    output logic signed [NEURONS*WIDTH-1:0] result,
    output logic                            done);

   // MODULES

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

   // STATE MACHINE
   
   typedef enum logic [2:0]
     { IDLE,
       INIT,
       COMPUTE,
       DONE } state_t;

   state_t state, next_state;

   always_ff @(posedge clk, posedge reset)
     state <= reset ? IDLE : next_state;

   always_comb
     case (state)
       IDLE:
         begin
            next_state = INIT;
         end
       INIT:
         begin
            next_state = COMPUTE;
         end
       COMPUTE:
         begin
            next_state = DONE;
         end
       DONE:
         begin
            next_state = IDLE;
         end
       default:
         next_state = state;
     endcase // case (state)

endmodule // accel

   
