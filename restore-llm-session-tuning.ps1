[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Write-Warning 'restore-llm-session-tuning.ps1 is now a compatibility wrapper. Prefer .\tools\exit-max-perf-mode.ps1 for new runs.'

& powershell -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'tools\exit-max-perf-mode.ps1') `
    -StatePath (Join-Path $PSScriptRoot 'results-local\session-tuning-state.json')
