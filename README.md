# Systolic Array Accelerator

Matrix multiplication accelerator using systolic array architecture in SystemVerilog.

## Project Structure

```
accel/
├── rtl/                    # RTL source files
│   ├── mac.sv              # Multiply-Accumulate cell
│   └── matmul.sv           # Matrix multiplier module
├── tb/                     # Testbenches
│   ├── mac_tb.sv           # MAC cell testbench
│   └── matmul_tb.sv        # Matrix multiplier testbench
├── Makefile                # Build system
└── README.md               # This file
```

## Modules

### MAC Cell (`rtl/mac.sv`)
- Multiply-accumulate processing element
- Core building block of systolic array
- Passes data north→south and west→east

### Matrix Multiplier (`rtl/matmul.sv`)
- Parameterized N×N systolic array
- Computes matrix-vector multiplication
- Configurable bit width and array size

## Building and Running

### Requirements
- Icarus Verilog (iverilog)
- GTKWave (optional, for viewing waveforms)

### Build all testbenches
```bash
make all
```

### Run individual tests
```bash
make run_mac          # Run MAC cell test
make run_matmul       # Run matrix multiply test
```

### Run all tests
```bash
make test
```

### View waveforms
```bash
gtkwave matmul_tb.vcd
```

### Clean build artifacts
```bash
make clean
```

## Architecture

The systolic array uses a diagonal data feeding pattern where:
- Matrix elements flow horizontally (west→east)
- Vector elements flow vertically (north→south)
- Each MAC cell accumulates partial products
- Results emerge at the bottom of the array

### Example: 3×3 Matrix-Vector Multiply

```
Matrix A:              Vector b:         Result C:
[2, 3, 4]              [1]               [20]
[5, 6, 7]      ×       [2]       =       [38]
[8, 9, 1]              [3]               [29]
```

The systolic array computes this efficiently with N time steps for data feeding and N more for draining.

