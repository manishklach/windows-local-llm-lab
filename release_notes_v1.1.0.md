# windows-local-llm-lab v1.1.0

Follow-up release focused on Qwen weight selection, Qwen thread tuning, and benchmark summary correctness.

This release builds on the first public Windows local LLM lab release with a tighter Qwen benchmarking loop, a corrected stats helper, and a clearer recommendation for the best-tested Qwen throughput setup on this laptop.

## Highlights

- Added a direct Windows quant comparison for alternate `Qwen3.5-4B` weights
- Confirmed `hf.co/unsloth/Qwen3.5-4B-GGUF:IQ4_XS` as the best Qwen throughput candidate tested so far
- Added a focused thread-only sweep for `IQ4_XS`
- Fixed the odd-sample median calculation in `tools/LlmLab.Common.ps1`
- Updated repo docs and results summaries to reflect the new Qwen findings

## Key benchmark findings

### Best-tested Qwen weight so far

Short Windows comparison at `6` threads, `1024` context, `64` batch, and `64` generated tokens:

- `hf.co/unsloth/Qwen3.5-4B-GGUF:IQ4_XS`: about `6.12` median eval tok/s
- `hf.co/unsloth/Qwen3.5-4B-GGUF:Q3_K_M`: about `5.85`
- `qwen35-4b-q4km`: about `5.76`

Takeaway:

- `IQ4_XS` is the strongest Qwen throughput candidate measured so far in the safe Windows Ollama path
- the lighter `Q3_K_M` quant did not provide a meaningful speed advantage over the current `q4km` reference on this machine

### Best-tested Qwen thread setting so far

Focused `IQ4_XS` thread sweep at `1024` context, `64` batch, and `128` generated tokens:

- `12` threads: about `6.9006` median eval tok/s
- `6` threads: about `6.5437`
- `10` threads: about `6.5103`
- `8` threads: about `6.4138`

Takeaway:

- unlike the older `qwen35-4b-q4km` baseline, `IQ4_XS` clearly prefers `12` threads on this laptop in the tested cell
- `IQ4_XS` at `12` threads is now the strongest Qwen decode-throughput configuration currently measured in the repo

### Longer IQ4_XS confirmation

At `6` threads, `1024` context, `64` batch, and `128` generated tokens, measured runs were:

- `6.3157`
- `6.0242`
- `6.7633`

Corrected summary:

- average eval tok/s: `6.3677`
- median eval tok/s: `6.3157`
- std dev: `0.304`

## Benchmark correctness fix

This release fixes a real reporting bug in `tools/LlmLab.Common.ps1`.

- odd-length samples were reporting the wrong median value
- the helper now computes the middle index explicitly and reports correct medians for 3-run and 5-run samples

This matters because the repo leans on median eval tok/s for benchmark comparison and recommendation logic.

## What this means for new users

Another Windows user should be able to clone this repo and run the benchmarks as long as they have:

- Windows PowerShell
- Ollama installed and reachable on `localhost:11434`
- at least one local Ollama model or a GGUF they can create into an Ollama model
- enough free RAM and disk for the selected model
- AC power for the safety-first benchmark flow

Practical caveats:

- exact tok/s results will vary a lot by CPU, memory bandwidth, thermals, and background load
- WSL comparison requires the controlled bridge workflow or a separate Ollama inside WSL
- Vulkan benchmarking is still blocked on the current test machine's Windows driver state and should be treated as experimental

## Recommended starting points for another Windows laptop

For a quick reproducible baseline:

1. Run `tools/preflight-llm-benchmark.ps1`.
2. Enter max-performance mode with `tools/enter-max-perf-mode.ps1`.
3. Measure one stable local model with `measure-ollama-tps-safe.ps1`.
4. Run a narrow thread or batch sweep before changing multiple variables at once.

If a new user wants to reproduce the current Qwen tuning path specifically, the best first reproduction target is:

- model: `hf.co/unsloth/Qwen3.5-4B-GGUF:IQ4_XS`
- threads: `12`
- context: `1024`
- batch: `64`
- generated tokens: `128`

## Files most relevant to this release

- `README.md`
- `results.md`
- `tools/LlmLab.Common.ps1`

## Commits included

- `64ce5db` `Add Qwen quant findings and fix median stats`
- `c333de3` `Add IQ4_XS thread sweep results`
