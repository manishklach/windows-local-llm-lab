[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$LlamaBenchPath,
    [Parameter(Mandatory)]
    [string]$ModelPath,
    [string]$OutDir = '.\results-local',
    [int]$Threads = 8,
    [int]$PromptTokens = 512,
    [int]$GenerateTokens = 128
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
$logPath = Join-Path $resolvedOutDir "llama-bench-vulkan-$stamp.log"

& $LlamaBenchPath -m $ModelPath -t $Threads -p $PromptTokens -n $GenerateTokens -ngl 999 2>&1 | Tee-Object -FilePath $logPath

Write-Host ''
Write-Host "Vulkan benchmark log saved to $logPath"
