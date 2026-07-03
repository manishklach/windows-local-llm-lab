[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string[]]$Models,
    [int]$NumThread = 8,
    [int]$NumCtx = 2048,
    [int]$NumPredict = 128,
    [int]$Runs = 3,
    [string]$OutDir = '.\results-local',
    [string]$Prompt = 'Explain why local inference performance depends on memory bandwidth.',
    [double]$Temperature = 0,
    [switch]$PullMissing,
    [int]$CooldownSeconds = 20,
    [int]$NumBatch = 128
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'tools\LlmLab.Common.ps1')

$resolvedOutDir = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutDir)
$paths = New-ResultPaths -OutDir $resolvedOutDir -Prefix 'model-compare'
$records = [System.Collections.Generic.List[object]]::new()
$summaries = [System.Collections.Generic.List[object]]::new()

foreach ($model in $Models) {
    if (-not (Test-OllamaModelPresent -Model $model)) {
        if (-not $PullMissing) {
            Write-Warning "Skipping missing local model '$model'. Pass -PullMissing to allow automatic pull."
            continue
        }

        Write-Host "Pulling missing model $model"
        &(Get-Command ollama).Source pull $model
    }

    $preflight = Invoke-LlmPreflightCheck -RequireAC -Model $model -ResultsPath $resolvedOutDir
    if (-not $preflight.Safe) {
        $preflight.Checks | Select-Object Name, Passed, Details | Format-Table -Wrap -AutoSize
        throw "Preflight failed before model '$model'."
    }

    Write-Host ''
    Write-Host ("Testing model {0}" -f $model)

    $modelRuns = [System.Collections.Generic.List[object]]::new()
    for ($runIndex = 1; $runIndex -le $Runs; $runIndex++) {
        $record = Invoke-OllamaGenerateBenchmark `
            -Model $model `
            -Prompt $Prompt `
            -NumPredict $NumPredict `
            -NumThread $NumThread `
            -NumCtx $NumCtx `
            -NumBatch $NumBatch `
            -Temperature $Temperature `
            -RunIndex $runIndex `
            -Warmup $false
        $records.Add($record)
        $modelRuns.Add($record)
        Write-Host ("  run {0}/{1} eval tok/s: {2}" -f $runIndex, $Runs, $record.EvalTokPerSec)
        Invoke-OllamaStop -Model $model
        if ($runIndex -lt $Runs -and $CooldownSeconds -gt 0) {
            Start-Sleep -Seconds $CooldownSeconds
        }
    }

    $stats = Get-StatsSummary -Values @($modelRuns | ForEach-Object { [double]$_.EvalTokPerSec })
    $summaries.Add([pscustomobject]@{
        Model           = $model
        MedianEvalTokPs = $stats.Median
        AvgEvalTokPs    = $stats.Average
        StdDevEvalTokPs = $stats.StdDev
        NumThread       = $NumThread
        NumCtx          = $NumCtx
        NumBatch        = $NumBatch
    })

    if ($CooldownSeconds -gt 0) {
        Start-Sleep -Seconds $CooldownSeconds
    }
}

if ($records.Count -eq 0) {
    throw 'No model runs were executed.'
}

$records | Export-Csv -Path $paths.CsvPath -NoTypeInformation
Write-JsonLines -InputObject @($records) -Path $paths.JsonlPath

$ordered = @($summaries | Sort-Object MedianEvalTokPs -Descending)
$mdLines = @(
    '# Model Comparison',
    '',
    '| Model | Median eval tok/s | Avg eval tok/s | Std dev | Threads | NumCtx | NumBatch |',
    '| --- | --- | --- | --- | --- | --- | --- |'
)
foreach ($summary in $ordered) {
    $mdLines += "| $($summary.Model) | $($summary.MedianEvalTokPs) | $($summary.AvgEvalTokPs) | $($summary.StdDevEvalTokPs) | $($summary.NumThread) | $($summary.NumCtx) | $($summary.NumBatch) |"
}
$mdLines | Set-Content -Path $paths.SummaryMd

Write-Host ''
$ordered | Format-Table Model, MedianEvalTokPs, AvgEvalTokPs, StdDevEvalTokPs, NumThread, NumCtx, NumBatch -AutoSize
