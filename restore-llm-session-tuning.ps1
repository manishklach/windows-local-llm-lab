$ErrorActionPreference = 'Stop'

$stateFile = Join-Path $PSScriptRoot 'results-local\session-tuning-state.json'
if (-not (Test-Path $stateFile)) {
    throw "State file not found: $stateFile"
}

$state = Get-Content $stateFile -Raw | ConvertFrom-Json

if ($state.active_scheme) {
    powercfg /S $state.active_scheme | Out-Null
}

if ($null -ne $state.min_ac) {
    powercfg /SETACVALUEINDEX SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMIN $state.min_ac | Out-Null
}

if ($null -ne $state.max_ac) {
    powercfg /SETACVALUEINDEX SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMAX $state.max_ac | Out-Null
}

powercfg /SETACTIVE SCHEME_CURRENT | Out-Null

$ollama = Get-Process ollama -ErrorAction SilentlyContinue | Where-Object { $_.Path -like '*Ollama*' } | Select-Object -First 1
if ($ollama) {
    $ollama.PriorityClass = 'Normal'
}

[pscustomobject]@{
    ActiveScheme = ((powercfg /getactivescheme) -join ' ')
    OllamaPriority = if ($ollama) { (Get-Process -Id $ollama.Id).PriorityClass } else { 'not-running' }
} | Format-List
