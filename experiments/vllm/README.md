# vLLM on This Laptop

This note documents the realistic `vLLM` path for this repo's current Windows laptop setup.

## Current conclusion

`vLLM` is worth treating as a serving-stack experiment here, not as the most likely path to higher raw decode throughput.

For this machine, the current best practical path is still:

- native Windows
- Ollama
- small local models that fit comfortably in memory

## Why this is not a straightforward win here

Observed local constraints on this laptop:

- Windows host: supported for Ollama, but `vLLM` does not support Windows natively
- WSL2 is installed and healthy
- default distro: `Ubuntu-24.04`
- WSL currently sees about `7.8 GB` RAM
- Docker Desktop is installed on Windows
- Docker-in-WSL now works inside `Ubuntu-24.04`
- GPU: AMD integrated graphics, not an NVIDIA CUDA setup

Practical implication:

- the high-value `vLLM + CUDA` path is not available on this machine
- the `vLLM + ROCm` path is high-friction and low-confidence for this exact Windows laptop setup
- the realistic path is a small `CPU-only` or very constrained WSL experiment

## What vLLM is still good for here

Even if it does not beat Ollama on raw single-user tok/s, `vLLM` can still be useful for:

- OpenAI-compatible local API serving
- request batching experiments
- prefix caching behavior
- long-prompt serving experiments
- comparing "serving stack feel" versus Ollama

## Recommended experiment scope

If you want to try `vLLM` on this laptop, keep the scope narrow:

1. Use `WSL2`, not native Windows.
2. Start with a very small model.
3. Treat it as a smoke test or serving experiment.
4. Do not expect it to beat the current Ollama results for compact models.

Good first models:

- `gemma:2b`-class sizes
- other roughly `1B` to `2B` text-generation checkpoints

Avoid starting with:

- large `Qwen` variants
- long-context heavy models
- anything that already feels tight in Ollama on this machine

## What must be fixed first

Before a real `vLLM` path is practical in WSL on this laptop:

1. Re-check available memory inside WSL.
2. Decide whether building `vLLM` CPU from source is worth the time on this machine.
3. Confirm a tiny Linux-side model server can start reliably before trying larger models.

Current smoke status:

- `docker --version` works inside `Ubuntu-24.04`
- `docker info` works inside `Ubuntu-24.04`
- `docker run --rm hello-world` completed successfully from WSL

That means the Docker + WSL bridge is healthy now. The remaining blocker is no longer Docker integration; it is whether `vLLM` itself is worth building and running on a small-memory CPU-only path.

## Suggested evaluation criteria

If you do run a `vLLM` experiment here, measure:

- time to first token
- short-answer throughput on a tiny model
- stability under repeated requests
- OpenAI-compatible API usability

Do not treat those numbers as directly interchangeable with:

- Ollama `eval tok/s`
- the repo's raw safe benchmark tables

`vLLM` is a serving runtime, so its real value on this laptop is more about API behavior and orchestration than raw isolated decode speed.

## Current repo recommendation

For this hardware:

- use Ollama plus the existing benchmark scripts for raw throughput work
- use `vLLM` only as an optional WSL experiment track
- defer deeper `vLLM` tuning unless the memory budget in WSL is improved and a CPU build is worth the setup cost
