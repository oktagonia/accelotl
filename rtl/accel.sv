module accel
  #(parameter WIDTH = 8,
    parameter NEURONS = 3,
    parameter LAYERS = 3,
    parameter SHIFT_WIDTH = 5,
    parameter ROWS = NEURONS,
    parameter COLS = (2*NEURONS-1)*LAYERS,
    parameter OUT_WIDTH = 2*WIDTH + $clog2(NEURONS),
    parameter STREAM_CYCLES = 2*NEURONS - 1)
   (input logic                                 clk, reset, start,
    input logic                                 we,
    input logic [$clog2(COLS)-1:0]              wcol,
    input logic [ROWS*WIDTH-1:0]                wdata,
    input logic [$clog2(LAYERS+1)-1:0]          nlayers,
    input logic [LAYERS*SHIFT_WIDTH-1:0]        shifts,
    input logic signed [NEURONS*WIDTH-1:0]      init_qin,
    output logic signed [NEURONS*WIDTH-1:0] result,
    output logic                                done);

   logic re, empty;
   logic mdone;
   logic acce;
   logic le;
   logic we_;
   logic shifte;
   logic qreset, mreset, wreset;
   
   logic [ROWS*WIDTH-1:0] rdata;
   logic [SHIFT_WIDTH-1:0] shift;
   logic signed [WIDTH-1:0] north, south;
   logic signed [NEURONS*WIDTH-1:0] data;
   logic signed [NEURONS*WIDTH-1:0] feedback_qin;
   logic signed [NEURONS*WIDTH-1:0] reqout;
   logic signed [NEURONS*WIDTH-1:0] reluout;
   logic signed [NEURONS*OUT_WIDTH-1:0] out_vec;

   logic [$clog2(LAYERS):0]             layer;
   logic [$clog2(STREAM_CYCLES):0]      run_count;

   assign north = 0;
   assign we_ = we && (state == IDLE);
   assign shift = shifts[layer*SHIFT_WIDTH+:SHIFT_WIDTH];

   weight_store #(ROWS, COLS, WIDTH) weights
     (clk, we_, wcol, wdata, re, wreset, rdata, empty);

   matmul #(.N(NEURONS), .M(NEURONS), .WIDTH(WIDTH)) matmul
     (clk, mreset, acce, rdata, south, out_vec, mdone);

   queue #(.WIDTH(WIDTH), .LENGTH(NEURONS)) queue
     (clk, qreset, shifte, north, south, le, data);

   requantizer #(WIDTH, NEURONS, SHIFT_WIDTH, OUT_WIDTH) requantizer
     (shift, out_vec, reqout);

   relu #(WIDTH, NEURONS) relu(reqout, reluout);

   typedef enum logic [2:0]
     { IDLE,
       LOAD_INPUT,
       RESET_MATMUL,
       RESET_WEIGHT_POINTER,
       PRIME_WEIGHT,
       RUN,
       CAPTURE,
       DONE } state_t;

   state_t state, next_state;

   always_ff @(posedge clk, posedge reset)
     begin
        state <= reset ? IDLE : next_state;

        if (reset)
          begin
             layer <= 0;
             run_count <= 0;
          end

        if (state == CAPTURE && layer < nlayers - 1)
          for (int i = 0; i < NEURONS; i++)
            feedback_qin[(NEURONS-1-i)*WIDTH+:WIDTH] <= reluout[i*WIDTH+:WIDTH];
        
        if (state == IDLE && start)
          layer <= 0;
        else if (state == CAPTURE && layer != nlayers-1)
          layer <= layer + 1;

        if (state == CAPTURE)
          result <= reqout;

        run_count <= (state == RUN) ? run_count + 1 : 0;
     end

   always_comb
     begin
        done = 0;
        le = 0;
        acce = 0;
        re = 0;
        shifte = 0;
        wreset = 0;
        mreset = 0;
        qreset = 0;
        data = '0;
        
        case (state)
          IDLE:
            begin
               if (start)
                 next_state = LOAD_INPUT;
               else
                 next_state = IDLE;
               done = 0;
               le = 0;
               acce = 0;
               re = 0;
               shifte = 0;
               wreset = 1;
               mreset = 1;
               qreset = 1;
            end
          LOAD_INPUT:
            begin
               next_state = RESET_MATMUL;
               done = 0;
               le = 1;
               acce = 0;
               re = 0;
               shifte = 0;
               wreset = 0;
               mreset = 1;
               qreset = 0;
               data = (layer == 0) ? init_qin : feedback_qin;
            end
          RESET_MATMUL:
            begin
               if (layer == 0)
                 next_state = RESET_WEIGHT_POINTER;
               else
                 next_state = PRIME_WEIGHT;
               done = 0;
               le = 0;
               acce = 0;
               re = 0;
               shifte = 0;
               wreset = 0;
               mreset = 1;
               qreset = 0;
            end
          RESET_WEIGHT_POINTER:
            begin
               next_state = PRIME_WEIGHT;
               done = 0;
               le = 0;
               acce = 0;
               re = 0;
               shifte = 0;
               wreset = 1;
               mreset = 1;
               qreset = 0;
            end
          PRIME_WEIGHT:
            begin
               next_state = RUN;
               done = 0;
               le = 0;
               acce = 0;
               re = 1;
               shifte = 0;
               wreset = 0;
               mreset = 0;
               qreset = 0;
            end
          RUN:
            begin
               if (run_count == STREAM_CYCLES - 1)
                 next_state = CAPTURE;
               else
                 next_state = RUN;
               done = 0;
               le = 0;
               acce = 1;
               re = (run_count < STREAM_CYCLES - 1);
               shifte = 1;
               wreset = 0;
               mreset = 0;
               qreset = 0;
            end
          CAPTURE:
            begin
               if (layer == nlayers - 1)
                 next_state = DONE;
               else
                 next_state = LOAD_INPUT;
               done = 0;
               le = 0;
               acce = 0;
               re = 0;
               shifte = 0;
               wreset = 0;
               mreset = 0;
               qreset = 0;
            end
          DONE:
            begin
               if (start)
                 next_state = DONE;
               else
                 next_state = IDLE;
               done = 1;
               le = 0;
               re = 0;
               acce = 0;
               shifte = 0;
               wreset = 0;
               mreset = 0;
               qreset = 0;
            end
          default:
            next_state = IDLE;
        endcase // case (state)
     end

endmodule // accel

   
