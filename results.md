# Results

## Machine

- CPU: `AMD Ryzen 3 5300U`
- RAM: `16 GB`
- GPU: integrated `AMD Radeon Graphics`
- Windows version: `Windows 11 Home Single Language 10.0.26200`
- Ollama version: `0.30.11`
- Power mode: `High performance` for current tuned runs
- AC plugged in: `Yes`
- Current reference model: `qwen35-4b-q4km`

## Stable baseline

Short earlier baseline with `32` generated tokens on the current reference model:

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

Short tuned check with `16` generated tokens on the current reference model:

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

Current best validated safe sweep cell:

| Threads | NumCtx | NumBatch | Median eval tok/s | Notes |
| --- | --- | --- | --- | --- |
| `6` | `1024` | `64` | `7.62` | best validated safe sweep cell so far |

This is stronger than the earlier short single-run checks and is the best measured generation result currently documented in this repo.

## Model / quant comparison

Short direct comparison on this laptop for the current `Qwen3.5-4B` reference family:

| Model | Prompt tok/s | Gen tok/s | Load seconds | Total seconds | Notes |
| --- | --- | --- | --- | --- | --- |
| `qwen35-4b-q4km:latest` | `18.45` | `6.81` | `8.47` | `12.23` | current best local choice |
| `qwen35-4b-udiq2m:latest` | `7.16` | `4.88` | `5.22` | `12.03` | smaller quant was slower here |

Short safe Gemma comparison using the newer harness and longer `64` token decode runs:

| Model | Threads | NumCtx | NumBatch | Median eval tok/s | Avg eval tok/s | Std dev | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `gemma:2b` | `6` | `2048` | `128` | `14.05` | `14.05` | `0.97` | short two-run sample, more variance |
| `gemma:2b` | `8` | `2048` | `128` | `14.78` | `14.78` | `0.03` | very stable short sample |
| `gemma:2b` | `10` | `2048` | `128` | `15.35` | `15.35` | `0.29` | first strong Gemma result |
| `gemma:2b` | `12` | `1024` | `128` | `15.48` | `15.48` | `0.30` | slightly behind the best ctx setting |
| `gemma:2b` | `12` | `2048` | `128` | `16.00` | `16.00` | `0.58` | best short Gemma result so far |
| `gemma:2b` | `12` | `4096` | `128` | `15.93` | `15.93` | `0.06` | nearly tied with `2048` and very stable |

Takeaway:

- `gemma:2b` is the fastest compact model measured so far on this laptop.
- On Gemma, `12` threads slightly beat both `10` and `8`, which is a different pattern from the direct `llama.cpp` Qwen CPU run.
- For this laptop, `num_ctx=2048` is the current best Gemma setting, while `4096` is close enough that it may be the safer default when a larger window is useful.
- This is a throughput finding only; it does not mean `gemma:2b` is the best overall quality model.

## llama.cpp direct benchmark

Direct `llama-bench` CPU results on `qwen35-4b-q4km.gguf`:

| Runtime | Threads | Prompt tokens | Gen tokens | Prompt tok/s | Gen tok/s | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| `llama.cpp` CPU | `8` | `512` | `128` | `19.30` | `6.12` | first direct CPU baseline |
| `llama.cpp` CPU | `10` | `512` | `128` | `23.49` | `5.47` | oversubscribed threads improved prefill but hurt generation |

Takeaway:

- `8` threads beat `10` threads for generation on this `4C/8T` Ryzen laptop.
- Direct `llama.cpp` CPU is currently a little behind the better Ollama runs on this machine.

## Vulkan status

Current status on this laptop:

- official `llama.cpp` Windows Vulkan build installed successfully
- `llama-bench --list-devices` reported `Available devices: (none)`
- no usable Vulkan device/backend is exposed to `llama-bench` yet on this Windows install

Conclusion:

- Vulkan is not benchmark-ready yet here
- fixing GPU/backend visibility is required before claiming anything about Vulkan speedups

## WSL comparison

Current status on this laptop:

- `WSL2` is installed and healthy
- default distro is `Ubuntu-24.04`
- Python and curl are available inside WSL
- current Windows-hosted Ollama endpoint is **not** reachable from WSL with the present setup

Conclusion:

- we do not yet have a valid WSL-vs-Windows throughput comparison
- to continue, either expose a reachable Ollama endpoint to WSL or run Ollama inside WSL

## Best known safe config

- Runtime: native Windows with Ollama
- Fastest compact throughput model: `gemma:2b`
- Reference comparison model: `qwen35-4b-q4km`
- Threads: `12` currently leads for `gemma:2b` in the short safe sample, while `6-8` remains the better tested range for `qwen35-4b-q4km`
- Gemma context: `2048` currently leads, with `4096` nearly tied
- Power mode: `High performance`
- AC processor min and max: `100%`
- Ollama priority: `High`
- Benchmark style: longer runs, warmup excluded, cooldown between runs

## Next model candidates

- `gemma4` compact variants are worth testing next, but only if their pull size stays reasonable for this laptop.
- compact `Nemotron`, `Kimi`, `MiniMax`, and alternate `Qwen` variants are reasonable next comparisons if they fit cleanly in `16 GB` RAM.

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
- Oversubscribing the CPU to `10` threads in direct `llama.cpp` reduced generation tok/s.
- WSL connectivity to the Windows Ollama API is not working by default on this machine.
- Vulkan backend/device discovery is not working yet in the current Windows environment.
