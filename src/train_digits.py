from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
import torch
import torch.nn as nn
import torch.optim as optim
from sklearn.datasets import load_digits
from sklearn.model_selection import train_test_split
from torch.utils.data import DataLoader, TensorDataset

from src.exporter import AccelotlExporter


def _sign_extend(value: int, bits: int) -> int:
    value &= (1 << bits) - 1
    return value - (1 << bits) if value & (1 << (bits - 1)) else value


def _unpack_lanes(line: str, lanes: int, bits: int) -> list[int]:
    value = int(line.strip(), 16)
    mask = (1 << bits) - 1
    return [_sign_extend((value >> (lane * bits)) & mask, bits) for lane in range(lanes)]


def _pack_lanes(values: list[int] | np.ndarray, bits: int) -> str:
    packed = 0
    mask = (1 << bits) - 1

    for lane, value in enumerate(values):
        packed |= (int(value) & mask) << (lane * bits)

    hex_digits = (len(values) * bits + 3) // 4
    return f"{packed:0{hex_digits}x}"


def build_model(hidden: int) -> nn.Sequential:
    return nn.Sequential(
        nn.Linear(64, hidden),
        nn.ReLU(),
        nn.Linear(hidden, 10),
    )


def load_data(seed: int) -> tuple[TensorDataset, TensorDataset]:
    digits = load_digits()
    x = torch.tensor(digits.data, dtype=torch.float32) / 16.0
    y = torch.tensor(digits.target, dtype=torch.long)

    x_train, x_test, y_train, y_test = train_test_split(
        x,
        y,
        test_size=0.2,
        random_state=seed,
        stratify=y,
    )

    return TensorDataset(x_train, y_train), TensorDataset(x_test, y_test)


def accuracy(model: nn.Module, loader: DataLoader) -> float:
    correct = 0
    total = 0

    model.eval()
    with torch.no_grad():
        for x, y in loader:
            pred = model(x).argmax(dim=1)
            correct += int((pred == y).sum().item())
            total += int(y.numel())

    return correct / total


def train(
    model: nn.Module,
    train_loader: DataLoader,
    test_loader: DataLoader,
    *,
    epochs: int,
    lr: float,
) -> None:
    loss_fn = nn.CrossEntropyLoss()
    optimizer = optim.Adam(model.parameters(), lr=lr)

    for epoch in range(epochs):
        model.train()
        total_loss = 0.0

        for x, y in train_loader:
            optimizer.zero_grad()
            loss = loss_fn(model(x), y)
            loss.backward()
            optimizer.step()
            total_loss += float(loss.item()) * int(y.numel())

        avg_loss = total_loss / len(train_loader.dataset)
        test_acc = accuracy(model, test_loader)
        print(f"epoch {epoch + 1:02d}: loss={avg_loss:.4f} test_acc={test_acc:.4f}")


def write_sim_vectors(out_dir: Path, sample: torch.Tensor) -> None:
    import json

    manifest = json.loads((out_dir / "model.json").read_text())
    neurons = int(manifest["neurons"])
    width = int(manifest["width"])
    out_width = int(manifest["out_width"])
    layers = int(manifest["layers"])
    stream_cycles = int(manifest["stream_cycles"])

    weight_lines = (out_dir / "weights.hex").read_text().splitlines()
    bias_lines = (out_dir / "biases.hex").read_text().splitlines()

    weights = []
    biases = []

    for layer_idx in range(layers):
        weight = np.zeros((neurons, neurons), dtype=np.int64)
        offset = layer_idx * stream_cycles

        for stream_col in range(stream_cycles):
            lanes = _unpack_lanes(weight_lines[offset + stream_col], neurons, width)
            for row, value in enumerate(lanes):
                logical_col = stream_col - row
                if 0 <= logical_col < neurons:
                    weight[row, logical_col] = value

        weights.append(weight)
        biases.append(
            np.array(_unpack_lanes(bias_lines[layer_idx], neurons, out_width), dtype=np.int64)
        )

    first_scale = float(manifest["layers_meta"][0]["input_scale"])
    activation = np.rint(sample.detach().cpu().numpy() / first_scale)
    activation = np.clip(activation, -128, 127).astype(np.int64)
    input_vector = activation.copy()

    for meta, weight, bias in zip(manifest["layers_meta"], weights, biases):
        acc = weight @ activation + bias
        activation = np.right_shift(acc, int(meta["shift"]))
        activation = np.clip(activation, -128, 127).astype(np.int64)

        if meta["relu"]:
            activation = np.maximum(activation, 0)

    (out_dir / "shifts.hex").write_text(
        "\n".join(f"{int(shift):02x}" for shift in manifest["shifts"]) + "\n"
    )
    (out_dir / "inputs.hex").write_text(
        _pack_lanes(list(reversed(input_vector.tolist())), width) + "\n"
    )
    (out_dir / "expected.hex").write_text(_pack_lanes(activation, width) + "\n")


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

    if args.hidden > args.neurons:
        raise ValueError("--hidden must be <= --neurons for zero-padding export")

    torch.manual_seed(args.seed)

    train_set, test_set = load_data(args.seed)
    train_loader = DataLoader(train_set, batch_size=args.batch_size, shuffle=True)
    test_loader = DataLoader(test_set, batch_size=args.batch_size)
    calibration_loader = DataLoader(train_set, batch_size=args.batch_size)

    model = build_model(args.hidden)
    train(
        model,
        train_loader,
        test_loader,
        epochs=args.epochs,
        lr=args.lr,
    )

    out_dir = Path(args.out)
    manifest = AccelotlExporter(model, neurons=args.neurons).export(
        out_dir,
        calibration_data=calibration_loader,
    )
    write_sim_vectors(out_dir, test_set[args.sim_index][0])

    print(f"exported {manifest['layers']} layers to {out_dir}")
    print(f"weights: {out_dir / manifest['weights']}")
    print(f"biases:  {out_dir / manifest['biases']}")
    print(f"sim input: {out_dir / 'inputs.hex'}")
    print(f"sim expected: {out_dir / 'expected.hex'}")


if __name__ == "__main__":
    main()
