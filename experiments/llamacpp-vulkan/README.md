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
powershell -ExecutionPolicy Bypass -File .\experiments\llamacpp-vulkan\run-llama-bench-cpu.ps1 -LlamaBenchPath C:\path\to\llama-bench.exe -ModelPath C:\path\to\model.gguf -Threads 8 -PromptTokens 512 -GenerateTokens 128 -BatchSize 128 -Repetitions 3
```

Vulkan experiment:

```powershell
powershell -ExecutionPolicy Bypass -File .\experiments\llamacpp-vulkan\run-llama-bench-vulkan.ps1 -LlamaBenchPath C:\path\to\llama-bench.exe -ModelPath C:\path\to\model.gguf -Threads 8 -PromptTokens 512 -GenerateTokens 128 -BatchSize 128 -Repetitions 3 -GpuLayers 999
```

Both scripts request JSON output from `llama-bench` and also save a raw log so you can diff CPU and Vulkan runs later.

Compare the logged tokens-per-second numbers against the safe Ollama baseline in [results.md](../../results.md), then use [compare-runtime-results.ps1](../../compare-runtime-results.ps1) for Windows vs WSL CSV comparisons.

## Findings so far on this laptop

- Direct `llama.cpp` CPU at `8` threads measured about `6.12` gen tok/s on `qwen35-4b-q4km.gguf`.
- Direct `llama.cpp` CPU at `10` threads measured about `5.47` gen tok/s, so oversubscribing this `4C/8T` CPU hurt generation throughput.
- Prompt processing improved at `10` threads, but generation throughput is the more important metric for chat-style local inference.
- `llama-bench --list-devices` currently reports `Available devices: (none)` here, so Vulkan is not benchmark-ready yet.
