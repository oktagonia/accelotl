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
ACCEL_TB = $(TB_DIR)/accel_tb.sv
SERIALIZER_TB = $(TB_DIR)/serializer_tb.sv

# Output executables
MAC_OUT = $(BUILD_DIR)/mac_tb
MATMUL_OUT = $(BUILD_DIR)/matmul_tb
ACCEL_OUT = $(BUILD_DIR)/accel_tb
SERIALIZER_OUT = $(BUILD_DIR)/serializer_tb

# VCD files
MAC_VCD = mac_tb.vcd
MATMUL_VCD = matmul_tb.vcd
ACCEL_VCD = accel_tb.vcd
SERIALIZER_VCD = serializer_tb.vcd

.PHONY: all clean mac matmul accel serializer run_mac run_matmul run_accel run_serializer

all: mac matmul accel serializer

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

# Accel testbench
accel: $(BUILD_DIR) $(ACCEL_OUT)

$(ACCEL_OUT): $(RTL_DIR)/mac.sv $(RTL_DIR)/matmul.sv $(RTL_DIR)/serializer.sv $(RTL_DIR)/accel.sv $(ACCEL_TB)
	$(SIM) $(SIMFLAGS) -o $(ACCEL_OUT) $(RTL_DIR)/mac.sv $(RTL_DIR)/matmul.sv $(RTL_DIR)/serializer.sv $(RTL_DIR)/accel.sv $(ACCEL_TB)

run_accel: $(ACCEL_OUT)
	./$(ACCEL_OUT)
	@echo "Waveform saved to $(ACCEL_VCD)"

# Serializer testbench
serializer: $(BUILD_DIR) $(SERIALIZER_OUT)

$(SERIALIZER_OUT): $(RTL_DIR)/mac.sv $(RTL_DIR)/matmul.sv $(RTL_DIR)/serializer.sv $(SERIALIZER_TB)
	$(SIM) $(SIMFLAGS) -o $(SERIALIZER_OUT) $(RTL_DIR)/mac.sv $(RTL_DIR)/matmul.sv $(RTL_DIR)/serializer.sv $(SERIALIZER_TB)

run_serializer: $(SERIALIZER_OUT)
	./$(SERIALIZER_OUT)
	@echo "Waveform saved to $(SERIALIZER_VCD)"

# Run all tests
test: run_mac run_matmul run_accel run_serializer

# Clean build artifacts
clean:
	rm -rf $(BUILD_DIR)
	rm -f *.vcd
	rm -f sim

# Display help
help:
	@echo "Available targets:"
	@echo "  all              - Build all testbenches"
	@echo "  mac              - Build MAC testbench"
	@echo "  matmul           - Build MatMul testbench"
	@echo "  accel            - Build Accel testbench"
	@echo "  serializer       - Build Serializer testbench"
	@echo "  run_mac          - Run MAC testbench"
	@echo "  run_matmul       - Run MatMul testbench"
	@echo "  run_accel        - Run Accel testbench"
	@echo "  run_serializer   - Run Serializer testbench"
	@echo "  test             - Run all tests"
	@echo "  clean            - Clean build artifacts"

