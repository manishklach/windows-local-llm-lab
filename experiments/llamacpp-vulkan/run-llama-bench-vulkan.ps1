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
    [int]$Repetitions = 3,
    [int]$GpuLayers = 999
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
$jsonPath = Join-Path $resolvedOutDir "llama-bench-vulkan-$stamp.json"
$logPath = Join-Path $resolvedOutDir "llama-bench-vulkan-$stamp.log"
$stdoutPath = Join-Path $resolvedOutDir "llama-bench-vulkan-$stamp.stdout.tmp"
$stderrPath = Join-Path $resolvedOutDir "llama-bench-vulkan-$stamp.stderr.tmp"

$args = @(
    '-m', $ModelPath,
    '-t', $Threads,
    '-b', $BatchSize,
    '-p', $PromptTokens,
    '-n', $GenerateTokens,
    '-r', $Repetitions,
    '-ngl', $GpuLayers,
    '-o', 'json'
)

$process = Start-Process -FilePath $LlamaBenchPath `
    -ArgumentList $args `
    -PassThru `
    -NoNewWindow `
    -Wait `
    -RedirectStandardOutput $stdoutPath `
    -RedirectStandardError $stderrPath

$stdoutText = if (Test-Path -LiteralPath $stdoutPath) { Get-Content -Raw $stdoutPath } else { '' }
$stderrText = if (Test-Path -LiteralPath $stderrPath) { Get-Content -Raw $stderrPath } else { '' }
$text = ($stdoutText, $stderrText -join [Environment]::NewLine).Trim()
$text | Set-Content -Path $logPath
$stdoutText | Set-Content -Path $jsonPath

Remove-Item -LiteralPath $stdoutPath, $stderrPath -Force -ErrorAction SilentlyContinue

if ($process.ExitCode -ne 0) {
    throw "llama-bench exited with code $($process.ExitCode). See $logPath"
}

Write-Host ''
Write-Host "Vulkan llama-bench JSON saved to $jsonPath"
Write-Host "Vulkan llama-bench log saved to $logPath"
