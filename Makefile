# Simple Makefile: one target per testbench
# Usage: make serializer / make mac / make matmul / make relu / make accel / make weight_store

IVERILOG ?= iverilog
VVP ?= vvp

.PHONY: serializer mac matmul relu accel weight_store queue combined clean

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
	mkdir -p build
	$(IVERILOG) -g2012 -o build/accel_tb rtl/mac.sv rtl/matmul.sv rtl/weight_store.sv rtl/queue.sv rtl/accel.sv tb/accel_tb.sv
	$(VVP) build/accel_tb

weight_store:
	$(IVERILOG) -g2012 -o weight_store_tb rtl/weight_store.sv tb/weight_store_tb.sv
	$(VVP) weight_store_tb

queue:
	$(IVERILOG) -g2012 -o queue_tb rtl/queue.sv tb/queue_tb.sv
	$(VVP) queue_tb

combined:
	$(IVERILOG) -g2012 -o combined_tb rtl/mac.sv rtl/matmul.sv rtl/weight_store.sv rtl/queue.sv tb/combined_tb.sv
	$(VVP) combined_tb

clean:
	rm -f *_tb *.vcd
