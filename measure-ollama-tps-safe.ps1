[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Model,
    [string]$Prompt = 'Explain why local inference performance depends on memory bandwidth.',
    [int]$Runs = 5,
    [int]$WarmupRuns = 1,
    [int]$NumPredict = 128,
    [int]$NumThread = 8,
    [int]$NumCtx = 2048,
    [int]$NumBatch = 128,
    [int]$CooldownSeconds = 15,
    [string]$OutDir = '.\results-local',
    [ValidateSet('Normal', 'AboveNormal', 'High')]
    [string]$OllamaPriority = 'High',
    [double]$Temperature = 0
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'tools\LlmLab.Common.ps1')

$resolvedOutDir = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutDir)
$preflight = Invoke-LlmPreflightCheck -RequireAC -Model $Model -ResultsPath $resolvedOutDir
if (-not $preflight.Safe) {
    $preflight.Checks | Select-Object Name, Passed, Details | Format-Table -Wrap -AutoSize
    throw 'Preflight failed. Fix the issues above or run tools/preflight-llm-benchmark.ps1 directly for more detail.'
}

Set-OllamaPrioritySafely -Priority $OllamaPriority | Out-Null

$paths = New-ResultPaths -OutDir $resolvedOutDir -Prefix "measure-$($Model -replace '[:/\\]', '_')"
$records = [System.Collections.Generic.List[object]]::new()

Write-Host ''
Write-Host ("Benchmarking model {0} with threads={1}, ctx={2}, batch={3}, num_predict={4}" -f $Model, $NumThread, $NumCtx, $NumBatch, $NumPredict)

for ($warmupIndex = 1; $warmupIndex -le $WarmupRuns; $warmupIndex++) {
    Write-Host ("Warmup {0}/{1}" -f $warmupIndex, $WarmupRuns)
    $record = Invoke-OllamaGenerateBenchmark `
        -Model $Model `
        -Prompt $Prompt `
        -NumPredict $NumPredict `
        -NumThread $NumThread `
        -NumCtx $NumCtx `
        -NumBatch $NumBatch `
        -Temperature $Temperature `
        -RunIndex $warmupIndex `
        -Warmup $true
    $records.Add($record)
    Write-Host ("  eval tok/s: {0}" -f $record.EvalTokPerSec)
    Invoke-OllamaStop -Model $Model
    if ($CooldownSeconds -gt 0) {
        Start-Sleep -Seconds $CooldownSeconds
    }
}

for ($runIndex = 1; $runIndex -le $Runs; $runIndex++) {
    Write-Host ("Measured run {0}/{1}" -f $runIndex, $Runs)
    $record = Invoke-OllamaGenerateBenchmark `
        -Model $Model `
        -Prompt $Prompt `
        -NumPredict $NumPredict `
        -NumThread $NumThread `
        -NumCtx $NumCtx `
        -NumBatch $NumBatch `
        -Temperature $Temperature `
        -RunIndex $runIndex `
        -Warmup $false
    $records.Add($record)
    Write-Host ("  eval tok/s: {0} | load s: {1}" -f $record.EvalTokPerSec, [math]::Round($record.LoadDurationNs / 1e9, 2))
    Invoke-OllamaStop -Model $Model
    if ($runIndex -lt $Runs -and $CooldownSeconds -gt 0) {
        Start-Sleep -Seconds $CooldownSeconds
    }
}

$records | Export-Csv -Path $paths.CsvPath -NoTypeInformation
Write-JsonLines -InputObject @($records) -Path $paths.JsonlPath

$measured = @($records | Where-Object { -not $_.Warmup })
$stats = Get-StatsSummary -Values @($measured | ForEach-Object { [double]$_.EvalTokPerSec })
$bestRun = $measured | Sort-Object EvalTokPerSec -Descending | Select-Object -First 1
$variancePercent = if ($stats.Median -gt 0) { [math]::Round(($stats.StdDev / $stats.Median) * 100, 2) } else { 0 }

$summaryLines = @(
    '# Measure Summary',
    '',
    "| Metric | Value |",
    "| --- | --- |",
    "| Model | $Model |",
    "| Runs | $Runs |",
    "| Warmup runs | $WarmupRuns |",
    "| NumThread | $NumThread |",
    "| NumCtx | $NumCtx |",
    "| NumBatch | $NumBatch |",
    "| NumPredict | $NumPredict |",
    "| Avg eval tok/s | $($stats.Average) |",
    "| Median eval tok/s | $($stats.Median) |",
    "| Min eval tok/s | $($stats.Min) |",
    "| Max eval tok/s | $($stats.Max) |",
    "| Std dev | $($stats.StdDev) |",
    "| Variance % of median | $variancePercent |",
    "| Best run | Run $($bestRun.RunIndex) at $($bestRun.EvalTokPerSec) tok/s |"
)

if ($variancePercent -gt 10) {
    $summaryLines += "| Variance warning | High variance detected; thermal or background noise may be affecting results. |"
}

$summaryLines | Set-Content -Path $paths.SummaryMd

Write-Host ''
Write-Host 'Summary'
[pscustomobject]@{
    Model            = $Model
    AverageEvalTokPs = $stats.Average
    MedianEvalTokPs  = $stats.Median
    MinEvalTokPs     = $stats.Min
    MaxEvalTokPs     = $stats.Max
    StdDev           = $stats.StdDev
    BestRun          = $bestRun.RunIndex
    BestEvalTokPs    = $bestRun.EvalTokPerSec
    CsvPath          = $paths.CsvPath
    JsonlPath        = $paths.JsonlPath
    SummaryPath      = $paths.SummaryMd
} | Format-List
