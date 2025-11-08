module accel
  #(parameter WIDTH = 8,
    parameter NEURONS = 3,
    parameter LAYERS = 3,
    parameter ROWS = NEURONS,
    parameter COLS = (2*NEURONS-1)*LAYERS,
    parameter OUT_WIDTH = 2*WIDTH + $clog2(NEURONS))
   (input logic                             clk, reset, start,
    // weight ports
    input logic                             w_load_e, wreset,
    input logic [$clog2(COLS)-1:0]          wcol,
    input logic [ROWS*WIDTH-1:0]            wdata,
    // queue ports
    input logic signed [NEURONS*WIDTH-1:0]  init_qin,
    // output ports
    output logic signed [NEURONS*WIDTH-1:0] result,
    output logic                            done);

   // MODULES

   logic re, empty;
   logic [ROWS*COLS*WIDTH-1:0] weight;

   weight_store #(ROWS, COLS, WIDTH) weights
     (clk, w_load_e, wcol, wdata, re, wreset, weight, empty);

   logic mreset, mdone;
   logic signed [NEURONS*OUT_WIDTH-1:0] out_vec;

   matmul #(.N(NEURONS), .M(NEURONS), .WIDTH(WIDTH)) matmul
     (clk, mreset, weight, qout, out_vec, mdone);

   logic signed [WIDTH-1:0] qin, qout, qload;
   logic                    qreset;

   assign qin = 0;
   assign qreset = reset;

   queue #(.WIDTH(WIDTH), .LENGTH(NEURONS)) queue
     (clk, qreset, qin, qout, q_load_e, qload);

   // STATE MACHINE
   
   typedef enum logic [2:0]
     { IDLE,
       INIT,
       COMPUTE,
       LOAD_OUTPUT } state_t;

   state_t state, next_state;

   always_ff @(posedge clk, posedge reset)
     state <= reset ? IDLE : next_state;

   always_comb
     case (state)
       IDLE:
         begin
            next_state = start ? INIT : IDLE;
            re = 0;
            q_load_e = 0;
            mreset = 1;
            done = 0;
            qload = init_qin;
         end
       INIT:
         begin
            next_state = COMPUTE;
            q_load_e = 1;
            wreset = 1;
            mreset = 1;
            done = 0;
            re = 0;
            qload = init_qin;
         end
       COMPUTE:
         begin
            next_state = mdone ? LOAD_OUTPUT : COMPUTE;
            re = 1;
            q_load_e = 0;
            mreset = 0;
            wreset = 0;
            done = 0;
            qload = init_qin;
         end
       LOAD_OUTPUT:
         begin
            next_state = empty ? IDLE : COMPUTE;
            re = 0;
            q_load_e = 1;
            mreset = 1;
            wreset = 0;
            qload = out_vec;
            done = empty;
         end
       default:
         next_state = state;
     endcase // case (state)

   assign result = out_vec;

endmodule // accel

   
