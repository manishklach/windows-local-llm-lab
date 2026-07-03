param(
    [switch]$StopPulls
)

$ErrorActionPreference = 'Stop'

$stateFile = Join-Path $PSScriptRoot 'results-local\session-tuning-state.json'
$stateDir = Split-Path -Parent $stateFile
if (-not (Test-Path $stateDir)) {
    New-Item -ItemType Directory -Path $stateDir | Out-Null
}

$currentScheme = (powercfg /getactivescheme) -join "`n"
$schemeMatch = [regex]::Match($currentScheme, 'GUID:\s+([a-f0-9-]+)', 'IgnoreCase')
if (-not $schemeMatch.Success) {
    throw "Could not determine active power scheme."
}
$activeScheme = $schemeMatch.Groups[1].Value

$minAcRaw = (powercfg /q SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMIN) -join "`n"
$maxAcRaw = (powercfg /q SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMAX) -join "`n"
$minAcMatch = [regex]::Match($minAcRaw, 'Current AC Power Setting Index:\s+0x([0-9a-f]+)', 'IgnoreCase')
$maxAcMatch = [regex]::Match($maxAcRaw, 'Current AC Power Setting Index:\s+0x([0-9a-f]+)', 'IgnoreCase')

$state = [pscustomobject]@{
    active_scheme = $activeScheme
    min_ac        = if ($minAcMatch.Success) { [convert]::ToInt32($minAcMatch.Groups[1].Value, 16) } else { $null }
    max_ac        = if ($maxAcMatch.Success) { [convert]::ToInt32($maxAcMatch.Groups[1].Value, 16) } else { $null }
}
$state | ConvertTo-Json | Set-Content -Path $stateFile

if ($StopPulls) {
    Get-CimInstance Win32_Process |
        Where-Object { $_.Name -eq 'ollama.exe' -and $_.CommandLine -like '* pull *' } |
        ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
}

powercfg /S SCHEME_MIN | Out-Null
powercfg /SETACVALUEINDEX SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMIN 100 | Out-Null
powercfg /SETACVALUEINDEX SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMAX 100 | Out-Null
powercfg /SETACTIVE SCHEME_CURRENT | Out-Null

$ollama = Get-Process ollama -ErrorAction SilentlyContinue | Where-Object { $_.Path -like '*Ollama*' } | Select-Object -First 1
if ($ollama) {
    $ollama.PriorityClass = 'High'
}

[pscustomobject]@{
    ActiveScheme = ((powercfg /getactivescheme) -join ' ')
    OllamaPriority = if ($ollama) { (Get-Process -Id $ollama.Id).PriorityClass } else { 'not-running' }
    StateFile = $stateFile
} | Format-List
