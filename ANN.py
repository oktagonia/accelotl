import subprocess
import json
import numpy as np
import torch.nn as nn

def _calculate_scale_factor(weights, bias):
    max_val = max(np.abs(weights).max(), np.abs(bias).max())
    scale = max_val / 127.0
    scale_pow2 = 2 ** np.ceil(np.log2(scale))
    return scale_pow2

def _float_to_int8(x, scale):
    scaled = np.round(x / scale)
    return np.clip(scaled, -128, 127).astype(np.int8)

def _quantize_model(model):
    quantized_layers = []
    
    for layer in model:
        if isinstance(layer, nn.Linear):
            continue
    
        weights = layer.weight.detach().numpy()
        bias = layer.bias.detach().numpy()
        
        scale = _calculate_scale_factor(weights, bias)
        augmented_weights = np.column_stack([bias, weights])
        
        quantized_layers.append({
            'weights': _float_to_int8(augmented_weights, scale).tolist(),
            'scale': scale
        })
    
    return quantized_layers

class ANN:
    def __init__(self, model, sim_exe='./build/matmul_tb'):
        self.quantized_layers = _quantize_model(model)
        
        self.sim = subprocess.Popen(
            [sim_exe],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            text=True
        )
    
    def predict(self, input_vector):
        x = np.concatenate([[1], input_vector])
        pass
    
    def close(self):
        self.sim.terminate()