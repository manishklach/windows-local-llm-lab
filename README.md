# Qwen Windows TPS Lab

Safe, reversible Windows laptop benchmarking for local LLM throughput with Ollama.

The stable baseline in this repo is native Windows plus Ollama. The goal is to improve tokens-per-second with repeatable measurements, not random tweaks.

## Repo contents

- safe preflight, tuning, and restore scripts under `tools/`
- safe Ollama benchmark wrappers in the repo root
- experiment scaffolding for `llama.cpp` Vulkan under `experiments/`
- results and methodology docs for tracking what actually helps

## Machine used so far

- CPU: `AMD Ryzen 3 5300U`
- Cores / threads: `4 / 8`
- RAM: `16 GB`
- GPU: integrated `AMD Radeon Graphics`
- Windows: `11`
- Ollama: `0.30.11`

## Model setup

1. Put the GGUF in the repo root as `qwen35-4b-q4km.gguf`.
2. Create the local Ollama model:

```powershell
ollama create qwen35-4b-q4km -f .\Modelfile.qwen35-4b-q4km
```

## Safe max-performance workflow

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\preflight-llm-benchmark.ps1 -RequireAC -Model qwen35-4b-q4km

powershell -ExecutionPolicy Bypass -File .\tools\enter-max-perf-mode.ps1 -UseUltimatePerformance -StopPulls -NoSleep -OllamaPriority High

powershell -ExecutionPolicy Bypass -File .\measure-ollama-tps-safe.ps1 -Model qwen35-4b-q4km -Runs 5 -WarmupRuns 1 -NumPredict 128 -NumThread 8 -NumCtx 2048

powershell -ExecutionPolicy Bypass -File .\sweep-ollama-options-safe.ps1 -Model qwen35-4b-q4km -ThreadCounts 6,7,8 -NumCtxValues 1024,2048,4096 -NumBatchValues 64,128,256 -NumPredict 128

powershell -ExecutionPolicy Bypass -File .\tools\exit-max-perf-mode.ps1 -DeleteStateAfterRestore
```

## Extra comparisons

Context length:

```powershell
powershell -ExecutionPolicy Bypass -File .\compare-context-length.ps1 -Model qwen35-4b-q4km -NumThread 8 -NumCtxValues 1024,2048,4096,8192 -NumPredict 128 -Runs 3
```

Model or quant comparison:

```powershell
powershell -ExecutionPolicy Bypass -File .\compare-models-safe.ps1 -Models qwen35-4b-q4km,qwen35-4b-udiq2m -NumThread 8 -NumCtx 2048 -NumPredict 128 -Runs 3
```

Thermal watch:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\watch-llm-thermals.ps1 -IntervalSeconds 5 -LogPath .\results-local\thermals.csv
```

## Safety rules

- Do not use Realtime priority.
- Do not disable thermal protections.
- Do not benchmark on battery.
- Keep the laptop plugged in.
- Put the laptop on a hard surface.
- Stop if the machine reboots repeatedly.
- Prefer `128` or `256` generated tokens for real measurements.
- Use short `16` or `32` token runs only for smoke checks.

More detail lives in [docs/safety.md](./docs/safety.md) and [docs/benchmark-methodology.md](./docs/benchmark-methodology.md).

## Existing compatibility scripts

The original scripts are still present for compatibility:

- `measure-ollama-tps.ps1`
- `sweep-ollama-options.ps1`
- `compare-ollama-models.ps1`
- `apply-llm-session-tuning.ps1`
- `restore-llm-session-tuning.ps1`

For new work, prefer the `*-safe.ps1` and `tools\*.ps1` workflow.
