Set-StrictMode -Version Latest

$script:PowerPlanAliases = @{
    Balanced        = '381b4222-f694-41f0-9685-ff5bb260df2e'
    HighPerformance = '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'
    Ultimate        = 'e9a42b02-d5df-448d-aa00-03f14749eb61'
}

function Resolve-LlmLabRepoRoot {
    param(
        [Parameter(Mandatory)]
        [string]$ScriptRoot
    )

    if ((Split-Path -Leaf $ScriptRoot) -eq 'tools') {
        return Split-Path -Parent $ScriptRoot
    }

    return $ScriptRoot
}

function Ensure-Directory {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Get-LlmTimestamp {
    return (Get-Date).ToString('yyyyMMdd-HHmmss')
}

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}

function Get-WindowsVersionSummary {
    $os = Get-CimInstance Win32_OperatingSystem
    return '{0} {1} ({2})' -f $os.Caption, $os.Version, $os.BuildNumber
}

function Get-ActivePowerSchemeInfo {
    $text = (powercfg /GETACTIVESCHEME) -join "`n"
    $match = [regex]::Match($text, 'GUID:\s+([a-f0-9-]+)\s+\((.+?)\)', 'IgnoreCase')
    if (-not $match.Success) {
        throw 'Could not determine active power scheme.'
    }

    [pscustomobject]@{
        Guid = $match.Groups[1].Value
        Name = $match.Groups[2].Value
        Raw  = $text
    }
}

function Get-PowerSettingAcValue {
    param(
        [Parameter(Mandatory)]
        [string]$SubGroup,
        [Parameter(Mandatory)]
        [string]$Setting
    )

    try {
        $text = (powercfg /Q SCHEME_CURRENT $SubGroup $Setting) -join "`n"
    } catch {
        return $null
    }

    $match = [regex]::Match($text, 'Current AC Power Setting Index:\s+0x([0-9a-f]+)', 'IgnoreCase')
    if (-not $match.Success) {
        return $null
    }

    return [convert]::ToInt32($match.Groups[1].Value, 16)
}

function Try-SetPowerValue {
    param(
        [Parameter(Mandatory)]
        [string[]]$Arguments
    )

    try {
        & powercfg @Arguments | Out-Null
        return $true
    } catch {
        Write-Verbose ("powercfg {0} failed: {1}" -f ($Arguments -join ' '), $_.Exception.Message)
        return $false
    }
}

function Get-BatteryStatusInfo {
    $battery = Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $battery) {
        return [pscustomobject]@{
            HasBattery      = $false
            BatteryPercent  = $null
            OnAcPower       = $true
            BatteryStatus   = $null
        }
    }

    $onAc = $battery.BatteryStatus -in @(2, 6, 7, 8, 9, 11)
    [pscustomobject]@{
        HasBattery      = $true
        BatteryPercent  = [int]$battery.EstimatedChargeRemaining
        OnAcPower       = $onAc
        BatteryStatus   = $battery.BatteryStatus
    }
}

function Get-MemoryStatusInfo {
    $os = Get-CimInstance Win32_OperatingSystem
    $totalBytes = [double]$os.TotalVisibleMemorySize * 1KB
    $freeBytes = [double]$os.FreePhysicalMemory * 1KB
    $usedPercent = if ($totalBytes -gt 0) {
        (($totalBytes - $freeBytes) / $totalBytes) * 100
    } else {
        0
    }

    [pscustomobject]@{
        TotalBytes        = [math]::Round($totalBytes, 0)
        FreeBytes         = [math]::Round($freeBytes, 0)
        TotalGB           = [math]::Round($totalBytes / 1GB, 2)
        FreeGB            = [math]::Round($freeBytes / 1GB, 2)
        UsedPercent       = [math]::Round($usedPercent, 2)
    }
}

function Test-PendingReboot {
    $paths = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending',
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'
    )

    foreach ($path in $paths) {
        if (Test-Path -LiteralPath $path) {
            return $true
        }
    }

    try {
        $sessionManager = Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name PendingFileRenameOperations -ErrorAction SilentlyContinue
        if ($null -ne $sessionManager.PendingFileRenameOperations) {
            return $true
        }
    } catch {
    }

    return $false
}

function Test-OllamaInstalled {
    return $null -ne (Get-Command ollama -ErrorAction SilentlyContinue)
}

function Test-OllamaReachable {
    try {
        Invoke-RestMethod -Method Get -Uri 'http://localhost:11434/api/tags' -TimeoutSec 10 | Out-Null
        return $true
    } catch {
        return $false
    }
}

