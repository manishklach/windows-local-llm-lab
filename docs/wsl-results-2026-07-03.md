# WSL Results 2026-07-03

This document captures the first successful `WSL2 -> Windows Ollama` throughput measurements on this laptop.

## Machine and path

- Host: `AMD Ryzen 3 5300U`, `4C/8T`, `16 GB RAM`
- Distro: `Ubuntu-24.04`
- Runtime path: `WSL2 -> Windows-hosted Ollama`
- Endpoint used from WSL: `http://172.26.208.1:11434`
- Bridge mode: controlled WSL bridge experiment enabled

## Gemma throughput sweep

All runs below used:

- Model: `gemma:2b`
- NumCtx: `2048`
- NumBatch: `128`
- NumPredict: `64`
- Warmups: `1`
- Measured runs: `2`

| Threads | Median eval tok/s | Avg eval tok/s | Min | Max | Summary artifact |
| --- | --- | --- | --- | --- | --- |
| `12` | `15.77` | `15.77` | `15.73` | `15.82` | `wsl-ollama-gemma_2b-20260703-060215-summary.md` |
| `16` | `14.98` | `14.98` | `14.96` | `15.01` | `wsl-ollama-gemma_2b-20260703-060532-summary.md` |
| `32` | `12.75` | `12.75` | `12.73` | `12.76` | `wsl-ollama-gemma_2b-20260703-060642-summary.md` |

## Takeaway

- `12` threads is the current best WSL result for `gemma:2b` on this laptop.
- `16` threads regressed relative to `12`, matching the native Windows trend.
- `32` threads is clearly worse and confirms the oversubscription ceiling.
- The best WSL result is very close to the native Windows short-sample `gemma:2b` best of about `16.00` eval tok/s.

## Qwen reference run

This run used the current best validated Windows Qwen cell for comparison:

- Model: `qwen35-4b-q4km`
- Threads: `6`
- NumCtx: `1024`
- NumBatch: `64`
- NumPredict: `64`
- Warmups: `1`
- Measured runs: `2`

| Threads | NumCtx | NumBatch | Median eval tok/s | Avg eval tok/s | Min | Max | Summary artifact |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `6` | `1024` | `64` | `5.33` | `5.33` | `5.05` | `5.61` | `wsl-ollama-qwen35-4b-q4km-20260703-061017-summary.md` |

Qwen takeaway:

- This WSL result is clearly below the current native Windows Qwen safe-sweep reference of about `7.62` median eval tok/s at the same `6/1024/64` shape.
- On this laptop, the `WSL2 -> Windows Ollama` path looks much more competitive for `gemma:2b` than for `qwen35-4b-q4km`.

## Notes

- Raw CSV, JSONL, and summary files live in `results-local/` and are intentionally gitignored to keep the repo clean.
- The tracked repo documents the measured conclusions and the exact artifact filenames for reproducibility.
