[CmdletBinding()]
param(
    [int]$IntervalSeconds = 5,
    [string]$LogPath = '.\results-local\thermals.csv',
    [int]$MaxSamples = 0,
    [int]$WarnCpuPercent = 95,
    [int]$WarnMemoryPercent = 90
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'LlmLab.Common.ps1')

$resolvedLogPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($LogPath)
$logDir = Split-Path -Parent $resolvedLogPath
if ($logDir) {
    Ensure-Directory -Path $logDir
}

$headerNeeded = -not (Test-Path -LiteralPath $resolvedLogPath)
$temperatureWarningShown = $false
$sampleIndex = 0

while ($true) {
    $sampleIndex++
    $cpuPercent = [math]::Round((Get-Counter '\Processor(_Total)\% Processor Time').CounterSamples[0].CookedValue, 2)
    $memory = Get-MemoryStatusInfo
    $scheme = Get-ActivePowerSchemeInfo
    $battery = Get-BatteryStatusInfo
    $ollamaProcess = Get-Process -Name ollama -ErrorAction SilentlyContinue | Sort-Object CPU -Descending | Select-Object -First 1

    $temperatureC = $null
    try {
        $thermal = Get-WmiObject -Namespace 'root/wmi' -Class MSAcpi_ThermalZoneTemperature -ErrorAction Stop | Select-Object -First 1
        if ($thermal -and $thermal.CurrentTemperature) {
            $temperatureC = [math]::Round(($thermal.CurrentTemperature / 10) - 273.15, 2)
        }
    } catch {
        if (-not $temperatureWarningShown) {
            Write-Warning 'Thermal WMI sensors were unavailable; temperature values will be blank.'
            $temperatureWarningShown = $true
        }
    }

    $row = [pscustomobject]@{
        Timestamp               = (Get-Date).ToString('o')
        CpuPercent              = $cpuPercent
        AvailableMemoryGB       = $memory.FreeGB
        TotalMemoryGB           = $memory.TotalGB
        MemoryUsedPercent       = $memory.UsedPercent
        OllamaCpuSeconds        = if ($ollamaProcess) { [math]::Round($ollamaProcess.CPU, 2) } else { $null }
        OllamaWorkingSetGB      = if ($ollamaProcess) { [math]::Round($ollamaProcess.WorkingSet64 / 1GB, 3) } else { $null }
        PowerScheme             = $scheme.Name
        OnAcPower               = $battery.OnAcPower
        BatteryPercent          = $battery.BatteryPercent
        TemperatureC            = $temperatureC
    }

    if ($headerNeeded) {
        $row | Export-Csv -Path $resolvedLogPath -NoTypeInformation
        $headerNeeded = $false
    } else {
        $row | Export-Csv -Path $resolvedLogPath -Append -NoTypeInformation
    }

    if ($cpuPercent -ge $WarnCpuPercent) {
        Write-Warning ("CPU utilization is high at {0}%." -f $cpuPercent)
    }

    if ($memory.UsedPercent -ge $WarnMemoryPercent) {
        Write-Warning ("Memory usage is high at {0}%." -f $memory.UsedPercent)
    }

    Write-Host ("[{0}] CPU {1}% | Memory {2}% used | Ollama WS {3} GB | Temp {4}" -f `
        $row.Timestamp,
        $cpuPercent,
        $memory.UsedPercent,
        $(if ($row.OllamaWorkingSetGB -ne $null) { $row.OllamaWorkingSetGB } else { 'n/a' }),
        $(if ($temperatureC -ne $null) { "$temperatureC C" } else { 'n/a' }))

    if ($MaxSamples -gt 0 -and $sampleIndex -ge $MaxSamples) {
        break
    }

    Start-Sleep -Seconds $IntervalSeconds
}
