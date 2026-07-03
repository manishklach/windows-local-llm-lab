[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$LlamaBenchPath,
    [Parameter(Mandatory)]
    [string]$ModelPath,
    [string]$OutDir = '.\results-local',
    [int]$Threads = 8,
    [int]$PromptTokens = 512,
    [int]$GenerateTokens = 128,
    [int]$BatchSize = 128,
    [int]$Repetitions = 3
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $LlamaBenchPath)) {
    throw "llama-bench executable not found: $LlamaBenchPath"
}

if (-not (Test-Path -LiteralPath $ModelPath)) {
    throw "Model not found: $ModelPath"
}

$resolvedOutDir = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutDir)
if (-not (Test-Path -LiteralPath $resolvedOutDir)) {
    New-Item -ItemType Directory -Path $resolvedOutDir -Force | Out-Null
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$jsonPath = Join-Path $resolvedOutDir "llama-bench-cpu-$stamp.json"
$logPath = Join-Path $resolvedOutDir "llama-bench-cpu-$stamp.log"

$args = @(
    '-m', $ModelPath,
    '-t', $Threads,
    '-b', $BatchSize,
    '-p', $PromptTokens,
    '-n', $GenerateTokens,
    '-r', $Repetitions,
    '-o', 'json'
)

$output = & $LlamaBenchPath @args 2>&1
$output | Tee-Object -FilePath $logPath | Out-Null
$text = $output | Out-String
$text | Set-Content -Path $jsonPath

Write-Host ''
Write-Host "CPU llama-bench JSON saved to $jsonPath"
Write-Host "CPU llama-bench log saved to $logPath"
