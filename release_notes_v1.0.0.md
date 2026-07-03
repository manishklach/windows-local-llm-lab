# windows-local-llm-lab v1.0.0

First public release of the Windows local LLM throughput lab.

This release turns the repo into a reproducible, safety-first benchmarking harness for local model throughput on a standard Windows laptop, with current measurements across Qwen and Gemma variants plus experimental runtime scaffolding for WSL and `llama.cpp`.

## Highlights

- Added reversible Windows max-performance session controls under `tools/`
- Added safe preflight checks before benchmarking
- Added structured Ollama benchmark wrappers with warmups, cooldowns, CSV, JSONL, and Markdown summaries
- Added context-length, model-comparison, and option-sweep scripts
- Added experimental scaffolding for `llama.cpp` CPU and Vulkan benchmarking
- Generalized the repo from a Qwen-only lab to a multi-model Windows local inference lab
- Published first measured Gemma throughput findings on this Ryzen laptop

## Key benchmark findings so far

### Stable reference model

`qwen35-4b-q4km` remains the quality-oriented reference model in this repo.

- best validated safe Ollama sweep cell so far: about `7.62` median eval tok/s
- winning tested cell for that result: `6` threads, `1024` context, `64` batch

### Fastest compact model measured so far

`gemma:2b` is the current compact throughput leader on this machine.

- best short safe result: about `16.00` median eval tok/s
- winning tested cell for that result: `12` threads, `2048` context, `128` batch, `64` generated tokens

### High-thread findings

Oversubscription helps to a point, then clearly stops helping on this `4C/8T` Ryzen 3 5300U.

- `8` threads on `gemma:2b`: about `14.78` median eval tok/s
- `10` threads on `gemma:2b`: about `15.35`
- `12` threads on `gemma:2b`: about `16.00`
- `16` threads on `gemma:2b`, best short sample: about `15.53`
- `32` threads on `gemma:2b`: about `12.99`

Longer confirmation run:

- `gemma:2b`, `16` threads, `1024` context, `128` generated tokens: about `15.12` median eval tok/s

Conclusion:

- `12` threads is the current sweet spot for `gemma:2b` on this laptop
- `16` and `32` threads do not improve throughput overall

### Context findings for Gemma

At `12` threads:

- `1024` context: about `15.48` median eval tok/s
- `2048` context: about `16.00`
- `4096` context: about `15.93`

Conclusion:

- `2048` is the current best tested Gemma setting
- `4096` is close enough to be a practical larger-window default when needed

## Runtime findings

### Native Windows + Ollama

Still the best proven safe runtime path on this laptop.

### `llama.cpp` CPU

Direct CPU benchmarking worked, but did not beat the better Ollama numbers on this machine.

- `8` threads: about `6.12` generation tok/s
- `10` threads: about `5.47` generation tok/s

### Vulkan

Not benchmark-ready yet on this Windows install.

- `llama-bench --list-devices` returned no usable device
- Vulkan driver visibility remains broken on this machine

### WSL

WSL itself is healthy, but the current Windows-hosted Ollama endpoint is not yet reachable from WSL with the present setup, so no valid Windows-vs-WSL throughput comparison is published yet.

## Safety model

This repo is intentionally conservative.

Allowed:

- Ultimate / High Performance power mode
- AC-only CPU min/max `100%`
- active cooling preference
- `ollama.exe` at `High` priority
- no-sleep while plugged in
- warmup exclusion and cooldowns between runs

Not recommended:

- Realtime priority
- BIOS tweaks
- undervolting
- fan-control hacks
- registry hacks
- thermal-protection bypasses
- globally disabling Windows Defender

## Quick Windows tuning ideas to try next

These are the next safe, fast experiments most likely to help without making the laptop unstable:

1. Run the longer confirmation on the actual winner, not just the candidate.
   Test `gemma:2b` at `12` threads with `128` generated tokens for both `2048` and `4096` context.

2. Sweep `num_batch` around the current winner.
   The next likely win is a focused batch sweep at `12` threads and `2048` context using `64`, `128`, and `256`.

3. Keep the model hot between runs when comparing decode throughput.
   Reload cost can hide decode behavior; using longer runs and measuring `eval_duration` is more meaningful than focusing on one short end-to-end wall-clock sample.

4. Reduce background Windows noise before benchmarking.
   Pause cloud sync, browsers with many tabs, Windows Update activity, indexing-heavy jobs, and any active model pulls.

5. Consider targeted Defender exclusions only if load time is the bottleneck.
   This is more likely to help model load and file scanning than decode tok/s. Do not disable Defender globally.

6. Keep using the stable performance envelope already proven here.
   AC power, hard surface, High or Ultimate Performance, `ollama.exe` at `High` priority, and cooldown between runs.

## Notes on utilization

Observed desktop utilization such as `71%` CPU and `60%` RAM does not automatically mean there is easy remaining throughput headroom.

- decode work often arrives in bursts, so Task Manager can understate short-lived saturation
- the thermal watcher repeatedly observed `95%` to `100%` CPU during active runs
- memory pressure was usually acceptable, so this laptop currently looks more CPU-limited than RAM-limited for these compact models

## Repo content added or hardened in this release

- `tools/enter-max-perf-mode.ps1`
- `tools/exit-max-perf-mode.ps1`
- `tools/preflight-llm-benchmark.ps1`
- `tools/watch-llm-thermals.ps1`
- `measure-ollama-tps-safe.ps1`
- `sweep-ollama-options-safe.ps1`
- `compare-context-length.ps1`
- `compare-models-safe.ps1`
- `compare-runtime-results.ps1`
- `experiments/llamacpp-vulkan/*`
- `experiments/wsl/*`
- `docs/safety.md`
- `docs/benchmark-methodology.md`

## Recommended next step

If the goal is a real chance at another gain on this laptop, the best next measurement is:

`gemma:2b` with `12` threads, `128` generated tokens, and a focused sweep over `2048` and `4096` context plus `64/128/256` batch.
