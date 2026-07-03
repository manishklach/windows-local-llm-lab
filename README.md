# Windows Local LLM Lab

Safe, reversible Windows laptop benchmarking for local LLM throughput across multiple local models and runtimes.

The stable baseline in this repo is native Windows plus Ollama. The goal is to improve tokens-per-second with repeatable measurements, not random tweaks.

## Current conclusion

On this laptop, the fastest proven safe runtime path is still `native Windows + Ollama`.

- best validated safe Ollama sweep cell so far: about `7.62` median eval tok/s at `6` threads, `1024` context, `64` batch
- fastest compact model measured so far: `gemma:2b` at about `15.54` median eval tok/s with `12` threads, `2048` context, `128` batch, and `128` generated tokens (batch `128` is the stability winner; batch `64` ties on throughput)
- `nemotron-mini:4b` reached about `6.53` median eval tok/s at the same hyperparameters (high variance)
- `glm4:9b` reached about `4.30` median eval tok/s at the same hyperparameters (very stable but slower)
- direct `llama.cpp` CPU at `8` threads reached about `6.12` gen tok/s
- direct `llama.cpp` CPU at `10` threads dropped to about `5.47` gen tok/s
- WSL now has a first valid comparison path through the controlled bridge experiment, with `gemma:2b` reaching about `15.77` median eval tok/s at `12` threads
- Vulkan is not ready yet because `llama-bench` currently sees no available device on this Windows setup

## Repo contents

- safe preflight, tuning, and restore scripts under `tools/`
- safe Ollama benchmark wrappers in the repo root
- experiment scaffolding for `llama.cpp` Vulkan under `experiments/`
- WSL comparison helpers for Linux-first runtime experiments
- results and methodology docs for tracking what actually helps

## Current model coverage

- current quality-oriented reference model: `qwen35-4b-q4km`
- fastest compact model measured so far: `gemma:2b`
- additional tested quants: `qwen35-4b-udiq2m`
- additional tested models: `nemotron-mini:4b`, `glm4:9b`
- additional tested models: `nemotron-mini:4b` (`6.53` tok/s — 2.4x slower than gemma), `glm4:9b` (`4.30` tok/s — 3.6x slower)
- next logical model candidates for this laptop: newer small `Gemma` variants (`gemma2`, `gemma4` compact), `Phi` series (`phi3`, `phi4`), compact `Qwen3.5` variants, and any new `Nemotron` or `MiniMax` releases that fit in `16 GB` RAM

## Machine used so far

- CPU: `AMD Ryzen 3 5300U`
- Cores / threads: `4 / 8`
- RAM: `16 GB`
- GPU: integrated `AMD Radeon Graphics`
- Windows: `11`
- Ollama: `0.30.11`

## Quick start for another Windows user

If you just want to download this repo and run a benchmark on your own Windows laptop, use this path.

1. Clone the repo:

```powershell
git clone https://github.com/manishklach/windows-local-llm-lab.git
cd windows-local-llm-lab
```

2. Install Ollama for Windows if you do not already have it:

