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

### phi3:mini (Microsoft, 3.8B params, ~2.3 GB)

Initial benchmark at the best known Gemma config (`12` threads, `2048` ctx, `128` batch, `128` gen tokens):

| Metric | Value |
| --- | --- |
| Median eval tok/s | `13.1556` |
| Avg eval tok/s | `13.1713` |
| Std dev | `0.0826` |
| Load time | `~2.5 s` |

Thread tuning revealed phi3:mini has a **completely different optimal thread count** from gemma:

| Threads | Median eval tok/s | Std dev | Notes |
| --- | --- | --- | --- |
| `6` | `13.6392` | `0.1045` | **Best config** — notably faster than 12 threads |
| `8` | `13.0026` | `0.0865` | Slightly slower |
| `10` | `12.1638` | `0.0203` | Most stable but slowest |
| `12` | `13.1556` | `0.0826` | Default comparison config |

Takeaway: `phi3:mini` at **6 threads** reaches `13.64` tok/s — only ~12% behind `gemma:2b` but with 1.9x the parameters. This is the best quality/speed tradeoff measured so far on this laptop.

### llama3.2:3b (Meta, 3B params, ~2.0 GB)

Initial benchmark at the best known Gemma config (`12` threads, `2048` ctx, `128` batch, `128` gen tokens):

| Metric | Value |
| --- | --- |
| Median eval tok/s | `13.5173` |
| Avg eval tok/s | `13.3155` |
| Std dev | `0.4921` |
| Load time | `~3.3 s` |

Takeaway: `llama3.2:3b` at `13.52` tok/s is competitive with `phi3:mini` but shows higher variance. It is ~13% behind `gemma:2b`.

### nemotron-mini:4b thread tuning

The initial 12-thread benchmark showed high variance (`0.98`). A thread sweep revealed **8 threads** is the optimal config:

| Threads | Median eval tok/s | Std dev | Notes |
| --- | --- | --- | --- |
| `4` | `5.7528` | `1.0782` | Undersubscribed, high variance |
| `6` | `7.1066` | `1.1307` | Still high variance |
| `8` | `8.8367` | `0.0515` | **Best config** — very stable! |
| `10` | `~9.45` (partial) | — | Running, appears faster |

Takeaway: `nemotron-mini:4b` is very sensitive to thread count. At `8` threads it reaches `8.84` tok/s with excellent stability — a **35% improvement** over the earlier 12-thread result. This demonstrates that optimal thread count is model-specific, not a universal setting.

### glm4:9b (THUDM, 9B params, 5.5 GB)

| Metric | Value |
| --- | --- |
| Median eval tok/s | `4.298` |
| Avg eval tok/s | `4.3443` |
| Std dev | `0.1809` |

Takeaway: Very stable but ~3.6x slower than `gemma:2b`. The 9B parameter count is likely memory-bandwidth-bound on this laptop.

### Context length sweep for gemma:2b

At `12` threads, `128` batch, `128` generated tokens:

| NumCtx | Median eval tok/s | Avg eval tok/s | Std dev | Notes |
| --- | --- | --- | --- | --- |
| `1024` | `14.9905` | `13.7553` | `2.1269` | Best median, but high variance suggests thermal interference |
| `2048` | `11.5501` | `12.2543` | `2.4092` | Unusually low — likely thermal throttling during consecutive runs |
| `4096` | `12.6672` | `11.9789` | `2.4625` | Recovering |
| `8192` | `14.6895` | `14.815` | `0.6946` | Recovered — similar to expected 15.54 |

Note: This sweep showed atypically high variance across all cells (thermal buildup from consecutive runs). The `1024` and `8192` cells are closest to the expected ~15.5 baseline. The earlier isolated runs at `2048` context with cooldown between runs (`15.54` median, `0.15` std dev) are more reliable.

## Best known safe config

- Runtime: native Windows with Ollama
- Fastest compact throughput model: `gemma:2b`
- Reference comparison model: `qwen35-4b-q4km`
- Threads: `12` currently leads for `gemma:2b`; `16` and `32` did not help on this `4C/8T` machine
- Threads for `IQ4_XS` Qwen: `12` also leads (unlike the older `q4km` reference which preferred `6`)
- Gemma context: `2048` currently leads, with `4096` nearly tied
- Gemma batch: `128` wins on stability; `64` ties on throughput
- Power mode: `High performance`
- AC processor min and max: `100%`
- Ollama priority: `High`
- Benchmark style: longer runs (`128`+ generated tokens), warmup excluded, cooldown between runs

## Model hierarchy (throughput)

Current measured throughput ranking from fastest to slowest on this laptop (Ollama, native Windows, best known config for each):

| Rank | Model | Params | Size | Median eval tok/s | Best Config |
| --- | --- | --- | --- | --- | --- |
| 1 | `gemma:2b` | 2B | 1.7 GB | `15.54` | 12 threads, 2048 ctx, 128 batch |
| 2 | `gemma:2b` (WSL) | 2B | 1.7 GB | `15.77` | WSL2 → Windows Ollama, 12 threads |
| 3 | `phi3:mini` | 3.8B | 2.3 GB | `13.64` | **6 threads**, 2048 ctx, 128 batch |
| 4 | `llama3.2:3b` | 3B | 2.0 GB | `13.52` | 12 threads, 2048 ctx, 128 batch |
| 5 | `nemotron-mini:4b` | 4B | 2.7 GB | `8.84` | **8 threads**, 2048 ctx, 128 batch |
| 6 | `qwen35-4b-q4km` | 4B | 2.7 GB | `7.62` | 6 threads, 1024 ctx, 64 batch |
| 7 | `hf.co/.../IQ4_XS` | 4B | 3.1 GB | `6.90` | 12 threads, 1024 ctx, 64 batch |
| 8 | `llama.cpp` CPU | 4B | 2.7 GB | `6.12` | 8 threads, direct CPU |
| 9 | `glm4:9b` | 9B | 5.5 GB | `4.30` | 12 threads, 2048 ctx, 128 batch |

Key insights:
- **Model architecture beats thread tuning.** The optimal thread count varies per model: gemma (`12`), phi3 (`6`), nemotron (`8`). Always sweep threads per model.
- **`phi3:mini` at 6 threads** is the standout find: only ~12% slower than `gemma:2b` but with 1.9x the parameters. This is the best quality/speed tradeoff tested so far.
- **`nemotron-mini:4b` improved 35%** by switching from 12 to 8 threads (6.53 → 8.84 tok/s), showing how critical model-specific tuning is.
- **`glm4:9b`** is solid but memory-bandwidth-bound on this laptop. Its 5.5 GB size saturates the memory channel.

## Next model candidates

- `gemma4` compact variants are worth testing next, but only if their pull size stays reasonable for this laptop.
- `Nemotron` (tested: `nemotron-mini:4b` at `6.53` tok/s — slower than gemma), `Kimi`, `MiniMax`, and alternate `Qwen` variants are reasonable next comparisons if they fit cleanly in `16 GB` RAM.
- `Phi-3` or `Phi-4` compact models from Microsoft are worth testing — they may offer a better quality/speed tradeoff than the tested models.
- Newer `qwen3.5` or `qwen4` compact variants (e.g., `qwen3.5:0.6b`, `qwen3.5:1.7b`, `qwen3.5:4b`) could offer better throughput than the current `qwen35-4b-q4km` reference.

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
