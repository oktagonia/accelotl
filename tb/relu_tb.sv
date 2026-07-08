`timescale 1ns/1ps

module relu_tb;
   localparam int WIDTH = 8;
   localparam int NEURONS = 4;

   logic signed [NEURONS*WIDTH-1:0] z;
   logic signed [NEURONS*WIDTH-1:0] a;

   relu #(
      .WIDTH(WIDTH),
      .NEURONS(NEURONS)
   ) dut (
      .z(z),
      .a(a)
   );

   function automatic logic signed [WIDTH-1:0] to_width(input int signed value);
      to_width = value[WIDTH-1:0];
   endfunction

   function automatic int signed relu_ref(input int signed value);
      relu_ref = (value > 0) ? value : 0;
   endfunction

   task automatic set_lane(input int lane, input int signed value);
      z[lane*WIDTH +: WIDTH] = to_width(value);
   endtask

   task automatic check_lane(input int lane, input int signed expected);
      int signed got;
      begin
         got = $signed(a[lane*WIDTH +: WIDTH]);
         if (got !== expected)
           $error("lane %0d got %0d expected %0d", lane, got, expected);
      end
   endtask

   task automatic check_vector;
      int signed input_value;
      int signed expected;
      begin
         #1;
         for (int i = 0; i < NEURONS; i++) begin
            input_value = $signed(z[i*WIDTH +: WIDTH]);
            expected = relu_ref(input_value);
            check_lane(i, expected);
         end
      end
   endtask

   initial begin
      $display("=== relu_tb ===");

      z = '0;
      set_lane(0, 50);
      set_lane(1, -50);
      set_lane(2, 0);
      set_lane(3, 127);
      check_vector();

      set_lane(0, -128);
      set_lane(1, -1);
      set_lane(2, 1);
      set_lane(3, 64);
      check_vector();

      for (int lane = 0; lane < NEURONS; lane++) begin
         z = '0;
         set_lane(lane, -25);
         check_vector();

         set_lane(lane, 25);
         check_vector();
      end

      for (int value = -128; value < 128; value++) begin
         for (int lane = 0; lane < NEURONS; lane++)
           set_lane(lane, value + lane);
         check_vector();
      end

      $display("relu_tb complete");
      $finish;
   end
endmodule
