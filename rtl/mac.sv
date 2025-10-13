// systolic array for matrix multiplication in verilog

module mac
  #(parameter WIDTH = 8, parameter OUT_WIDTH)
   (input logic               clk, reset,
    input logic [WIDTH-1:0]    n, w, // incoming from north and west
    output logic [WIDTH-1:0]   s, e, // outgoing to south and east
    output logic [OUT_WIDTH-1:0] p);
   
   always_ff @(posedge clk, posedge reset)
     begin
        p <= reset ? 0 : p + n*w;
        s <= reset ? 0 : n;
        e <= reset ? 0 : w;
     end
   
endmodule // mac
