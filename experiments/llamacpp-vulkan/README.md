# llama.cpp Vulkan Experiment

This folder is intentionally experimental.

The stable baseline for this repo is still Ollama running on the CPU path under Windows. Keep using the Ollama scripts in the repo root for day-to-day measurement unless `llama.cpp` Vulkan clearly proves better on your machine.

## Why this is separate

- `llama.cpp` Vulkan can help on some GPUs, but AMD iGPU laptops are highly driver-dependent.
- The Vulkan path can be less stable than the Ollama CPU baseline.
- A good benchmark here is useful only if it beats the stable Ollama numbers with repeatable runs.

## Guardrails

- Do not replace the Ollama baseline until measured numbers prove it is faster.
- Do not auto-download binaries or models from these scripts.
- Keep Windows display drivers current only through normal AMD or laptop-vendor update channels.

## Usage

CPU reference run:

```powershell
powershell -ExecutionPolicy Bypass -File .\experiments\llamacpp-vulkan\run-llama-bench-cpu.ps1 -LlamaBenchPath C:\path\to\llama-bench.exe -ModelPath C:\path\to\model.gguf
```

Vulkan experiment:

```powershell
powershell -ExecutionPolicy Bypass -File .\experiments\llamacpp-vulkan\run-llama-bench-vulkan.ps1 -LlamaBenchPath C:\path\to\llama-bench.exe -ModelPath C:\path\to\model.gguf
```

Compare the logged tokens-per-second numbers against the safe Ollama baseline in [results.md](../../results.md).
