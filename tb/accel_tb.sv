`timescale 1ns/1ps

module accel_tb;
   localparam int WIDTH = 8;
   localparam int NEURONS = 4;
   localparam int LAYERS = 2;
   localparam int SHIFT_WIDTH = 5;
   localparam int ROWS = NEURONS;
   localparam int STREAM_CYCLES = 2*NEURONS - 1;
   localparam int COLS = STREAM_CYCLES * LAYERS;
   localparam int OUT_WIDTH = 2*WIDTH + $clog2(NEURONS);
   localparam int SHIFT0 = 2;
   localparam int SHIFT1 = 1;
   localparam int X_FRAC = 4;
   localparam int W0_FRAC = 3;
   localparam int Y0_FRAC = X_FRAC + W0_FRAC - SHIFT0;
   localparam int W1_FRAC = 2;
   localparam int Y1_FRAC = Y0_FRAC + W1_FRAC - SHIFT1;

   logic clk = 0;
   logic reset = 0;
   logic start = 0;
   logic we = 0;
   logic [$clog2(COLS)-1:0] wcol = 0;
   logic [ROWS*WIDTH-1:0] wdata = 0;
   logic [$clog2(LAYERS+1)-1:0] nlayers = LAYERS;
   logic [LAYERS*SHIFT_WIDTH-1:0] shifts = '0;
   logic signed [NEURONS*WIDTH-1:0] init_qin = 0;
   logic signed [NEURONS*WIDTH-1:0] result;
   logic done;

   int signed x[NEURONS];
   int signed w0[NEURONS][NEURONS];
   int signed w1[NEURONS][NEURONS];
   int signed y0_acc[NEURONS];
   int signed y0_q[NEURONS];
   int signed y1_acc[NEURONS];
   int signed y1_q[NEURONS];

   accel #(
      .WIDTH(WIDTH),
      .NEURONS(NEURONS),
      .LAYERS(LAYERS),
      .SHIFT_WIDTH(SHIFT_WIDTH)
   ) dut (
      .clk(clk),
      .reset(reset),
      .start(start),
      .we(we),
      .wcol(wcol),
      .wdata(wdata),
      .nlayers(nlayers),
      .shifts(shifts),
      .init_qin(init_qin),
      .result(result),
      .done(done)
   );

   always #5 clk = ~clk;

   function automatic int signed clamp_int8(input int signed value);
      begin
         if (value > 127)
           clamp_int8 = 127;
         else if (value < -128)
           clamp_int8 = -128;
         else
           clamp_int8 = value;
      end
   endfunction

   function automatic int signed requantize_ref(
      input int signed value,
      input int shift
   );
      requantize_ref = clamp_int8(value >>> shift);
   endfunction

   function automatic logic signed [WIDTH-1:0] to_width(input int signed value);
      to_width = value[WIDTH-1:0];
   endfunction

   function automatic real to_real(input int signed value, input int frac_bits);
      to_real = $itor(value) / $itor(1 << frac_bits);
   endfunction

   task automatic build_matrices;
      begin
         x[0] = 16;   // 1.00 in Q4
         x[1] = -8;   // -0.50 in Q4
         x[2] = 24;   // 1.50 in Q4
         x[3] = 4;    // 0.25 in Q4

         w0[0][0] = 8;   w0[0][1] = -4;  w0[0][2] = 0;   w0[0][3] = 4;
         w0[1][0] = -8;  w0[1][1] = 8;   w0[1][2] = 4;   w0[1][3] = 0;
         w0[2][0] = 4;   w0[2][1] = 0;   w0[2][2] = -4;  w0[2][3] = 8;
         w0[3][0] = 2;   w0[3][1] = 2;   w0[3][2] = 2;   w0[3][3] = 2;

         w1[0][0] = 4;   w1[0][1] = 0;   w1[0][2] = -4;  w1[0][3] = 8;
         w1[1][0] = -4;  w1[1][1] = 4;   w1[1][2] = 0;   w1[1][3] = 4;
         w1[2][0] = 8;   w1[2][1] = -8;  w1[2][2] = 4;   w1[2][3] = 0;
         w1[3][0] = 0;   w1[3][1] = 4;   w1[3][2] = 4;   w1[3][3] = -4;

         for (int row = 0; row < NEURONS; row++) begin
            y0_acc[row] = 0;
            y1_acc[row] = 0;

            for (int col = 0; col < NEURONS; col++)
              y0_acc[row] += w0[row][col] * x[col];

            y0_q[row] = requantize_ref(y0_acc[row], SHIFT0);
         end

         for (int row = 0; row < NEURONS; row++) begin
            for (int col = 0; col < NEURONS; col++)
              y1_acc[row] += w1[row][col] * y0_q[col];

            y1_q[row] = requantize_ref(y1_acc[row], SHIFT1);
         end
      end
   endtask

   task automatic load_col(
      input logic [$clog2(COLS)-1:0] col,
      input logic [ROWS*WIDTH-1:0] col_data
   );
      begin
         @(negedge clk);
         wcol = col;
         wdata = col_data;
         we = 1;
         @(posedge clk);
         @(negedge clk);
         we = 0;
      end
   endtask

   task automatic load_layer(input int layer_idx);
      logic [ROWS*WIDTH-1:0] col_data;
      int stream_col;
      int row;
      int logical_col;
      int signed weight;
      begin
         for (stream_col = 0; stream_col < STREAM_CYCLES; stream_col++) begin
            col_data = '0;

            for (row = 0; row < NEURONS; row++) begin
               logical_col = stream_col - row;
               weight = 0;

               if (logical_col >= 0 && logical_col < NEURONS) begin
                  if (layer_idx == 0)
                    weight = w0[row][logical_col];
                  else
                    weight = w1[row][logical_col];
               end

               col_data[row*WIDTH +: WIDTH] = to_width(weight);
            end

            load_col(layer_idx*STREAM_CYCLES + stream_col, col_data);
         end
      end
   endtask

   task automatic print_x;
      begin
         $write("x = [");
         for (int i = 0; i < NEURONS; i++) begin
            if (i != 0)
              $write(", ");
            $write("%0d", x[i]);
         end
         $display("]");
      end
   endtask

   task automatic print_real_values;
      begin
         $display("real scales:");
         $display("  x_real      = x / 2^%0d", X_FRAC);
         $display("  w0_real     = w0 / 2^%0d", W0_FRAC);
         $display("  y0_q_real   = y0_q / 2^%0d", Y0_FRAC);
         $display("  w1_real     = w1 / 2^%0d", W1_FRAC);
         $display("  output_real = output / 2^%0d", Y1_FRAC);

         $display("real matmul 0: y0 = w0*x");
         $write("x_real = [");
         for (int i = 0; i < NEURONS; i++) begin
            if (i != 0)
              $write(", ");
            $write("%0.6f", to_real(x[i], X_FRAC));
         end
         $display("]");

         $display("w0_real =");
         for (int row = 0; row < NEURONS; row++) begin
            $write("  [");
            for (int col = 0; col < NEURONS; col++) begin
               if (col != 0)
                 $write(", ");
               $write("%0.6f", to_real(w0[row][col], W0_FRAC));
            end
            $display("]");
         end

         $write("y0_acc_real = [");
         for (int i = 0; i < NEURONS; i++) begin
            if (i != 0)
              $write(", ");
            $write("%0.6f", to_real(y0_acc[i], X_FRAC + W0_FRAC));
         end
         $display("]");

         $write("y0_q_real = [");
         for (int i = 0; i < NEURONS; i++) begin
            if (i != 0)
              $write(", ");
            $write("%0.6f", to_real(y0_q[i], Y0_FRAC));
         end
         $display("]");

         $display("real matmul 1: y1 = w1*y0_q");
         $display("w1_real =");
         for (int row = 0; row < NEURONS; row++) begin
            $write("  [");
            for (int col = 0; col < NEURONS; col++) begin
               if (col != 0)
                 $write(", ");
               $write("%0.6f", to_real(w1[row][col], W1_FRAC));
            end
            $display("]");
         end

         $write("y1_acc_real = [");
         for (int i = 0; i < NEURONS; i++) begin
            if (i != 0)
              $write(", ");
            $write("%0.6f", to_real(y1_acc[i], Y0_FRAC + W1_FRAC));
         end
         $display("]");

         $write("expected_real = [");
         for (int i = 0; i < NEURONS; i++) begin
            if (i != 0)
              $write(", ");
            $write("%0.6f", to_real(y1_q[i], Y1_FRAC));
         end
         $display("]");
      end
   endtask

   task automatic print_w0;
      begin
         $display("w0 =");
         for (int row = 0; row < NEURONS; row++) begin
            $write("  [");
            for (int col = 0; col < NEURONS; col++) begin
               if (col != 0)
                 $write(", ");
               $write("%0d", w0[row][col]);
            end
            $display("]");
         end
      end
   endtask

   task automatic print_w1;
      begin
         $display("w1 =");
         for (int row = 0; row < NEURONS; row++) begin
            $write("  [");
            for (int col = 0; col < NEURONS; col++) begin
               if (col != 0)
                 $write(", ");
               $write("%0d", w1[row][col]);
            end
            $display("]");
         end
      end
   endtask

   task automatic print_refs;
      begin
         $write("y0_acc = [");
         for (int i = 0; i < NEURONS; i++) begin
            if (i != 0)
              $write(", ");
            $write("%0d", y0_acc[i]);
         end
         $display("]");

         $write("y0_q = [");
         for (int i = 0; i < NEURONS; i++) begin
            if (i != 0)
              $write(", ");
            $write("%0d", y0_q[i]);
         end
         $display("]");

         $write("y1_acc = [");
         for (int i = 0; i < NEURONS; i++) begin
            if (i != 0)
              $write(", ");
            $write("%0d", y1_acc[i]);
         end
         $display("]");

         $write("expected = [");
         for (int i = 0; i < NEURONS; i++) begin
            if (i != 0)
              $write(", ");
            $write("%0d", y1_q[i]);
         end
         $display("]");
      end
   endtask

   task automatic print_result(input string name);
      int signed got;
      begin
         $write("%s = [", name);
         for (int i = 0; i < NEURONS; i++) begin
            got = $signed(result[i*WIDTH +: WIDTH]);
            if (i != 0)
              $write(", ");
            $write("%0d", got);
         end
         $display("]");
      end
   endtask

   task automatic print_result_real(input string name);
      int signed got;
      begin
         $write("%s = [", name);
         for (int i = 0; i < NEURONS; i++) begin
            got = $signed(result[i*WIDTH +: WIDTH]);
            if (i != 0)
              $write(", ");
            $write("%0.6f", to_real(got, Y1_FRAC));
         end
         $display("]");
      end
   endtask

   initial begin
      $display("=== accel_tb: two fixed-point 4x4 matmuls ===");

      build_matrices();

      print_real_values();
      $display("integer fixed-point values:");
      print_x();
      print_w0();
      print_refs();
      print_w1();

      shifts[0*SHIFT_WIDTH +: SHIFT_WIDTH] = SHIFT0[SHIFT_WIDTH-1:0];
      shifts[1*SHIFT_WIDTH +: SHIFT_WIDTH] = SHIFT1[SHIFT_WIDTH-1:0];

      reset = 1;
      start = 0;
      we = 0;
      init_qin = 0;
      repeat (2) @(posedge clk);
      @(negedge clk);
      reset = 0;

      load_layer(0);
      load_layer(1);

      @(negedge clk);
      for (int i = 0; i < NEURONS; i++)
        init_qin[(NEURONS-1-i)*WIDTH +: WIDTH] = to_width(x[i]);

      start = 1;
      @(posedge clk);
      @(negedge clk);
      start = 0;

      wait (done);
      @(negedge clk);

      print_result("got");
      print_result_real("got_real");

      for (int i = 0; i < NEURONS; i++) begin
         int got;
         got = $signed(result[i*WIDTH +: WIDTH]);

         if (got !== y1_q[i])
           $error("row %0d result %0d expected %0d acc %0d", i, got, y1_q[i], y1_acc[i]);
      end

      $display("fixed-point 4x4 two-layer accel test complete");
      $finish;
   end

   initial begin
      #5000;
      $error("timeout waiting for done");
      $finish;
   end
endmodule
