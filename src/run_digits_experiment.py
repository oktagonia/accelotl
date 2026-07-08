from __future__ import annotations

import argparse
import json
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


RTL_SOURCES = [
    "rtl/mac.sv",
    "rtl/matmul.sv",
    "rtl/weight_store.sv",
    "rtl/queue.sv",
    "rtl/requantizer.sv",
    "rtl/relu.sv",
    "rtl/bias_store.sv",
    "rtl/accel.sv",
    "tb/accel_tb.sv",
]


def run(cmd: list[str]) -> None:
    print("+", " ".join(cmd), flush=True)
    subprocess.run(cmd, cwd=ROOT, check=True)


def sign_extend(value: int, bits: int) -> int:
    return value - (1 << bits) if value & (1 << (bits - 1)) else value


def unpack_lanes(hex_line: str, lanes: int, bits: int) -> list[int]:
    value = int(hex_line.strip(), 16)
    mask = (1 << bits) - 1
    return [sign_extend((value >> (idx * bits)) & mask, bits) for idx in range(lanes)]


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", default="build/digits_model")
    parser.add_argument("--epochs", type=int, default=25)
    parser.add_argument("--batch-size", type=int, default=64)
    parser.add_argument("--hidden", type=int, default=64)
    parser.add_argument("--neurons", type=int, default=64)
    parser.add_argument("--lr", type=float, default=1e-3)
    parser.add_argument("--seed", type=int, default=0)
    parser.add_argument("--sim-index", type=int, default=0)
    args = parser.parse_args()

    out_dir = Path(args.out)
    run(
        [
            ".venv/bin/python",
            "-m",
            "src.train_digits",
            "--out",
            str(out_dir),
            "--epochs",
            str(args.epochs),
            "--batch-size",
            str(args.batch_size),
            "--hidden",
            str(args.hidden),
            "--neurons",
            str(args.neurons),
            "--lr",
            str(args.lr),
            "--seed",
            str(args.seed),
            "--sim-index",
            str(args.sim_index),
        ]
    )

    manifest = json.loads((ROOT / out_dir / "model.json").read_text())
    expected_hex = (ROOT / out_dir / "expected.hex").read_text().strip()
    expected = unpack_lanes(
        expected_hex,
        int(manifest["neurons"]),
        int(manifest["width"]),
    )
    class_count = int(manifest["layers_meta"][-1]["out_features"])
    print(f"desired packed output: 0x{expected_hex}", flush=True)
    print(f"desired logits: {expected[:class_count]}", flush=True)
    print(
        f"desired class: {max(range(class_count), key=lambda idx: expected[idx])}",
        flush=True,
    )

    sim_exe = ROOT / "build" / "digits_accel_tb"
    sim_exe.parent.mkdir(parents=True, exist_ok=True)

    run(
        [
            "iverilog",
            "-g2012",
            "-P",
            f"accel_tb.NEURONS={manifest['neurons']}",
            "-P",
            f"accel_tb.LAYERS={manifest['layers']}",
            "-P",
            "accel_tb.TEST_VECTORS=1",
            "-o",
            str(sim_exe),
            *RTL_SOURCES,
        ]
    )

    run(
        [
            "vvp",
            str(sim_exe),
            f"+weights={out_dir / manifest['weights']}",
            f"+biases={out_dir / manifest['biases']}",
            f"+shifts={out_dir / 'shifts.hex'}",
            f"+inputs={out_dir / 'inputs.hex'}",
            f"+expected={out_dir / 'expected.hex'}",
        ]
    )


if __name__ == "__main__":
    main()
