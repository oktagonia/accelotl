# Accelotl (WIP)

![Axolotl](axolotl.jpg)

Hardware neural network accelerator with systolic array architecture in SystemVerilog.

## Modules

| Module            | Description                       |
| ----------------- | --------------------------------- |
| `mac.sv`          | Multiply-accumulate               |
| `matmul.sv`       | N×N systolic array                |
| `weight_store.sv` | Column-addressable weight memory  |
| `queue.sv`        | Shift register with parallel load |
| `accel.sv`        | Top-level controller with FSM     |

## Building

```bash
make mac
make matmul
make queue
make relu
make requantizer
make weight_store
make accel
```

**Requirements:** Icarus Verilog, GTKWave (optional)

## Digits Export Experiment

The current Python flow trains a small ReLU MLP on scikit-learn's 8x8 digits dataset, exports its quantized weights and biases, then runs the file-driven `accel_tb` against one generated test vector. Create a local venv with PyTorch and scikit-learn, then run:

```bash
.venv/bin/python -m src.run_digits_experiment --out build/digits_model
```

This writes `model.json`, `weights.hex`, `biases.hex`, `shifts.hex`, `inputs.hex`, and `expected.hex` under `build/digits_model`, compiles `tb/accel_tb.sv` with the exported model dimensions, and runs the RTL simulation. The testbench can also be run directly with plusargs such as `+weights=... +biases=... +shifts=... +inputs=... +expected=...`. The exporter itself lives in `src/exporter.py`; give it a PyTorch `Linear/ReLU/.../Linear` MLP and it will quantize, zero-pad non-square layers into the square hardware tile, and emit the hex files used by the simulator.

## Design Notes

- TODO: Uniform quantization with configurable `SCALE_SHIFT` parameter
- Integer-only control path works for two back-to-back `64x64` matmuls.
- Weights load while `accel` is idle.
- Weights are stored in padded/skewed stream order.
- `STREAM_CYCLES = 2*NEURONS - 1`.
- `LAYERS` is hardware capacity.
- `nlayers` is the active model depth.
- Layer output feedback currently truncates to `WIDTH`.

## FSM

```mermaid
stateDiagram-v2
  [*] --> IDLE
  IDLE --> LOAD_INPUT: start
  IDLE --> IDLE: !start
  LOAD_INPUT --> RESET_MATMUL
  RESET_MATMUL --> RESET_WEIGHT_POINTER: layer == 0
  RESET_MATMUL --> PRIME_WEIGHT: layer != 0
  RESET_WEIGHT_POINTER --> PRIME_WEIGHT
  PRIME_WEIGHT --> RUN
  RUN --> RUN: run_count != STREAM_CYCLES-1
  RUN --> CAPTURE: run_count == STREAM_CYCLES-1
  CAPTURE --> DONE: layer == nlayers-1
  CAPTURE --> LOAD_INPUT: layer != nlayers-1
  DONE --> DONE: start
  DONE --> IDLE: !start
```

| State | `done` | `le` | `acce` | `re` | `bre` | `shifte` | `wreset` | `mreset` | `qreset` |
| --- | ---: | ---: | ---: | --- | ---: | ---: | ---: | ---: | ---: |
| `IDLE` | 0 | 0 | 0 | 0 | 0 | 0 | 1 | 1 | 1 |
| `LOAD_INPUT` | 0 | 1 | 0 | 0 | 0 | 0 | 0 | 1 | 0 |
| `RESET_MATMUL` | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 1 | 0 |
| `RESET_WEIGHT_POINTER` | 0 | 0 | 0 | 0 | 0 | 0 | 1 | 1 | 0 |
| `PRIME_WEIGHT` | 0 | 0 | 0 | 1 | 1 | 0 | 0 | 0 | 0 |
| `RUN` | 0 | 0 | 1 | `run_count < STREAM_CYCLES-1` | 0 | 1 | 0 | 0 | 0 |
| `CAPTURE` | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| `DONE` | 1 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