- download from [ollama.com/download/windows](https://ollama.com/download/windows)
- after install, confirm it works:

```powershell
ollama --version
```

3. Pull a public test model.

Fastest simple starter:

```powershell
ollama pull gemma:2b
```

Qwen throughput candidate tested in this repo:

```powershell
ollama pull hf.co/unsloth/Qwen3.5-4B-GGUF:IQ4_XS
```

4. Run the preflight safety and readiness check:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\preflight-llm-benchmark.ps1 -RequireAC -Model gemma:2b
```

5. Enter the reversible max-performance benchmark mode:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\enter-max-perf-mode.ps1 -UseUltimatePerformance -StopPulls -NoSleep -OllamaPriority High
```

6. Run one direct benchmark:

For `gemma:2b`:

```powershell
powershell -ExecutionPolicy Bypass -File .\measure-ollama-tps-safe.ps1 -Model gemma:2b -Runs 3 -WarmupRuns 1 -NumPredict 64 -NumThread 12 -NumCtx 2048 -NumBatch 128
```

For the tested `IQ4_XS` Qwen path:

```powershell
powershell -ExecutionPolicy Bypass -File .\measure-ollama-tps-safe.ps1 -Model hf.co/unsloth/Qwen3.5-4B-GGUF:IQ4_XS -Runs 3 -WarmupRuns 1 -NumPredict 128 -NumThread 12 -NumCtx 1024 -NumBatch 64
```

7. Restore normal desktop settings when you are done:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\exit-max-perf-mode.ps1 -DeleteStateAfterRestore
```

Results are written under `results-local\` as:

- `.csv` for spreadsheet analysis
- `.jsonl` for machine-readable records
- `-summary.md` for the quick human-readable result

## Reproducible benchmark recipes

Use these if you want a quick apples-to-apples comparison against the main tested paths in this repo.

`gemma:2b` compact throughput recipe:

```powershell
ollama pull gemma:2b
powershell -ExecutionPolicy Bypass -File .\tools\preflight-llm-benchmark.ps1 -RequireAC -Model gemma:2b
powershell -ExecutionPolicy Bypass -File .\measure-ollama-tps-safe.ps1 -Model gemma:2b -Runs 3 -WarmupRuns 1 -NumPredict 64 -NumThread 12 -NumCtx 2048 -NumBatch 128
```

`Qwen3.5-4B IQ4_XS` throughput recipe:

```powershell
ollama pull hf.co/unsloth/Qwen3.5-4B-GGUF:IQ4_XS
powershell -ExecutionPolicy Bypass -File .\tools\preflight-llm-benchmark.ps1 -RequireAC -Model hf.co/unsloth/Qwen3.5-4B-GGUF:IQ4_XS
powershell -ExecutionPolicy Bypass -File .\measure-ollama-tps-safe.ps1 -Model hf.co/unsloth/Qwen3.5-4B-GGUF:IQ4_XS -Runs 3 -WarmupRuns 1 -NumPredict 128 -NumThread 12 -NumCtx 1024 -NumBatch 64
```

## Codex with Ollama

If you want to use local Codex against a model served by Ollama, the supported path is `Codex CLI` or the `Codex IDE extension` in local OSS mode.

Basic flow:

1. Make sure Ollama is running.
2. Pull a local model.
3. Start Codex in OSS mode.

Example:

```powershell
ollama pull hf.co/unsloth/Qwen3.5-4B-GGUF:IQ4_XS
codex --oss
```

Optional persistent Codex config in `~/.codex/config.toml`:

```toml
model_provider = "oss"
oss_provider = "ollama"
```

Useful smoke test:

```powershell
codex --oss "Summarize this repository and suggest one small performance experiment."
```

What to measure:

- whether local Codex feels responsive for coding tasks
- whether tool use, file edits, and repo summarization work reliably with the chosen local model
- whether a given model is usable for your coding workflow at acceptable latency

What not to compare directly:

- do not treat Codex session responsiveness as the same metric as raw Ollama `eval tok/s`
- Codex adds agent-loop overhead, prompt scaffolding, tool orchestration, filesystem actions, and UI/runtime latency
- use this repo's benchmark scripts for raw model throughput, and use Codex OSS mode for workflow usability testing

Practical recommendation:

- benchmark raw model speed with `measure-ollama-tps-safe.ps1`, `compare-models-safe.ps1`, and `sweep-ollama-options-safe.ps1`
- separately smoke-test `codex --oss` with the same local model to decide whether the model is good enough for real coding help

## Model setup example

The current reference baseline in this repo uses `qwen35-4b-q4km`, but the benchmark scripts are generic and can be pointed at any local Ollama model or GGUF path.

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

## Batch sweep recipe

To reproduce the focused batch sweep for `gemma:2b`:

```powershell
powershell -ExecutionPolicy Bypass -File .\sweep-ollama-options-safe.ps1 -Model gemma:2b -ThreadCounts 12 -NumCtxValues 2048 -NumBatchValues 64,128,256,512 -NumPredict 128 -Runs 3 -WarmupRuns 1
```

## Model comparison recipe

To compare any set of models at fixed hyperparameters:

```powershell
powershell -ExecutionPolicy Bypass -File .\compare-models-safe.ps1 -Models gemma:2b,nemotron-mini:4b,glm4:9b -NumThread 12 -NumCtx 2048 -NumBatch 128 -NumPredict 128 -Runs 3
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

## llama.cpp direct track

CPU:

```powershell
powershell -ExecutionPolicy Bypass -File .\experiments\llamacpp-vulkan\run-llama-bench-cpu.ps1 -LlamaBenchPath C:\path\to\llama-bench.exe -ModelPath C:\path\to\qwen35-4b-q4km.gguf -Threads 8 -PromptTokens 512 -GenerateTokens 128 -BatchSize 128 -Repetitions 3
```

Vulkan:

```powershell
powershell -ExecutionPolicy Bypass -File .\experiments\llamacpp-vulkan\run-llama-bench-vulkan.ps1 -LlamaBenchPath C:\path\to\llama-bench.exe -ModelPath C:\path\to\qwen35-4b-q4km.gguf -Threads 8 -PromptTokens 512 -GenerateTokens 128 -BatchSize 128 -Repetitions 3 -GpuLayers 999
```

Measured takeaway so far:

- use `8` threads, not `10`, for generation on this `4C/8T` CPU
- current direct `llama.cpp` CPU numbers do not beat the better Ollama numbers on this machine
- Vulkan still needs backend/device visibility fixed before it can be tested honestly

## Gemma measurement

Safe `gemma:2b` checks on the same laptop with `64` generated tokens, `2048` context, and `128` batch:

| Model | Threads | NumCtx | Median eval tok/s | Avg eval tok/s | Std dev | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| `gemma:2b` | `6` | `2048` | `14.05` | `14.05` | `0.97` | higher variance on the short two-run sample |
| `gemma:2b` | `8` | `2048` | `14.78` | `14.78` | `0.03` | very stable |
| `gemma:2b` | `10` | `2048` | `15.35` | `15.35` | `0.29` | first strong Gemma result |
| `gemma:2b` | `12` | `1024` | `15.48` | `15.48` | `0.30` | slightly behind the best ctx setting |
| `gemma:2b` | `12` | `2048` | `15.54` | `15.63` | `0.15` | confirmed best across 3 longer runs at batch 128 |
| `gemma:2b` | `12` | `4096` | `15.93` | `15.93` | `0.06` | nearly tied with `2048`, very stable |
| `gemma:2b` | `16` | `1024` | `15.53` | `15.53` | `0.58` | best short `16`-thread context result |
| `gemma:2b` | `16` | `2048` | `14.29` | `14.29` | `0.48` | regression versus `12` threads |
| `gemma:2b` | `16` | `4096` | `14.88` | `14.88` | `1.14` | high variance, not attractive |
| `gemma:2b` | `32` | `2048` | `12.99` | `12.99` | `0.08` | stable, but clearly slower from heavy oversubscription |

Focused batch sweep at `12` threads, `2048` context, `128` generated tokens:

| Batch | Median eval tok/s | Std dev | Variance % |
| --- | --- | --- | --- |
| `64` | `15.54` | `0.45` | `2.90` |
| `128` | `15.54` | `0.15` | `0.94` |
| `256` | `15.26` | `0.64` | `4.20` |
| `512` | `15.24` | `0.27` | `1.79` |

Measured takeaway so far:

- `gemma:2b` is much faster than the current `qwen35-4b-q4km` baseline on this laptop for decode throughput
- on this short safe sample, `12` threads slightly beat both `10` and `8` threads for `gemma:2b`
- pushing beyond `12` threads did not help overall: `16` regressed on most contexts, and `32` was clearly slower
- `2048` context is the current best Gemma setting, but `4096` is very close and more stable than the short `2048` sample
- batch `64` and `128` are tied on throughput, but `128` wins on stability (lowest variance)
- the earlier short-sample best of `~16.00` was a single outlier; the reproducible median is `~15.54`
- this is a throughput result, not a quality ranking; `qwen35-4b-q4km` remains the current reference model in this repo for broader comparisons

## Additional model benchmarks

Beyond the primary Gemma and Qwen targets, this repo now includes throughput measurements for additional local models at the best known Gemma hyperparameters (`12` threads, `2048` ctx, `128` batch, `128` generated tokens):

| Model | Size | Median eval tok/s | Std dev | vs gemma:2b |
| --- | --- | --- | --- | --- |
| `nemotron-mini:4b` | 2.7 GB (4B) | `6.53` | `0.98` | 2.4x slower |
| `glm4:9b` | 5.5 GB (9B) | `4.30` | `0.18` | 3.6x slower |

Takeaway: Neither model challenges `gemma:2b` on throughput. `gemma:2b` remains the fastest model measured on this laptop by a wide margin. The `nemotron-mini:4b` run showed unusually high variance (std dev `0.98`), suggesting thermal or scheduling sensitivity.

## Qwen quant comparison

You can compare alternate Ollama or Hugging Face-hosted quants with the same harness:

```powershell
powershell -ExecutionPolicy Bypass -File .\compare-models-safe.ps1 -Models qwen35-4b-q4km,qwen35-4b-udiq2m -NumThread 8 -NumCtx 2048 -NumPredict 128 -Runs 3
```

Measured takeaway so far on this laptop for a clean `Qwen3.5-4B` Windows decode comparison at `6` threads, `1024` context, `64` batch, and `64` generated tokens:

- `hf.co/unsloth/Qwen3.5-4B-GGUF:IQ4_XS` is the fastest tested Qwen weight so far at about `6.12` median eval tok/s
- `hf.co/unsloth/Qwen3.5-4B-GGUF:Q3_K_M` followed at about `5.85`
- the existing `qwen35-4b-q4km` reference landed at about `5.76` in the same short two-run harness
- a longer `IQ4_XS` confirmation at `128` generated tokens averaged about `6.37` eval tok/s, with a corrected median of about `6.32` after fixing the repo's odd-sample median helper
- on this machine, a smaller or more aggressive quant does not automatically win; the right answer needs measurement

Thread-only follow-up sweep for `IQ4_XS` at `1024` context, `64` batch, and `128` generated tokens:

- `12` threads is the current best tested `IQ4_XS` setting on this laptop at about `6.90` median eval tok/s
- `6` threads followed at about `6.54`
- `10` threads reached about `6.51`, but with noticeably higher variance
- `8` threads was stable at about `6.41`, but slower

## WSL comparison track

WSL readiness:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\test-wsl-readiness.ps1
```

WSL benchmark against the Windows-hosted Ollama API:

```powershell
powershell -ExecutionPolicy Bypass -File .\experiments\wsl\run-ollama-benchmark-wsl.ps1 -Distro Ubuntu-24.04 -Model qwen35-4b-q4km -Runs 3 -WarmupRuns 1 -NumPredict 128 -NumThread 8 -NumCtx 2048 -NumBatch 128
```

If the readiness script says `WindowsOllamaFromWSL=False`, this laptop is not currently exposing the Windows Ollama endpoint into WSL. In that case, either:

- point the WSL runner at a reachable endpoint with `-OllamaEndpoint http://<host>:11434`
- or install and run Ollama inside WSL for a true Linux-side comparison

For a reversible, scoped Windows-hosted API experiment, use the controlled bridge workflow documented in [experiments/wsl/README.md](./experiments/wsl/README.md) instead of permanently exposing Ollama broadly.

Measured takeaway so far:

- WSL itself is healthy on this machine
- with the controlled bridge enabled and the explicit endpoint `http://172.26.208.1:11434`, `gemma:2b` reached about `15.77` median eval tok/s from `WSL2` at `12` threads, `2048` context, `128` batch, and `64` generated tokens
- boosting WSL threads beyond `12` did not help: `16` threads landed around `14.98`, and `32` threads dropped to about `12.75`
- the WSL winner is very close to the current native Windows Gemma best of about `15.54` median eval tok/s on the same laptop
- `qwen35-4b-q4km` was notably worse through the same WSL path: about `5.33` median eval tok/s at `6` threads, `1024` context, and `64` batch, versus the native Windows Qwen reference of about `7.62`
- the tracked WSL snapshot lives in [docs/wsl-results-2026-07-03.md](./docs/wsl-results-2026-07-03.md)

Compare the native Windows CSV against the WSL CSV:

```powershell
powershell -ExecutionPolicy Bypass -File .\compare-runtime-results.ps1 -PrimaryCsv .\results-local\measure-qwen35-4b-q4km-<windows>.csv -SecondaryCsv .\results-local\wsl-ollama-qwen35-4b-q4km-<wsl>.csv
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
WSL-specific notes live in [experiments/wsl/README.md](./experiments/wsl/README.md).

## Existing compatibility scripts

The original scripts are still present for compatibility:

- `measure-ollama-tps.ps1`
- `sweep-ollama-options.ps1`
- `compare-ollama-models.ps1`
- `apply-llm-session-tuning.ps1`
- `restore-llm-session-tuning.ps1`

For new work, prefer the `*-safe.ps1` and `tools\*.ps1` workflow.