function Get-OllamaLocalModelNames {
    if (-not (Test-OllamaInstalled)) {
        return @()
    }

    $lines = &(Get-Command ollama).Source list 2>$null
    if (-not $lines) {
        return @()
    }

    $models = foreach ($line in $lines | Select-Object -Skip 1) {
        $trimmed = $line.Trim()
        if (-not $trimmed) {
            continue
        }

        ($trimmed -split '\s{2,}')[0]
    }

    return @($models | Where-Object { $_ })
}

function Test-OllamaModelPresent {
    param(
        [Parameter(Mandatory)]
        [string]$Model
    )

    $models = Get-OllamaLocalModelNames
    if ($models -contains $Model) {
        return $true
    }

    $withLatest = if ($Model -match ':') { $Model } else { "$Model`:latest" }
    if ($models -contains $withLatest) {
        return $true
    }

    if ($Model -like '*:latest') {
        $withoutLatest = $Model -replace ':latest$', ''
        return $models -contains $withoutLatest
    }

    return $false
}

function Invoke-LlmPreflightCheck {
    [CmdletBinding()]
    param(
        [int]$MinBatteryPercent = 40,
        [double]$MinFreeMemoryGB = 4,
        [switch]$RequireAC,
        [string]$Model,
        [string]$ResultsPath
    )

    $checks = [System.Collections.Generic.List[object]]::new()
    $overallSafe = $true

    $battery = Get-BatteryStatusInfo
    if ($RequireAC) {
        $ok = (-not $battery.HasBattery) -or $battery.OnAcPower
        $checks.Add([pscustomobject]@{
            Name    = 'ACPower'
            Passed  = $ok
            Details = if ($battery.HasBattery) { "On AC power: $($battery.OnAcPower)" } else { 'No battery detected.' }
        })
        if (-not $ok) { $overallSafe = $false }
    }

    if ($battery.HasBattery) {
        $batteryOk = $battery.BatteryPercent -ge $MinBatteryPercent
        $checks.Add([pscustomobject]@{
            Name    = 'BatteryPercent'
            Passed  = $batteryOk
            Details = "Battery at $($battery.BatteryPercent)%."
        })
        if (-not $batteryOk) { $overallSafe = $false }
    }

    $memory = Get-MemoryStatusInfo
    $memoryOk = $memory.FreeGB -ge $MinFreeMemoryGB
    $checks.Add([pscustomobject]@{
        Name    = 'FreeMemory'
        Passed  = $memoryOk
        Details = ("Free {0} GB / Total {1} GB ({2}% used)." -f $memory.FreeGB, $memory.TotalGB, $memory.UsedPercent)
    })
    if (-not $memoryOk) { $overallSafe = $false }

    $rebootPending = Test-PendingReboot
    $checks.Add([pscustomobject]@{
        Name    = 'PendingReboot'
        Passed  = -not $rebootPending
        Details = if ($rebootPending) { 'A Windows reboot appears to be pending.' } else { 'No pending reboot detected.' }
    })

    $ollamaInstalled = Test-OllamaInstalled
    $checks.Add([pscustomobject]@{
        Name    = 'OllamaInstalled'
        Passed  = $ollamaInstalled
        Details = if ($ollamaInstalled) { 'ollama command found.' } else { 'ollama command not found.' }
    })
    if (-not $ollamaInstalled) { $overallSafe = $false }

    $ollamaReachable = $false
    if ($ollamaInstalled) {
        $ollamaReachable = Test-OllamaReachable
    }
    $checks.Add([pscustomobject]@{
        Name    = 'OllamaReachable'
        Passed  = $ollamaReachable
        Details = if ($ollamaReachable) { 'Ollama HTTP API reachable.' } else { 'Ollama HTTP API not reachable on localhost:11434.' }
    })
    if (-not $ollamaReachable) { $overallSafe = $false }

    if ($Model) {
        $modelOk = Test-OllamaModelPresent -Model $Model
        $checks.Add([pscustomobject]@{
            Name    = 'ModelPresent'
            Passed  = $modelOk
            Details = if ($modelOk) { "Model '$Model' exists locally." } else { "Model '$Model' is not present locally." }
        })
        if (-not $modelOk) { $overallSafe = $false }
    }

    if ($ResultsPath) {
        try {
            Ensure-Directory -Path $ResultsPath
            $checks.Add([pscustomobject]@{
                Name    = 'ResultsPath'
                Passed  = $true
                Details = "Results directory ready: $ResultsPath"
            })
        } catch {
            $checks.Add([pscustomobject]@{
                Name    = 'ResultsPath'
                Passed  = $false
                Details = $_.Exception.Message
            })
            $overallSafe = $false
        }
    }

    $ollamaProcesses = @(Get-CimInstance Win32_Process -Filter "Name = 'ollama.exe'" -ErrorAction SilentlyContinue)
    $duplicateHeavy = $ollamaProcesses.Count -gt 2
    $pullDetected = $false
    foreach ($process in $ollamaProcesses) {
        if ($process.CommandLine -and $process.CommandLine -match '\spull\s') {
            $pullDetected = $true
            break
        }
    }

    $checks.Add([pscustomobject]@{
        Name    = 'HeavyOllamaActivity'
        Passed  = -not ($duplicateHeavy -or $pullDetected)
        Details = if ($duplicateHeavy -or $pullDetected) {
            "Ollama activity detected. Process count: $($ollamaProcesses.Count). Pull active: $pullDetected."
        } else {
            "Ollama process count: $($ollamaProcesses.Count)."
        }
    })
    if ($duplicateHeavy -or $pullDetected) { $overallSafe = $false }

    $currentDrive = Get-PSDrive -Name ([System.IO.Path]::GetPathRoot((Get-Location).Path).TrimEnd('\').TrimEnd(':'))
    $diskOk = $currentDrive.Free -ge 5GB
    $checks.Add([pscustomobject]@{
        Name    = 'DiskFree'
        Passed  = $diskOk
        Details = ("Free disk: {0} GB on {1}" -f [math]::Round($currentDrive.Free / 1GB, 2), $currentDrive.Root)
    })
    if (-not $diskOk) { $overallSafe = $false }

    return [pscustomobject]@{
        Safe         = $overallSafe
        Checks       = @($checks)
        Battery      = $battery
        Memory       = $memory
        Windows      = Get-WindowsVersionSummary
        PowerScheme  = Get-ActivePowerSchemeInfo
        Timestamp    = (Get-Date).ToString('o')
        IsAdmin      = Test-IsAdministrator
    }
}

function Write-JsonLines {
    param(
        [Parameter(Mandatory)]
        [object[]]$InputObject,
        [Parameter(Mandatory)]
        [string]$Path
    )

    $dir = Split-Path -Parent $Path
    if ($dir) {
        Ensure-Directory -Path $dir
    }

    foreach ($item in $InputObject) {
        ($item | ConvertTo-Json -Depth 10 -Compress) | Add-Content -Path $Path
    }
}

function Invoke-OllamaGenerateBenchmark {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Model,
        [Parameter(Mandatory)]
        [string]$Prompt,
        [int]$NumPredict = 128,
        [int]$NumThread = 0,
        [int]$NumCtx = 2048,
        [int]$NumBatch = 128,
        [double]$Temperature = 0,
        [int]$RunIndex = 1,
        [bool]$Warmup = $false
    )

    $options = @{
        temperature = $Temperature
        num_predict = $NumPredict
        num_ctx     = $NumCtx
        num_batch   = $NumBatch
    }

    if ($NumThread -gt 0) {
        $options.num_thread = $NumThread
    }

    $payload = @{
        model   = $Model
        prompt  = $Prompt
        stream  = $false
        options = $options
    } | ConvertTo-Json -Depth 6

    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $response = Invoke-RestMethod `
        -Uri 'http://localhost:11434/api/generate' `
        -Method Post `
        -ContentType 'application/json' `
        -Body $payload `
        -TimeoutSec 1800
    $stopwatch.Stop()

    $promptTokPerSec = if ($response.prompt_eval_duration -gt 0) {
        $response.prompt_eval_count / ($response.prompt_eval_duration / 1e9)
    } else {
        0
    }

    $evalTokPerSec = if ($response.eval_duration -gt 0) {
        $response.eval_count / ($response.eval_duration / 1e9)
    } else {
        0
    }

    $totalTokPerSec = if ($response.total_duration -gt 0) {
        ($response.prompt_eval_count + $response.eval_count) / ($response.total_duration / 1e9)
    } else {
        0
    }

    [pscustomobject]@{
        Timestamp               = (Get-Date).ToString('o')
        Model                   = $Model
        Prompt                  = $Prompt
        RunIndex                = $RunIndex
        Warmup                  = $Warmup
        NumPredict              = $NumPredict
        NumThread               = $NumThread
        NumCtx                  = $NumCtx
        NumBatch                = $NumBatch
        Temperature             = $Temperature
        PromptEvalCount         = [int]$response.prompt_eval_count
        PromptEvalDurationNs    = [double]$response.prompt_eval_duration
        PromptTokPerSec         = [math]::Round($promptTokPerSec, 4)
        EvalCount               = [int]$response.eval_count
        EvalDurationNs          = [double]$response.eval_duration
        EvalTokPerSec           = [math]::Round($evalTokPerSec, 4)
        TotalDurationNs         = [double]$response.total_duration
        LoadDurationNs          = [double]$response.load_duration
        WallClockSeconds        = [math]::Round($stopwatch.Elapsed.TotalSeconds, 4)
        GeneratedChars          = if ($response.response) { $response.response.Length } else { 0 }
        TotalTokPerSec          = [math]::Round($totalTokPerSec, 4)
        DoneReason              = $response.done_reason
    }
}

function Set-OllamaPrioritySafely {
    [CmdletBinding()]
    param(
        [ValidateSet('Normal', 'AboveNormal', 'High')]
        [string]$Priority = 'Normal'
    )

    $processes = @(Get-Process -Name ollama -ErrorAction SilentlyContinue)
    if (-not $processes) {
        Write-Host "ollama.exe is not running; skipping priority update."
        return $false
    }

    foreach ($process in $processes) {
        try {
            $process.PriorityClass = $Priority
        } catch {
            Write-Warning ("Could not set priority for ollama.exe PID {0}: {1}" -f $process.Id, $_.Exception.Message)
        }
    }

    return $true
}

function Stop-OllamaPullProcesses {
    $stopped = [System.Collections.Generic.List[int]]::new()
    $processes = @(Get-CimInstance Win32_Process -Filter "Name = 'ollama.exe'" -ErrorAction SilentlyContinue)
    foreach ($process in $processes) {
        if (-not $process.CommandLine) {
            continue
        }

        if ($process.CommandLine -match '\spull\s') {
            try {
                Stop-Process -Id $process.ProcessId -Force
                $stopped.Add($process.ProcessId)
            } catch {
                Write-Warning ("Could not stop Ollama pull process PID {0}: {1}" -f $process.ProcessId, $_.Exception.Message)
            }
        }
    }

    return @($stopped)
}

function Invoke-OllamaStop {
    param(
        [Parameter(Mandatory)]
        [string]$Model,
        [int]$TimeoutSeconds = 15
    )

    if (-not (Test-OllamaInstalled)) {
        return
    }

    try {
        $ollamaPath = (Get-Command ollama).Source
        $process = Start-Process -FilePath $ollamaPath -ArgumentList @('stop', $Model) -PassThru -WindowStyle Hidden
        if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
            try {
                Stop-Process -Id $process.Id -Force
            } catch {
            }
            Write-Warning "Timed out waiting for 'ollama stop $Model'; continuing."
        }
    } catch {
        Write-Verbose ("ollama stop failed for {0}: {1}" -f $Model, $_.Exception.Message)
    }
}

function Get-StabilityScore {
    param(
        [double]$Median,
        [double]$StdDev
    )

    return [math]::Round($Median - (0.5 * $StdDev), 4)
}

function Get-StatsSummary {
    param(
        [Parameter(Mandatory)]
        [double[]]$Values
    )

    if (-not $Values -or $Values.Count -eq 0) {
        throw 'No values supplied.'
    }

    $sorted = $Values | Sort-Object
    $average = ($Values | Measure-Object -Average).Average
    $min = ($Values | Measure-Object -Minimum).Minimum
    $max = ($Values | Measure-Object -Maximum).Maximum
    $median = if ($sorted.Count % 2 -eq 1) {
        $sorted[[int]($sorted.Count / 2)]
    } else {
        ($sorted[($sorted.Count / 2) - 1] + $sorted[$sorted.Count / 2]) / 2
    }

    $variance = 0.0
    foreach ($value in $Values) {
        $variance += [math]::Pow(($value - $average), 2)
    }
    $variance = $variance / $Values.Count
    $stdDev = [math]::Sqrt($variance)

    [pscustomobject]@{
        Average = [math]::Round($average, 4)
        Median  = [math]::Round($median, 4)
        Min     = [math]::Round($min, 4)
        Max     = [math]::Round($max, 4)
        StdDev  = [math]::Round($stdDev, 4)
    }
}

function New-ResultPaths {
    param(
        [Parameter(Mandatory)]
        [string]$OutDir,
        [Parameter(Mandatory)]
        [string]$Prefix
    )

    Ensure-Directory -Path $OutDir
    $stamp = Get-LlmTimestamp
    [pscustomobject]@{
        Stamp      = $stamp
        JsonlPath  = Join-Path $OutDir "$Prefix-$stamp.jsonl"
        CsvPath    = Join-Path $OutDir "$Prefix-$stamp.csv"
        SummaryMd  = Join-Path $OutDir "$Prefix-$stamp-summary.md"
    }
}
