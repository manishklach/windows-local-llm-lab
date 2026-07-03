# Qwen Windows TPS Lab

Small repo for running a local `Qwen3.5-4B` benchmark on a standard Windows laptop, measuring prompt and generation throughput with Ollama, and tracking tuning experiments over time.

## Goal

Build a simple, repeatable local inference setup first, then try practical optimizations on:

- native Windows
- quant choice
- thread count
- prompt length
- generation length
- later, WSL comparison

## Machine Used For Initial Results

- CPU: `AMD Ryzen 3 5300U`
- Cores / threads: `4 / 8`
- RAM: `16 GB`
- GPU: integrated `AMD Radeon Graphics`
- OS: Windows
- Runtime: `Ollama 0.30.11`

## Model Used

- Family: `Qwen3.5-4B`
- Quant: `Q4_K_M`
- Local Ollama model name: `qwen35-4b-q4km`

The `.gguf` file is intentionally not committed.

## Local Setup

1. Put the GGUF file in the repo root as:

```text
qwen35-4b-q4km.gguf
```

2. Create the local Ollama model:

```powershell
ollama create qwen35-4b-q4km -f .\Modelfile.qwen35-4b-q4km
```

3. Run the benchmark:

```powershell
powershell -ExecutionPolicy Bypass -File .\measure-ollama-tps.ps1 -Model qwen35-4b-q4km -Runs 3 -NumPredict 32
```

## First Results

See [results.md](./results.md) for the baseline and first tuning pass.

## Next Experiments

- compare `Q4_K_M` vs `Q3_K_M`
- sweep `num_thread`
- test longer prompts and longer generations
- compare native Windows vs WSL
- try alternative runtimes like `llama.cpp`
