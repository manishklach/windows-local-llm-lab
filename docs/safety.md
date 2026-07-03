# Safety

This repo is for squeezing more local LLM throughput out of a Windows laptop without crossing into unsafe or hard-to-reverse tuning.

## Recommended and allowed

- Windows max-performance power plans.
- AC-only processor min and max at `100%`.
- Preferring active cooling when the setting is available.
- `ollama.exe` priority up to `High`.
- Disabling sleep while plugged in for a benchmark session.
- Warmup runs, cooldowns, and thermal monitoring.

## Not recommended

- Realtime process priority.
- BIOS tweaks or hidden firmware options.
- Undervolting experiments.
- Registry hacks for thermal or scheduler behavior.
- Fan-control hacks.
- Disabling thermal throttling or thermal protections.
- Disabling Windows Defender globally.
- Killing unrelated user processes just because they use CPU.
- Broadly exposing the Ollama API to every network as a permanent default.

## Operating envelope

- Keep the laptop plugged into AC power.
- Place it on a hard surface so the cooling path is not blocked.
- Stop and cool down if the machine reboots or hangs repeatedly.
- Use the restore script after a benchmark session so temporary changes do not linger.

## Reversible tuning

Every script in `tools/` is designed to save or infer the prior state before applying changes, and to restore the machine with `.\tools\exit-max-perf-mode.ps1`.

## Network exposure experiments

If you test `WSL` access to the Windows-hosted Ollama API, treat it as a reversible experiment:

- prefer a scoped Windows Firewall rule over broad inbound access
- prefer WSL-subnet-only scope over `Any`
- restart Ollama only long enough to run the comparison
- restore the prior host binding and remove the firewall rule after the test
