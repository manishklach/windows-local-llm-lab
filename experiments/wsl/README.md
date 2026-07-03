# WSL Comparison Track

This folder is for comparing the current native Windows baseline against the same Ollama model accessed from `WSL2`.

## Why test WSL

- `vLLM` and other Linux-first runtimes generally fit better in `WSL` than on native Windows.
- Even before trying a new runtime, it is useful to measure whether `WSL2` adds overhead or changes throughput when talking to the Windows-hosted Ollama API.
- If `WSL` is slower than native Windows for the same model and prompt, that is a signal to be cautious about moving the whole workflow there on this laptop.

## Guardrails

- Keep the native Windows Ollama benchmark as the baseline.
- Do not assume `WSL` is faster until the numbers show it.
- Start by calling the Windows-hosted Ollama service from `WSL`.
- Only move to a fully Linux-hosted runtime after the lightweight comparison is complete.

## Workflow

Check WSL readiness:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\test-wsl-readiness.ps1
```

Run the same benchmark prompt from WSL against the Windows-hosted Ollama service:

```powershell
powershell -ExecutionPolicy Bypass -File .\experiments\wsl\run-ollama-benchmark-wsl.ps1 -Distro Ubuntu-24.04 -Model qwen35-4b-q4km -Runs 3 -NumPredict 128 -NumThread 8 -NumCtx 2048
```

If the readiness script reports `WindowsOllamaFromWSL=False`, you can either:

- pass a reachable API base URL with `-OllamaEndpoint http://<host>:11434`
- or switch to a WSL-hosted Ollama setup before benchmarking

## Controlled bridge experiment

If you want to test the Windows-hosted Ollama API from `WSL`, do it as a reversible experiment instead of a permanent default.

This repo includes:

- `enable-wsl-ollama-bridge.ps1`
- `disable-wsl-ollama-bridge.ps1`

What the enable script does:

- saves the prior user-level `OLLAMA_HOST` value to a local state file
- sets user-level `OLLAMA_HOST=0.0.0.0:11434`
- creates a Windows Firewall inbound rule for TCP `11434`
- scopes the inbound rule to the detected `vEthernet (WSL)` subnet by default

What it does not do:

- it does not make this the repo default
- it does not open the port broadly to every network by default
- it does not restart Ollama for you

Enable the controlled experiment from an elevated PowerShell session:

```powershell
powershell -ExecutionPolicy Bypass -File .\experiments\wsl\enable-wsl-ollama-bridge.ps1
```

Then restart Ollama manually and re-run the readiness check:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\test-wsl-readiness.ps1
```

When you are done, restore the prior behavior:

```powershell
powershell -ExecutionPolicy Bypass -File .\experiments\wsl\disable-wsl-ollama-bridge.ps1 -DeleteStateAfterRestore
```

If the script cannot detect the `vEthernet (WSL)` subnet, you can pass `-AllowLocalSubnetFallback`, but that is broader than the WSL-only path and should stay a temporary experiment.

Then compare the Windows CSV from `measure-ollama-tps-safe.ps1` against the WSL CSV with:

```powershell
powershell -ExecutionPolicy Bypass -File .\compare-runtime-results.ps1 -PrimaryCsv .\results-local\measure-qwen35-4b-q4km-<windows>.csv -SecondaryCsv .\results-local\wsl-ollama-qwen35-4b-q4km-<wsl>.csv
```

## Findings so far on this laptop

- `WSL2` is installed and healthy, with `Ubuntu-24.04` available.
- Python and curl are available inside WSL.
- The current Windows-hosted Ollama endpoint is not reachable from WSL by default on this machine.
- That means the repo can verify WSL readiness, but a real WSL-vs-Windows throughput comparison still requires either a reachable `-OllamaEndpoint` or a WSL-hosted Ollama runtime.
