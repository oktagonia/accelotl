# Simple Makefile: one target per testbench
# Usage: make serializer / make mac / make matmul / make relu / make accel / make weight_store

IVERILOG ?= iverilog
VVP ?= vvp

.PHONY: serializer mac matmul relu accel weight_store clean

serializer:
	$(IVERILOG) -g2012 -o serializer_tb rtl/serializer.sv tb/serializer_tb.sv
	$(VVP) serializer_tb

mac:
	$(IVERILOG) -g2012 -o mac_tb rtl/mac.sv tb/mac_tb.sv
	$(VVP) mac_tb

matmul:
	$(IVERILOG) -g2012 -o matmul_tb rtl/mac.sv rtl/matmul.sv tb/matmul_tb.sv
	$(VVP) matmul_tb

relu:
	$(IVERILOG) -g2012 -o relu_tb rtl/relu.sv tb/relu_tb.sv
	$(VVP) relu_tb

accel:
	$(IVERILOG) -g2012 -o accel_tb rtl/mac.sv rtl/matmul.sv rtl/activation.sv rtl/accel.sv tb/accel_tb.sv
	$(VVP) accel_tb

weight_store:
	$(IVERILOG) -g2012 -o weight_store_tb rtl/weight_store.sv tb/weight_store_tb.sv
	$(VVP) weight_store_tb

clean:
	rm -f *_tb *.vcd