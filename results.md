# Results

## Machine

- CPU: `AMD Ryzen 3 5300U`
- RAM: `16 GB`
- GPU: integrated `AMD Radeon Graphics`
- Windows version: `Windows 11 Home Single Language 10.0.26200`
- Ollama version: `0.30.11`
- Power mode: `High performance` for current tuned runs
- AC plugged in: `Yes`
- Model: `qwen35-4b-q4km`

## Stable baseline

Short earlier baseline with `32` generated tokens:

| Scenario | Threads | Prompt tok/s | Gen tok/s | Load seconds | Total seconds |
| --- | --- | --- | --- | --- | --- |
| Vanilla Windows baseline | `default` | `12.89` | `5.21` | `7.78` | `16.55` |

## Max-performance profile

Safe tuning so far:

- switched from `Balanced` to `High performance`
- set AC processor min and max to `100%`
- preferred active cooling when available
- raised `ollama.exe` priority to `High`
- stopped background model pulls before benchmarking

Short tuned check with `16` generated tokens:

| Scenario | Threads | Prompt tok/s | Gen tok/s | Load seconds | Total seconds |
| --- | --- | --- | --- | --- | --- |
| Tuned Windows session | `8` | `19.79` | `6.76` | `7.85` | `11.54` |

## Thread sweep

| Threads | Prompt tok/s | Gen tok/s | Load seconds | Total seconds | Notes |
| --- | --- | --- | --- | --- | --- |
| `4` | `15.31` | `5.56` | `7.83` | `15.79` | earlier baseline sweep |
| `6` | `17.48` | `5.99` | `7.52` | `11.68` | tuned short polite run |
| `7` | `18.83` | `6.54` | `7.03` | `10.86` | tuned short polite run |
| `8` | `23.24` | `6.86` | `7.19` | `13.36` | best short baseline sweep |
| `8` | `20.73` | `6.87` | `7.00` | `10.59` | best tuned short polite run |

## Context length sweep

Pending. Use `.\compare-context-length.ps1` and log timestamped outputs from `results-local`.

## Batch sweep

Pending. Use `.\sweep-ollama-options-safe.ps1` and capture the top median and stability-adjusted configs here.

## Model / quant comparison

Short direct comparison on this laptop:

| Model | Prompt tok/s | Gen tok/s | Load seconds | Total seconds | Notes |
| --- | --- | --- | --- | --- | --- |
| `qwen35-4b-q4km:latest` | `18.45` | `6.81` | `8.47` | `12.23` | current best local choice |
| `qwen35-4b-udiq2m:latest` | `7.16` | `4.88` | `5.22` | `12.03` | smaller quant was slower here |

## Best known safe config

- Runtime: native Windows with Ollama
- Model: `qwen35-4b-q4km`
- Threads: `8`
- Power mode: `High performance`
- AC processor min and max: `100%`
- Ollama priority: `High`
- Benchmark style: longer runs, warmup excluded, cooldown between runs

## Risky / not recommended

- Realtime process priority
- battery-only benchmarking
- thermal-protection bypasses
- BIOS tweaks and fan-control hacks
- claiming wins from tiny `16` token micro-tests alone

## Reboot / instability notes

- Larger model experiments on this laptop were not practical.
- Background Ollama pulls can interfere with measurements and leave partial blobs behind.
- Safe session tuning improved load time and benchmark hygiene more than raw generation throughput.
