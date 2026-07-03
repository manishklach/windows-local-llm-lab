[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch]$UseUltimatePerformance,
    [switch]$StopPulls,
    [switch]$NoSleep,
    [ValidateSet('Normal', 'AboveNormal', 'High')]
    [string]$OllamaPriority = 'Normal',
    [string]$StatePath = '.\.llm-maxperf-state.json',
    [switch]$ForceStateOverwrite
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'LlmLab.Common.ps1')

function Resolve-DesiredScheme {
    param(
        [bool]$UseUltimate
    )

    if (-not $UseUltimate) {
        return $script:PowerPlanAliases.HighPerformance
    }

    $current = Get-ActivePowerSchemeInfo
    if ($current.Name -like '*Ultimate Performance*') {
        return $current.Guid
    }

    try {
        $schemes = (powercfg /L) -join "`n"
        $existingUltimate = [regex]::Matches($schemes, 'Power Scheme GUID:\s+([a-f0-9-]+)\s+\((Ultimate Performance.*?)\)', 'IgnoreCase') |
            Select-Object -First 1
        if ($existingUltimate.Success) {
            return $existingUltimate.Groups[1].Value
        }
    } catch {
        Write-Verbose ("Could not enumerate existing power schemes: {0}" -f $_.Exception.Message)
    }

    $duplicateOutput = ''
    try {
        $duplicateOutput = (powercfg -duplicatescheme $script:PowerPlanAliases.Ultimate) -join "`n"
    } catch {
        Write-Verbose ("Ultimate Performance duplication failed: {0}" -f $_.Exception.Message)
    }

    if ($duplicateOutput) {
        $match = [regex]::Match($duplicateOutput, 'GUID:\s+([a-f0-9-]+)', 'IgnoreCase')
        if ($match.Success) {
            return $match.Groups[1].Value
        }
    }

    return $script:PowerPlanAliases.HighPerformance
}

$resolvedStatePath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($StatePath)
$stateDir = Split-Path -Parent $resolvedStatePath
if ($stateDir) {
    Ensure-Directory -Path $stateDir
}

if ((Test-Path -LiteralPath $resolvedStatePath) -and -not $ForceStateOverwrite) {
    throw "State file already exists at '$resolvedStatePath'. Restore first or pass -ForceStateOverwrite."
}

$currentScheme = Get-ActivePowerSchemeInfo
$previousState = [ordered]@{
    timestampUtc            = (Get-Date).ToUniversalTime().ToString('o')
    hostname                = $env:COMPUTERNAME
    windowsVersion          = Get-WindowsVersionSummary
    scriptVersion           = '1.0.0'
    activeSchemeGuid        = $currentScheme.Guid
    activeSchemeName        = $currentScheme.Name
    acSleepTimeoutMinutes   = Get-PowerSettingAcValue -SubGroup 'SUB_SLEEP' -Setting 'STANDBYIDLE'
    acDiskTimeoutMinutes    = Get-PowerSettingAcValue -SubGroup 'SUB_DISK' -Setting 'DISKIDLE'
    processorMinAc          = Get-PowerSettingAcValue -SubGroup 'SUB_PROCESSOR' -Setting 'PROCTHROTTLEMIN'
    processorMaxAc          = Get-PowerSettingAcValue -SubGroup 'SUB_PROCESSOR' -Setting 'PROCTHROTTLEMAX'
    activeCoolingAc         = Get-PowerSettingAcValue -SubGroup 'SUB_PROCESSOR' -Setting 'SYSCOOLPOL'
    hibernateChanged        = $false
    ultimatePerformanceRequested = [bool]$UseUltimatePerformance
    ultimatePerformanceEnabled   = $false
    powerSchemeChanged      = $false
}

$desiredScheme = Resolve-DesiredScheme -UseUltimate:$UseUltimatePerformance
if ($desiredScheme -eq $script:PowerPlanAliases.HighPerformance -and $UseUltimatePerformance) {
    Write-Warning 'Ultimate Performance was unavailable or could not be duplicated; falling back to High Performance.'
}

$changeLog = [System.Collections.Generic.List[string]]::new()
$changeLog.Add("Current power plan: $($currentScheme.Name) [$($currentScheme.Guid)]")

if ($PSCmdlet.ShouldProcess($resolvedStatePath, 'Save max-performance restore state')) {
    $previousState | ConvertTo-Json -Depth 6 | Set-Content -Path $resolvedStatePath
}

