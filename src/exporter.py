from __future__ import annotations

import json
import math
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, Sequence

import numpy as np
import torch
import torch.nn as nn


@dataclass(frozen=True)
class LinearLayer:
    module: nn.Linear
    in_features: int
    out_features: int
    relu: bool


@dataclass(frozen=True)
class QuantizedLayer:
    weight: np.ndarray
    bias: np.ndarray
    in_features: int
    out_features: int
    weight_scale: float
    input_scale: float
    output_scale: float
    shift: int
    relu: bool


def _leaf_modules(model: nn.Module) -> list[nn.Module]:
    return [module for module in model.modules() if not list(module.children())]


def _mlp_modules(model: nn.Module) -> list[nn.Module]:
    modules = _leaf_modules(model)

    if modules and isinstance(modules[0], nn.Flatten):
        modules = modules[1:]

    return modules


def _next_power_of_two(value: float) -> float:
    if value <= 0.0 or not math.isfinite(value):
        return 1.0

    return float(2 ** math.ceil(math.log2(value)))


def _symmetric_int8_scale(values: np.ndarray) -> float:
    max_abs = float(np.max(np.abs(values))) if values.size else 0.0
    return _next_power_of_two(max_abs / 127.0)


def _quantize_int8(values: np.ndarray, scale: float) -> np.ndarray:
    quantized = np.rint(values / scale)
    return np.clip(quantized, -128, 127).astype(np.int8)


def _signed_range(bits: int) -> tuple[int, int]:
    return -(1 << (bits - 1)), (1 << (bits - 1)) - 1


def _quantize_signed(values: np.ndarray, scale: float, bits: int) -> np.ndarray:
    minval, maxval = _signed_range(bits)
    quantized = np.rint(values / scale)
    return np.clip(quantized, minval, maxval).astype(np.int64)


def _twos_complement(value: int, bits: int) -> int:
    return int(value) & ((1 << bits) - 1)


def _pack_lanes(values: Sequence[int], width: int) -> str:
    packed = 0
    for lane, value in enumerate(values):
        packed |= _twos_complement(int(value), width) << (lane * width)

    hex_digits = math.ceil((len(values) * width) / 4)
    return f"{packed:0{hex_digits}x}"


