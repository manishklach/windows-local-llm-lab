# Benchmark Methodology

## Core metrics

The most important throughput number for local generation is `eval tok/s`, derived from Ollama's `eval_count` and `eval_duration`. That metric isolates generation speed more directly than total wall-clock time.

Prompt evaluation throughput is useful too, but it reflects a different phase of inference. Prompt processing and token generation can behave differently under the same model and thread settings.

## Why warmup runs are excluded

Warmup runs help stabilize caches, initial model load behavior, and transient system noise. They should not be mixed into the final summary because they usually underperform the steady-state runs.

## Why 128 or 256 tokens are better than 16 or 32

Very short runs are fine for smoke tests, but they are too noisy for serious throughput comparisons. Using `128` or `256` generated tokens gives a more stable read on real generation speed.

## Why thread count has a sweet spot

More threads are not always better. On laptop CPUs, memory bandwidth, cache pressure, and scheduling overhead can make a lower thread count faster or more stable than using every logical thread.

## Why context length matters

Larger `num_ctx` settings can increase memory pressure and may reduce tokens-per-second even when the actual prompt is short. That is why the repo includes a dedicated context-length comparison script.

## Why quantization matters

Smaller quants can reduce memory usage, but they do not guarantee higher throughput on every laptop. The CPU, memory subsystem, and runtime all influence whether a different quant is actually faster.
