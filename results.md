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

Short Windows quant sweep for alternate `Qwen3.5-4B` Ollama / Hugging Face weights using the safe comparison harness at `6` threads, `1024` context, `64` batch, and `64` generated tokens:

| Model | Median eval tok/s | Avg eval tok/s | Std dev | Notes |
| --- | --- | --- | --- | --- |
| `hf.co/unsloth/Qwen3.5-4B-GGUF:IQ4_XS` | `6.12` | `6.12` | `0.60` | fastest tested Qwen weight in this short harness |
| `hf.co/unsloth/Qwen3.5-4B-GGUF:Q3_K_M` | `5.85` | `5.85` | `0.08` | slightly ahead of the current local reference |
| `qwen35-4b-q4km` | `5.76` | `5.76` | `0.03` | current local reference in the same harness |

Takeaway:

- `IQ4_XS` is the best Qwen throughput candidate tested so far for this laptop if the goal is raw decode speed
- `Q3_K_M` was not meaningfully better than the current `q4km` reference here
- a longer `IQ4_XS` confirmation at the same `6/1024/64` setting but with `128` generated tokens produced measured runs of `6.3157`, `6.0242`, and `6.7633` tok/s, for a corrected median of `6.3157` and average of `6.3677`
- these values come from the newer short safe comparison harness and should be read as same-cell relative comparisons, not replacements for the earlier longer validated `7.62` native Windows Qwen reference sweep cell

Thread-only follow-up sweep for `hf.co/unsloth/Qwen3.5-4B-GGUF:IQ4_XS` at `1024` context, `64` batch, and `128` generated tokens:

| Threads | Median eval tok/s | Avg eval tok/s | Std dev | Variance % | Notes |
| --- | --- | --- | --- | --- | --- |
| `12` | `6.9006` | `6.9006` | `0.0084` | `0.12` | current best tested `IQ4_XS` thread setting |
| `6` | `6.5437` | `6.5437` | `0.1207` | `1.84` | prior baseline thread count still competitive |
| `10` | `6.5103` | `6.5103` | `0.3363` | `5.17` | higher variance, less attractive |
| `8` | `6.4138` | `6.4138` | `0.0282` | `0.44` | very stable, but slower |

Takeaway:

- unlike the earlier `qwen35-4b-q4km` baseline, `IQ4_XS` clearly prefers `12` threads on this laptop in the tested `1024/64/128` cell
- this is the best Qwen-specific thread tuning result measured so far in the current repo session

Short safe Gemma comparison using the newer harness and longer `64` token decode runs:

| Model | Threads | NumCtx | NumBatch | Median eval tok/s | Avg eval tok/s | Std dev | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `gemma:2b` | `6` | `2048` | `128` | `14.05` | `14.05` | `0.97` | short two-run sample, more variance |
| `gemma:2b` | `8` | `2048` | `128` | `14.78` | `14.78` | `0.03` | very stable short sample |
| `gemma:2b` | `10` | `2048` | `128` | `15.35` | `15.35` | `0.29` | first strong Gemma result |
| `gemma:2b` | `12` | `1024` | `128` | `15.48` | `15.48` | `0.30` | slightly behind the best ctx setting |
| `gemma:2b` | `12` | `2048` | `128` | `16.00` | `16.00` | `0.58` | best short Gemma result so far |
| `gemma:2b` | `12` | `4096` | `128` | `15.93` | `15.93` | `0.06` | nearly tied with `2048` and very stable |
| `gemma:2b` | `16` | `1024` | `128` | `15.53` | `15.53` | `0.58` | best short `16`-thread context result |
| `gemma:2b` | `16` | `2048` | `128` | `14.29` | `14.29` | `0.48` | regression versus `12` threads |
| `gemma:2b` | `16` | `4096` | `128` | `14.88` | `14.88` | `1.14` | higher variance and slower overall |
| `gemma:2b` | `32` | `2048` | `128` | `12.99` | `12.99` | `0.08` | stable, but clearly slower from heavy oversubscription |

Longer confirmation run on the `16`-thread path:

| Model | Threads | NumCtx | NumBatch | NumPredict | Median eval tok/s | Avg eval tok/s | Std dev | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `gemma:2b` | `16` | `1024` | `128` | `128` | `15.12` | `14.87` | `0.19` | longer decode run; still behind the best `12`-thread short sample |

