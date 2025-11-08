# Accelotl

Hardware neural network accelerator with systolic array architecture in SystemVerilog.

## Architecture

- **MAC units** with planned uniform quantization.
- **Systolic array** for matrix-vector multiplication
- **Weight store** with column-wise streaming
- **Queue** for activation storage and data feeding
- **FSM controller** for multi-layer execution

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
make module # to run the tb for module
```

**Requirements:** Icarus Verilog, GTKWave (optional)

## Design Notes

- TODO: Uniform quantization with configurable `SCALE_SHIFT` parameter
- Systolic array requires `(N-1)` padding columns per layer for pipeline delays
- FSM cycles: `IDLE → INIT → (COMPUTE → LOAD_OUTPUT)× → IDLE`
- Each `COMPUTE` state processes one weight column over N cycles
