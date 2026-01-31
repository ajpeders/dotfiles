#!/bin/bash

# Check for NVIDIA GPU
if command -v nvidia-smi &> /dev/null; then
    gpu_usage=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits)
    gpu_temp=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits)
    gpu_name=$(nvidia-smi --query-gpu=name --format=csv,noheader)
    echo "{\"text\":\"${gpu_usage}% ${gpu_temp}°C\",\"tooltip\":\"${gpu_name}\\nUsage: ${gpu_usage}%\\nTemperature: ${gpu_temp}°C\"}"
# Check for AMD GPU
elif command -v radeontop &> /dev/null; then
    echo '{"text":"GPU\nAMD","tooltip":"AMD GPU detected"}'
# Intel or no dedicated GPU
else
    echo '{"text":"","tooltip":"No dedicated GPU"}'
fi
