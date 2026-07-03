[CmdletBinding()]
param(
    [switch]$StopPulls
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Write-Warning 'apply-llm-session-tuning.ps1 is now a compatibility wrapper. Prefer .\tools\enter-max-perf-mode.ps1 for new runs.'

& powershell -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'tools\enter-max-perf-mode.ps1') `
    -StopPulls:$StopPulls `
    -NoSleep `
    -OllamaPriority High `
    -StatePath (Join-Path $PSScriptRoot 'results-local\session-tuning-state.json')
