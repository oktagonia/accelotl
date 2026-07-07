`timescale 1ns/1ps

module requantizer_tb;
   localparam int WIDTH = 8;
   localparam int NEURONS = 4;
   localparam int SHIFT_WIDTH = 5;
   localparam int OUT_WIDTH = 16;

   logic [SHIFT_WIDTH-1:0] shift;
   logic signed [NEURONS*OUT_WIDTH-1:0] accs;
   logic signed [NEURONS*WIDTH-1:0] out;

   requantizer #(
      .WIDTH(WIDTH),
      .NEURONS(NEURONS),
      .SHIFT_WIDTH(SHIFT_WIDTH),
      .OUT_WIDTH(OUT_WIDTH)
   ) dut (
      .shift(shift),
      .accs(accs),
      .out(out)
   );

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

   task automatic set_acc(input int lane, input int signed value);
      accs[lane*OUT_WIDTH +: OUT_WIDTH] = value[OUT_WIDTH-1:0];
   endtask

   task automatic check_lane(input int lane, input int signed expected);
      int signed got;
      begin
         got = $signed(out[lane*WIDTH +: WIDTH]);
         if (got !== expected)
           $error("lane %0d got %0d expected %0d", lane, got, expected);
      end
   endtask

   task automatic check_vector;
      int signed acc;
      int signed expected;
      begin
         #1;
         for (int i = 0; i < NEURONS; i++) begin
            acc = $signed(accs[i*OUT_WIDTH +: OUT_WIDTH]);
            expected = clamp_int8(acc >>> shift);
            check_lane(i, expected);
         end
      end
   endtask

   initial begin
      $display("=== requantizer_tb ===");

      accs = '0;

      shift = 0;
      set_acc(0, 0);
      set_acc(1, 127);
      set_acc(2, -128);
      set_acc(3, 42);
      check_vector();

      shift = 2;
      set_acc(0, 512);
      set_acc(1, -512);
      set_acc(2, 508);
      set_acc(3, -508);
      check_vector();

      shift = 1;
      set_acc(0, 400);
      set_acc(1, -400);
      set_acc(2, 254);
      set_acc(3, -256);
      check_vector();

      shift = 4;
      set_acc(0, 2047);
      set_acc(1, -2048);
      set_acc(2, 1000);
      set_acc(3, -1000);
      check_vector();

      $display("requantizer_tb complete");
      $finish;
   end
endmodule