Takeaway:

- `gemma:2b` is the fastest compact model measured so far on this laptop.
- On Gemma, `12` threads slightly beat both `10` and `8`, which is a different pattern from the direct `llama.cpp` Qwen CPU run.
- Pushing further to `16` or `32` threads does not improve throughput on this `4C/8T` Ryzen laptop.
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
- current Windows-hosted Ollama endpoint is **not** reachable from WSL by default

Controlled bridge result:

| Runtime | Model | Threads | NumCtx | NumBatch | NumPredict | Median eval tok/s | Avg eval tok/s | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `WSL2 -> Windows Ollama` | `gemma:2b` | `12` | `2048` | `128` | `64` | `15.77` | `15.77` | uses explicit endpoint `http://172.26.208.1:11434` with the controlled WSL bridge enabled |
| `WSL2 -> Windows Ollama` | `gemma:2b` | `16` | `2048` | `128` | `64` | `14.98` | `14.98` | higher threads regressed, matching native Windows behavior |
| `WSL2 -> Windows Ollama` | `gemma:2b` | `32` | `2048` | `128` | `64` | `12.75` | `12.75` | heavy oversubscription is clearly slower |
| `WSL2 -> Windows Ollama` | `qwen35-4b-q4km` | `6` | `1024` | `64` | `64` | `5.33` | `5.33` | same shape as the current best validated native Windows Qwen sweep cell |

Conclusion:

- the repo now has a first valid WSL-vs-Windows comparison point for `gemma:2b`
- the best `WSL2 -> Windows Ollama` result is very close to the native Windows short-sample Gemma result of about `16.00` eval tok/s
- WSL oversubscription follows the same pattern as native Windows here: `12` threads beats `16`, and `32` is much worse
- `qwen35-4b-q4km` is materially slower through this WSL path than on native Windows at the current best-tested `6/1024/64` setting
- the Windows-hosted endpoint still needs the controlled bridge workflow or an explicit reachable endpoint; it is not reachable from WSL by default

## Gemma batch sweep

Focused batch sweep for `gemma:2b` at `12` threads, `2048` context, and `128` generated tokens:

| Batch | Median eval tok/s | Avg eval tok/s | Std dev | Variance % |
| --- | --- | --- | --- | --- |
| `64` | `15.5441` | `15.7402` | `0.4506` | `2.90` |
| `128` | `15.5418` | `15.6316` | `0.1466` | `0.94` |
| `256` | `15.258` | `15.364` | `0.6412` | `4.20` |
| `512` | `15.2384` | `15.3373` | `0.2722` | `1.79` |

Takeaway: batch `64` and `128` are tied on throughput, but **`128` wins decisively on stability** (lowest std dev). The earlier short-sample best of `~16.00` was a single outlier; the reproducible median across 3 measured runs is `~15.54`.

## New model sweep

Initial benchmarks for additional local models at the best known Gemma hyperparameters (`12` threads, `2048` ctx, `128` batch, `128` generated tokens):

| Model | Median eval tok/s | Avg eval tok/s | Std dev | Notes |
| --- | --- | --- | --- | --- |
| `nemotron-mini:4b` | `6.529` | `6.7978` | `0.9782` | 4B NVIDIA, high variance, ~2.5x slower than gemma:2b |
| `glm4:9b` | `4.298` | `4.3443` | `0.1809` | 9B THUDM, very stable but slow, ~3.6x slower than gemma:2b |

Takeaway: Neither model beats the existing `gemma:2b` compact throughput winner. `gemma:2b` remains the fastest model measured on this laptop by a wide margin.

## Best known safe config

- Runtime: native Windows with Ollama
- Fastest compact throughput model: `gemma:2b`
- Reference comparison model: `qwen35-4b-q4km`
- Threads: `12` currently leads for `gemma:2b`; `16` and `32` did not help on this `4C/8T` machine
- Gemma context: `2048` currently leads, with `4096` nearly tied
- Gemma batch: `128` wins on stability; `64` ties on throughput
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
- WSL connectivity to the Windows Ollama API is not working by default on this machine; the first valid comparison required the controlled bridge workflow and explicit endpoint `http://172.26.208.1:11434`.
- Vulkan backend/device discovery is not working yet in the current Windows environment.
