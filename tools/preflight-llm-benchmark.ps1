[CmdletBinding()]
param(
    [int]$MinBatteryPercent = 40,
    [double]$MinFreeMemoryGB = 4,
    [switch]$RequireAC,
    [switch]$WarnOnly,
    [string]$Model,
    [string]$ResultsPath = '.\results-local'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'LlmLab.Common.ps1')

$resolvedResultsPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($ResultsPath)
$preflight = Invoke-LlmPreflightCheck `
    -MinBatteryPercent $MinBatteryPercent `
    -MinFreeMemoryGB $MinFreeMemoryGB `
    -RequireAC:$RequireAC `
    -Model $Model `
    -ResultsPath $resolvedResultsPath

Write-Host ''
Write-Host 'LLM benchmark preflight'
Write-Host ('Timestamp:    {0}' -f $preflight.Timestamp)
Write-Host ('Windows:      {0}' -f $preflight.Windows)
Write-Host ('Power scheme: {0} ({1})' -f $preflight.PowerScheme.Name, $preflight.PowerScheme.Guid)
Write-Host ('Admin token:  {0}' -f $preflight.IsAdmin)
Write-Host ''

$preflight.Checks |
    Select-Object Name, Passed, Details |
    Format-Table -Wrap -AutoSize

Write-Host ''
if ($preflight.Safe) {
    Write-Host 'Preflight result: SAFE to benchmark.'
    exit 0
}

if ($WarnOnly) {
    Write-Warning 'Preflight found issues, but -WarnOnly was passed so execution can continue.'
    exit 0
}

Write-Error 'Preflight found issues. Fix the failed checks or re-run with -WarnOnly if you only want advisory output.'