class AccelotlExporter:
    """Export a sequential PyTorch MLP into the current Accelotl RTL layout."""

    def __init__(
        self,
        model: nn.Module,
        *,
        neurons: int,
        width: int = 8,
        shift_width: int = 5,
        out_width: int | None = None,
    ) -> None:
        self.model = model.eval()
        self.neurons = neurons
        self.width = width
        self.shift_width = shift_width
        self.out_width = out_width or (2 * width + math.ceil(math.log2(neurons)))

    def collect_layers(self) -> list[LinearLayer]:
        modules = _mlp_modules(self.model)
        layers: list[LinearLayer] = []
        previous_out_features: int | None = None
        idx = 0

        while idx < len(modules):
            module = modules[idx]

            if not isinstance(module, nn.Linear):
                raise ValueError(
                    "expected a ReLU-MLP of Linear/ReLU layers; "
                    f"found {module!r} at position {idx}"
                )

            if module.bias is None:
                raise ValueError("current RTL exporter expects nn.Linear bias tensors")

            if (
                previous_out_features is not None
                and module.in_features != previous_out_features
            ):
                raise ValueError(
                    "MLP layer dimensions do not chain: previous layer outputs "
                    f"{previous_out_features}, next Linear expects {module.in_features}"
                )

            if module.in_features > self.neurons or module.out_features > self.neurons:
                raise ValueError(
                    "current RTL exporter zero-pads into a fixed square "
                    f"{self.neurons}x{self.neurons} matmul; got Linear("
                    f"{module.in_features}, {module.out_features})"
                )

            relu = idx + 1 < len(modules) and isinstance(modules[idx + 1], nn.ReLU)

            if relu and idx + 2 == len(modules):
                raise ValueError("final Linear layer should not be followed by ReLU")

            if idx + 1 < len(modules) and not relu:
                raise ValueError(
                    "expected each hidden Linear layer in the ReLU-MLP to be "
                    f"followed by ReLU; layer at position {idx} is not"
                )

            layers.append(
                LinearLayer(
                    module=module,
                    in_features=module.in_features,
                    out_features=module.out_features,
                    relu=relu,
                )
            )
            previous_out_features = module.out_features
            idx += 2 if relu else 1

        if not layers:
            raise ValueError("model does not contain any nn.Linear layers")

        return layers

    def calibrate_activations(
        self,
        calibration_data: Iterable[torch.Tensor | tuple[torch.Tensor, object]],
    ) -> list[float]:
        layers = self.collect_layers()
        max_abs = [0.0 for _ in range(len(layers) + 1)]

        with torch.no_grad():
            for batch in calibration_data:
                x = batch[0] if isinstance(batch, (list, tuple)) else batch
                x = x.detach().float().cpu().reshape(x.shape[0], -1)
                max_abs[0] = max(max_abs[0], float(x.abs().max().item()))

                for idx, layer in enumerate(layers):
                    x = layer.module.cpu()(x)
                    if layer.relu:
                        x = torch.relu(x)
                    max_abs[idx + 1] = max(max_abs[idx + 1], float(x.abs().max().item()))

        return [_next_power_of_two(value / 127.0) for value in max_abs]

    def quantize(
        self,
        *,
        activation_scales: Sequence[float],
    ) -> list[QuantizedLayer]:
        layers = self.collect_layers()

        if len(activation_scales) != len(layers) + 1:
            raise ValueError(
                "activation_scales must contain one input scale plus one output "
                f"scale per layer; expected {len(layers) + 1}, got {len(activation_scales)}"
            )

        quantized_layers: list[QuantizedLayer] = []
        max_shift = (1 << self.shift_width) - 1

        for idx, layer in enumerate(layers):
            linear = layer.module
            weight_float = linear.weight.detach().cpu().numpy().astype(np.float64)
            bias_float = linear.bias.detach().cpu().numpy().astype(np.float64)

            input_scale = float(activation_scales[idx])
            requested_output_scale = float(activation_scales[idx + 1])
            weight_scale = _symmetric_int8_scale(weight_float)
            acc_scale = input_scale * weight_scale

            if acc_scale <= 0.0:
                raise ValueError(f"invalid accumulator scale for layer {idx}: {acc_scale}")

            shift_ratio = requested_output_scale / acc_scale
            shift = max(0, int(round(math.log2(shift_ratio)))) if shift_ratio > 0.0 else 0
            shift = min(shift, max_shift)
            output_scale = acc_scale * (1 << shift)

            quantized_layers.append(
                QuantizedLayer(
                    weight=_quantize_int8(weight_float, weight_scale),
                    bias=_quantize_signed(bias_float, acc_scale, self.out_width),
                    in_features=layer.in_features,
                    out_features=layer.out_features,
                    weight_scale=weight_scale,
                    input_scale=input_scale,
                    output_scale=output_scale,
                    shift=shift,
                    relu=layer.relu,
                )
            )

        return quantized_layers

    def pack_weight_layer(self, weight: np.ndarray) -> list[str]:
        if weight.shape[0] > self.neurons or weight.shape[1] > self.neurons:
            raise ValueError(
                f"cannot pack weight shape {weight.shape} into "
                f"{self.neurons}x{self.neurons} hardware tile"
            )

        stream_cycles = 2 * self.neurons - 1
        padded = np.zeros((self.neurons, self.neurons), dtype=weight.dtype)
        padded[: weight.shape[0], : weight.shape[1]] = weight
        lines: list[str] = []

        for stream_col in range(stream_cycles):
            lanes = []
            for row in range(self.neurons):
                logical_col = stream_col - row
                if 0 <= logical_col < self.neurons:
                    lanes.append(int(padded[row, logical_col]))
                else:
                    lanes.append(0)

            lines.append(_pack_lanes(lanes, self.width))

        return lines

    def pack_bias_layer(self, bias: np.ndarray) -> str:
        if bias.shape[0] > self.neurons:
            raise ValueError(
                f"cannot pack bias length {bias.shape[0]} into {self.neurons} lanes"
            )

        padded = np.zeros(self.neurons, dtype=bias.dtype)
        padded[: bias.shape[0]] = bias
        return _pack_lanes([int(value) for value in padded], self.out_width)

    def export(
        self,
        out_dir: str | Path,
        *,
        activation_scales: Sequence[float] | None = None,
        calibration_data: Iterable[torch.Tensor | tuple[torch.Tensor, object]] | None = None,
    ) -> dict[str, object]:
        if activation_scales is None:
            if calibration_data is None:
                raise ValueError("provide activation_scales or calibration_data")
            activation_scales = self.calibrate_activations(calibration_data)

        quantized_layers = self.quantize(activation_scales=activation_scales)
        out_path = Path(out_dir)
        out_path.mkdir(parents=True, exist_ok=True)

        weight_lines: list[str] = []
        bias_lines: list[str] = []
        layer_meta: list[dict[str, object]] = []

        for idx, layer in enumerate(quantized_layers):
            weight_offset = len(weight_lines)
            packed_weights = self.pack_weight_layer(layer.weight)
            weight_lines.extend(packed_weights)
            bias_lines.append(self.pack_bias_layer(layer.bias))

            layer_meta.append(
                {
                    "index": idx,
                    "in_features": layer.in_features,
                    "out_features": layer.out_features,
                    "padded_features": self.neurons,
                    "relu": layer.relu,
                    "shift": layer.shift,
                    "input_scale": layer.input_scale,
                    "weight_scale": layer.weight_scale,
                    "output_scale": layer.output_scale,
                    "bias_scale": layer.input_scale * layer.weight_scale,
                    "weight_offset": weight_offset,
                    "weight_columns": len(packed_weights),
                    "bias_line": idx,
                }
            )

        (out_path / "weights.hex").write_text("\n".join(weight_lines) + "\n")
        (out_path / "biases.hex").write_text("\n".join(bias_lines) + "\n")

        manifest: dict[str, object] = {
            "format": "accelotl-v0",
            "width": self.width,
            "out_width": self.out_width,
            "shift_width": self.shift_width,
            "neurons": self.neurons,
            "layers": len(quantized_layers),
            "stream_cycles": 2 * self.neurons - 1,
            "shifts": [layer.shift for layer in quantized_layers],
            "weights": "weights.hex",
            "biases": "biases.hex",
            "layers_meta": layer_meta,
        }

        (out_path / "model.json").write_text(json.dumps(manifest, indent=2) + "\n")
        return manifest
