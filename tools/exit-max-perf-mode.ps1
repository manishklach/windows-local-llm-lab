[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$StatePath = '.\.llm-maxperf-state.json',
    [switch]$DeleteStateAfterRestore
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'LlmLab.Common.ps1')

$resolvedStatePath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($StatePath)
if (-not (Test-Path -LiteralPath $resolvedStatePath)) {
    throw "State file not found: $resolvedStatePath"
}

$state = Get-Content -Raw -Path $resolvedStatePath | ConvertFrom-Json
$restoreLog = [System.Collections.Generic.List[string]]::new()

if ($state.activeSchemeGuid -and $PSCmdlet.ShouldProcess($state.activeSchemeGuid, 'Restore previous power scheme')) {
    if (Try-SetPowerValue -Arguments @('/S', [string]$state.activeSchemeGuid)) {
        $restoreLog.Add("Restored power plan GUID $($state.activeSchemeGuid).")
    } else {
        $restoreLog.Add("Could not restore power plan GUID $($state.activeSchemeGuid).")
    }
}

if ($null -ne $state.acSleepTimeoutMinutes -and $PSCmdlet.ShouldProcess('AC sleep timeout', 'Restore previous sleep timeout')) {
    if (Try-SetPowerValue -Arguments @('/CHANGE', 'standby-timeout-ac', [string]$state.acSleepTimeoutMinutes)) {
        $restoreLog.Add("Restored AC sleep timeout to $($state.acSleepTimeoutMinutes) minute(s).")
    } else {
        $restoreLog.Add('Could not restore AC sleep timeout.')
    }
}

if ($null -ne $state.acDiskTimeoutMinutes -and $PSCmdlet.ShouldProcess('AC disk timeout', 'Restore previous disk timeout')) {
    if (Try-SetPowerValue -Arguments @('/CHANGE', 'disk-timeout-ac', [string]$state.acDiskTimeoutMinutes)) {
        $restoreLog.Add("Restored AC disk timeout to $($state.acDiskTimeoutMinutes) minute(s).")
    } else {
        $restoreLog.Add('Could not restore AC disk timeout.')
    }
}

if ($null -ne $state.processorMinAc -and $PSCmdlet.ShouldProcess('Processor min AC', 'Restore previous processor min AC')) {
    if (Try-SetPowerValue -Arguments @('/SETACVALUEINDEX', 'SCHEME_CURRENT', 'SUB_PROCESSOR', 'PROCTHROTTLEMIN', [string]$state.processorMinAc)) {
        $restoreLog.Add("Restored processor minimum to $($state.processorMinAc)%.")
    } else {
        $restoreLog.Add('Could not restore processor minimum.')
    }
}

if ($null -ne $state.processorMaxAc -and $PSCmdlet.ShouldProcess('Processor max AC', 'Restore previous processor max AC')) {
    if (Try-SetPowerValue -Arguments @('/SETACVALUEINDEX', 'SCHEME_CURRENT', 'SUB_PROCESSOR', 'PROCTHROTTLEMAX', [string]$state.processorMaxAc)) {
        $restoreLog.Add("Restored processor maximum to $($state.processorMaxAc)%.")
    } else {
        $restoreLog.Add('Could not restore processor maximum.')
    }
}

if ($null -ne $state.activeCoolingAc -and $PSCmdlet.ShouldProcess('Active cooling', 'Restore previous active cooling value')) {
    if (Try-SetPowerValue -Arguments @('/SETACVALUEINDEX', 'SCHEME_CURRENT', 'SUB_PROCESSOR', 'SYSCOOLPOL', [string]$state.activeCoolingAc)) {
        $restoreLog.Add("Restored AC cooling policy to $($state.activeCoolingAc).")
    } else {
        $restoreLog.Add('Could not restore AC cooling policy.')
    }
}

if ($PSCmdlet.ShouldProcess('SCHEME_CURRENT', 'Refresh active scheme after restore')) {
    Try-SetPowerValue -Arguments @('/SETACTIVE', 'SCHEME_CURRENT') | Out-Null
}

if ($PSCmdlet.ShouldProcess('ollama.exe', 'Reset priority to Normal')) {
    if (Set-OllamaPrioritySafely -Priority 'Normal') {
        $restoreLog.Add('Reset existing ollama.exe processes to Normal priority.')
    } else {
        $restoreLog.Add('ollama.exe was not running; priority reset skipped.')
    }
}

if ($DeleteStateAfterRestore -and $PSCmdlet.ShouldProcess($resolvedStatePath, 'Delete state file after successful restore')) {
    Remove-Item -LiteralPath $resolvedStatePath -Force
    $restoreLog.Add('Deleted state file after restore.')
}

$scheme = Get-ActivePowerSchemeInfo

Write-Host ''
Write-Host 'Exit max-performance mode summary'
Write-Host ('Current plan: {0} ({1})' -f $scheme.Name, $scheme.Guid)
Write-Host ''
$restoreLog | ForEach-Object { Write-Host ('- {0}' -f $_) }
