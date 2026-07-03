[CmdletBinding()]
param(
    [string]$Distro = 'Ubuntu-24.04',
    [Parameter(Mandatory)]
    [string]$Model,
    [string]$Prompt = 'Explain why local inference performance depends on memory bandwidth.',
    [int]$Runs = 3,
    [int]$WarmupRuns = 1,
    [int]$NumPredict = 128,
    [int]$NumThread = 8,
    [int]$NumCtx = 2048,
    [int]$NumBatch = 128,
    [int]$CooldownSeconds = 10,
    [string]$OutDir = '.\results-local',
    [double]$Temperature = 0,
    [string]$OllamaEndpoint = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Convert-WindowsPathToWslPath {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $resolved = [System.IO.Path]::GetFullPath($Path)
    if ($resolved -notmatch '^([A-Za-z]):\\(.+)$') {
        throw "Cannot convert path to WSL format: $resolved"
    }

    $drive = $matches[1].ToLowerInvariant()
    $rest = $matches[2] -replace '\\', '/'
    return "/mnt/$drive/$rest"
}

if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) {
    throw 'wsl.exe is not available on this machine.'
}

$resolvedOutDir = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutDir)
if (-not (Test-Path -LiteralPath $resolvedOutDir)) {
    New-Item -ItemType Directory -Path $resolvedOutDir -Force | Out-Null
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$jsonlPath = Join-Path $resolvedOutDir "wsl-ollama-$($Model -replace '[:/\\]', '_')-$stamp.jsonl"
$csvPath = Join-Path $resolvedOutDir "wsl-ollama-$($Model -replace '[:/\\]', '_')-$stamp.csv"
$summaryPath = Join-Path $resolvedOutDir "wsl-ollama-$($Model -replace '[:/\\]', '_')-$stamp-summary.md"
$configPath = Join-Path $resolvedOutDir "wsl-ollama-$stamp-config.json"

[pscustomobject]@{
    Model           = $Model
    Prompt          = $Prompt
    Runs            = $Runs
    WarmupRuns      = $WarmupRuns
    NumPredict      = $NumPredict
    NumThread       = $NumThread
    NumCtx          = $NumCtx
    NumBatch        = $NumBatch
    CooldownSeconds = $CooldownSeconds
    Temperature     = $Temperature
    OllamaEndpoint  = $OllamaEndpoint
} | ConvertTo-Json -Depth 5 | Set-Content -Path $configPath

$wslConfigPath = Convert-WindowsPathToWslPath -Path $configPath
if (-not $wslConfigPath) {
    throw 'Could not convert the Windows config path to a WSL path.'
}

$pythonScript = @"
import json, sys, time, urllib.request

config_path = sys.argv[1]
with open(config_path, "r", encoding="utf-8") as handle:
    config = json.load(handle)

records = []

def discover_base_url():
    if config.get("OllamaEndpoint"):
        return str(config["OllamaEndpoint"]).rstrip("/")

    candidates = ["http://localhost:11434", "http://host.docker.internal:11434"]
    with open("/etc/resolv.conf", "r", encoding="utf-8") as handle:
        for line in handle:
            if line.startswith("nameserver "):
                candidates.append(f"http://{line.split()[1]}:11434")

    last_error = None
    for endpoint in candidates:
        try:
            urllib.request.urlopen(endpoint + "/api/tags", timeout=3).read()
            return endpoint
        except Exception as exc:
            last_error = f"{endpoint} -> {exc}"

    raise RuntimeError(f"Could not reach Ollama from WSL. Last error: {last_error}")

base_url = discover_base_url()
url = base_url + "/api/generate"

def run_one(run_index, warmup):
    payload = {
        "model": config["Model"],
        "prompt": config["Prompt"],
        "stream": False,
        "options": {
            "temperature": float(config["Temperature"]),
            "num_predict": int(config["NumPredict"]),
            "num_thread": int(config["NumThread"]),
            "num_ctx": int(config["NumCtx"]),
            "num_batch": int(config["NumBatch"]),
        },
    }
    body = json.dumps(payload).encode("utf-8")
    request = urllib.request.Request(url, data=body, headers={"Content-Type": "application/json"})
    started = time.time()
    with urllib.request.urlopen(request, timeout=1800) as response:
        data = json.loads(response.read().decode("utf-8"))
    elapsed = time.time() - started

    prompt_eval_duration = float(data.get("prompt_eval_duration", 0))
    eval_duration = float(data.get("eval_duration", 0))
    total_duration = float(data.get("total_duration", 0))
    prompt_eval_count = int(data.get("prompt_eval_count", 0))
    eval_count = int(data.get("eval_count", 0))

    prompt_tps = (prompt_eval_count / (prompt_eval_duration / 1e9)) if prompt_eval_duration > 0 else 0.0
    eval_tps = (eval_count / (eval_duration / 1e9)) if eval_duration > 0 else 0.0
    total_tps = ((prompt_eval_count + eval_count) / (total_duration / 1e9)) if total_duration > 0 else 0.0

    record = {
        "Timestamp": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
        "Runtime": "WSL2->WindowsOllama",
        "Model": config["Model"],
        "RunIndex": run_index,
        "Warmup": warmup,
        "NumPredict": int(config["NumPredict"]),
        "NumThread": int(config["NumThread"]),
        "NumCtx": int(config["NumCtx"]),
        "NumBatch": int(config["NumBatch"]),
        "PromptEvalCount": prompt_eval_count,
        "PromptEvalDurationNs": prompt_eval_duration,
        "PromptTokPerSec": round(prompt_tps, 4),
        "EvalCount": eval_count,
        "EvalDurationNs": eval_duration,
        "EvalTokPerSec": round(eval_tps, 4),
        "TotalDurationNs": total_duration,
        "LoadDurationNs": float(data.get("load_duration", 0)),
        "WallClockSeconds": round(elapsed, 4),
        "TotalTokPerSec": round(total_tps, 4),
        "GeneratedChars": len(data.get("response", "")),
    }
    records.append(record)
    print(f"{'warmup' if warmup else 'run'} {run_index}: eval tok/s {record['EvalTokPerSec']}", flush=True)

for i in range(1, int(config["WarmupRuns"]) + 1):
    run_one(i, True)
    if int(config["CooldownSeconds"]) > 0:
        time.sleep(int(config["CooldownSeconds"]))

for i in range(1, int(config["Runs"]) + 1):
    run_one(i, False)
    if i < int(config["Runs"]) and int(config["CooldownSeconds"]) > 0:
        time.sleep(int(config["CooldownSeconds"]))

print("JSON_RESULT_START", flush=True)
print(json.dumps(records), flush=True)
print("JSON_RESULT_END", flush=True)
"@

$bashScriptPath = "/tmp/qwen_windows_tps_lab_wsl_bench.py"
& wsl.exe -d $Distro -- bash -lc "cat > $bashScriptPath <<'PY'
$pythonScript
PY"

$rawOutput = & wsl.exe -d $Distro -- python3 $bashScriptPath $wslConfigPath 2>&1
$cleanOutput = (($rawOutput | Out-String) -replace "`0", '').Trim()
Write-Host $cleanOutput

$jsonMatch = [regex]::Match($cleanOutput, 'JSON_RESULT_START\s*(\[.*\])\s*JSON_RESULT_END', 'Singleline')
if (-not $jsonMatch.Success) {
    throw 'Could not parse structured JSON results from the WSL benchmark run.'
}

$records = $jsonMatch.Groups[1].Value | ConvertFrom-Json
$records | Export-Csv -Path $csvPath -NoTypeInformation
foreach ($record in @($records)) {
    ($record | ConvertTo-Json -Depth 6 -Compress) | Add-Content -Path $jsonlPath
}

$measured = @($records | Where-Object { -not $_.Warmup })
$values = @($measured | ForEach-Object { [double]$_.EvalTokPerSec } | Sort-Object)
$avg = [math]::Round((($values | Measure-Object -Average).Average), 4)
$min = [math]::Round((($values | Measure-Object -Minimum).Minimum), 4)
$max = [math]::Round((($values | Measure-Object -Maximum).Maximum), 4)
$median = if ($values.Count % 2 -eq 1) {
    [math]::Round($values[[int]($values.Count / 2)], 4)
} else {
    [math]::Round((($values[($values.Count / 2) - 1] + $values[$values.Count / 2]) / 2), 4)
}

$summary = @(
    '# WSL Benchmark Summary',
    '',
    "| Metric | Value |",
    "| --- | --- |",
    "| Runtime | WSL2 to Windows-hosted Ollama |",
    "| Distro | $Distro |",
    "| Endpoint | $(if ($OllamaEndpoint) { $OllamaEndpoint } else { 'auto-discovered from WSL' }) |",
    "| Model | $Model |",
    "| Avg eval tok/s | $avg |",
    "| Median eval tok/s | $median |",
    "| Min eval tok/s | $min |",
    "| Max eval tok/s | $max |"
)
$summary | Set-Content -Path $summaryPath

Remove-Item -LiteralPath $configPath -Force -ErrorAction SilentlyContinue

Write-Host ''
Write-Host 'WSL benchmark summary'
[pscustomobject]@{
    Runtime          = 'WSL2->WindowsOllama'
    Distro           = $Distro
    Model            = $Model
    AverageEvalTokPs = $avg
    MedianEvalTokPs  = $median
    MinEvalTokPs     = $min
    MaxEvalTokPs     = $max
    CsvPath          = $csvPath
    JsonlPath        = $jsonlPath
    SummaryPath      = $summaryPath
} | Format-List
