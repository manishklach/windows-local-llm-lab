# Results

## Baseline Session

Date: `2026-07-03`

### Hardware Snapshot

- CPU: `AMD Ryzen 3 5300U`
- Cores / threads: `4 / 8`
- RAM: about `16 GB`
- GPU: integrated `AMD Radeon Graphics`

### Vanilla Windows Baseline

Short single-pass benchmark with `32` generated tokens:

| Metric | Value |
| --- | --- |
| Prompt tokens | `33` |
| Prompt tok/s | `12.89` |
| Generated tokens | `32` |
| Gen tok/s | `5.21` |
| Load time | `7.78 s` |
| Total time | `16.55 s` |

### First Thread Tuning Pass

Using the same short generation length:

| Threads | Prompt tok/s | Gen tok/s | Load time | Total time |
| --- | --- | --- | --- | --- |
| `4` | `15.31` | `5.56` | `7.83 s` | `15.79 s` |
| `8` | `23.24` | `6.86` | `7.19 s` | `13.36 s` |

### Takeaway

The first easy win on this laptop was setting `num_thread=8`, which improved generation throughput from `5.21 tok/s` to `6.86 tok/s`, about a `32%` increase over the initial baseline.

## Notes

- The earlier attempt to use a much larger GLM-family model on this laptop was not practical for local inference.
- A large failed Ollama partial download was left in the local blob cache and should be cleaned up before more storage-heavy experiments.