if ($desiredScheme -and $desiredScheme -ne $currentScheme.Guid) {
    if ($PSCmdlet.ShouldProcess($desiredScheme, 'Activate desired power scheme')) {
        if (Try-SetPowerValue -Arguments @('/S', $desiredScheme)) {
            $previousState.powerSchemeChanged = $true
            $previousState.ultimatePerformanceEnabled = ($desiredScheme -ne $script:PowerPlanAliases.HighPerformance)
            $changeLog.Add("Activated plan GUID $desiredScheme")
        } else {
            $changeLog.Add("Could not activate plan GUID $desiredScheme")
        }
    }
} else {
    $changeLog.Add('Kept current power plan.')
}

if ($PSCmdlet.ShouldProcess('SCHEME_CURRENT', 'Set AC processor min/max to 100%')) {
    if (Try-SetPowerValue -Arguments @('/SETACVALUEINDEX', 'SCHEME_CURRENT', 'SUB_PROCESSOR', 'PROCTHROTTLEMIN', '100')) {
        $changeLog.Add('Set AC processor minimum to 100%.')
    } else {
        $changeLog.Add('Processor minimum setting unsupported or failed.')
    }

    if (Try-SetPowerValue -Arguments @('/SETACVALUEINDEX', 'SCHEME_CURRENT', 'SUB_PROCESSOR', 'PROCTHROTTLEMAX', '100')) {
        $changeLog.Add('Set AC processor maximum to 100%.')
    } else {
        $changeLog.Add('Processor maximum setting unsupported or failed.')
    }

    if (Try-SetPowerValue -Arguments @('/SETACVALUEINDEX', 'SCHEME_CURRENT', 'SUB_PROCESSOR', 'SYSCOOLPOL', '0')) {
        $changeLog.Add('Preferred active cooling on AC.')
    } else {
        $changeLog.Add('Active cooling setting unsupported; skipped.')
    }

    Try-SetPowerValue -Arguments @('/SETACTIVE', 'SCHEME_CURRENT') | Out-Null
}

if ($NoSleep) {
    if ($PSCmdlet.ShouldProcess('AC sleep/disk timeouts', 'Disable sleep and disk idle timeouts on AC')) {
        if (Try-SetPowerValue -Arguments @('/CHANGE', 'standby-timeout-ac', '0')) {
            $changeLog.Add('Disabled AC sleep timeout.')
        } else {
            $changeLog.Add('Could not disable AC sleep timeout.')
        }

        if (Try-SetPowerValue -Arguments @('/CHANGE', 'disk-timeout-ac', '0')) {
            $changeLog.Add('Disabled AC disk timeout.')
        } else {
            $changeLog.Add('Could not disable AC disk timeout.')
        }
    }
}

if ($StopPulls) {
    if ($PSCmdlet.ShouldProcess('Ollama pull processes', 'Stop active model pulls only')) {
        $stopped = @(Stop-OllamaPullProcesses)
        if ($stopped.Count -gt 0) {
            $changeLog.Add("Stopped Ollama pull processes: $($stopped -join ', ')")
        } else {
            $changeLog.Add('No active Ollama pull process detected.')
        }
    }
}

if ($PSCmdlet.ShouldProcess('ollama.exe', "Set priority to $OllamaPriority")) {
    if (Set-OllamaPrioritySafely -Priority $OllamaPriority) {
        $changeLog.Add("Set existing ollama.exe priority to $OllamaPriority.")
    } else {
        $changeLog.Add('ollama.exe was not running; priority change skipped.')
    }
}

$newScheme = Get-ActivePowerSchemeInfo

Write-Host ''
Write-Host 'Entered max-performance mode'
Write-Host ('Previous plan: {0} ({1})' -f $currentScheme.Name, $currentScheme.Guid)
Write-Host ('Current plan:  {0} ({1})' -f $newScheme.Name, $newScheme.Guid)
Write-Host ('State file:    {0}' -f $resolvedStatePath)
Write-Host ''
$changeLog | ForEach-Object { Write-Host ('- {0}' -f $_) }
Write-Host ''
Write-Host 'Restore with:'
Write-Host 'powershell -ExecutionPolicy Bypass -File .\tools\exit-max-perf-mode.ps1'
