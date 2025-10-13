# Makefile for systolic array accelerator project

# Simulator
SIM = iverilog
SIMFLAGS = -g2012 -Wall

# Directories
RTL_DIR = rtl
TB_DIR = tb
BUILD_DIR = build

# RTL files
RTL_SRCS = $(RTL_DIR)/mac.sv $(RTL_DIR)/matmul.sv

# Testbenches
MAC_TB = $(TB_DIR)/mac_tb.sv
MATMUL_TB = $(TB_DIR)/matmul_tb.sv

# Output executables
MAC_OUT = $(BUILD_DIR)/mac_tb
MATMUL_OUT = $(BUILD_DIR)/matmul_tb

# VCD files
MAC_VCD = mac_tb.vcd
MATMUL_VCD = matmul_tb.vcd

.PHONY: all clean mac matmul run_mac run_matmul

all: mac matmul

# Create build directory
$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

# MAC testbench
mac: $(BUILD_DIR) $(MAC_OUT)

$(MAC_OUT): $(RTL_DIR)/mac.sv $(MAC_TB)
	$(SIM) $(SIMFLAGS) -o $(MAC_OUT) $(RTL_DIR)/mac.sv $(MAC_TB)

run_mac: $(MAC_OUT)
	./$(MAC_OUT)
	@echo "Waveform saved to $(MAC_VCD)"

# MatMul testbench
matmul: $(BUILD_DIR) $(MATMUL_OUT)

$(MATMUL_OUT): $(RTL_DIR)/mac.sv $(RTL_DIR)/matmul.sv $(MATMUL_TB)
	$(SIM) $(SIMFLAGS) -o $(MATMUL_OUT) $(RTL_DIR)/mac.sv $(RTL_DIR)/matmul.sv $(MATMUL_TB)

run_matmul: $(MATMUL_OUT)
	./$(MATMUL_OUT)
	@echo "Waveform saved to $(MATMUL_VCD)"

# Run all tests
test: run_mac run_matmul

# Clean build artifacts
clean:
	rm -rf $(BUILD_DIR)
	rm -f *.vcd
	rm -f sim

# Display help
help:
	@echo "Available targets:"
	@echo "  all           - Build all testbenches"
	@echo "  mac           - Build MAC testbench"
	@echo "  matmul        - Build MatMul testbench"
	@echo "  run_mac       - Run MAC testbench"
	@echo "  run_matmul    - Run MatMul testbench"
	@echo "  test          - Run all tests"
	@echo "  clean         - Clean build artifacts"

