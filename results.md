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

## Safe Runtime/System Tuning

### Session Tuning Applied

- switched from `Balanced` to `High performance`
- set AC minimum processor state to `100%`
- kept AC maximum processor state at `100%`
- raised `ollama.exe` priority from `Normal` to `High`
- stopped background model pulls before benchmarking

### Tuned Single-Model Check

Using the same `Q4_K_M` model with `8` threads and `16` generated tokens:

| Metric | Before tuning | After tuning |
| --- | --- | --- |
| Prompt tok/s | `18.86` | `19.79` |
| Gen tok/s | `6.78` | `6.76` |
| Load time | `13.42 s` | `7.85 s` |
| Total time | `17.17 s` | `11.54 s` |

### Tuned Thread Sweep

Short polite run with `16` generated tokens:

| Threads | Prompt tok/s | Gen tok/s | Load time | Total time |
| --- | --- | --- | --- | --- |
| `8` | `20.73` | `6.87` | `7.00 s` | `10.59 s` |
| `7` | `18.83` | `6.54` | `7.03 s` | `10.86 s` |
| `6` | `17.48` | `5.99` | `7.52 s` | `11.68 s` |

### Takeaway

Safe Windows/session tuning did **not** materially increase generation throughput on this laptop by itself, but it did make the benchmark loop much healthier:

- much faster load time
- lower total time per short run
- fewer background conflicts

For raw generation speed, `8` threads is still the best setting among the tuned runs so far.

## Notes

- The earlier attempt to use a much larger GLM-family model on this laptop was not practical for local inference.
- A large failed Ollama partial download was left in the local blob cache and should be cleaned up before more storage-heavy experiments.
