[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Model,
    [int]$NumThread = 8,
    [int[]]$NumCtxValues = @(1024, 2048, 4096, 8192),
    [int]$NumPredict = 128,
    [int]$Runs = 3,
    [string]$OutDir = '.\results-local',
    [int]$NumBatch = 128,
    [string]$Prompt = 'Explain why local inference performance depends on memory bandwidth.',
    [double]$Temperature = 0,
    [int]$CooldownSeconds = 15
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'tools\LlmLab.Common.ps1')

$resolvedOutDir = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutDir)
$paths = New-ResultPaths -OutDir $resolvedOutDir -Prefix "ctx-compare-$($Model -replace '[:/\\]', '_')"
$records = [System.Collections.Generic.List[object]]::new()
$summaries = [System.Collections.Generic.List[object]]::new()

foreach ($numCtx in $NumCtxValues) {
    $preflight = Invoke-LlmPreflightCheck -RequireAC -Model $Model -ResultsPath $resolvedOutDir
    if (-not $preflight.Safe) {
        $preflight.Checks | Select-Object Name, Passed, Details | Format-Table -Wrap -AutoSize
        throw "Preflight failed before num_ctx=$numCtx."
    }

    Write-Host ''
    Write-Host ("Testing num_ctx={0}" -f $numCtx)

    for ($runIndex = 1; $runIndex -le $Runs; $runIndex++) {
        $record = Invoke-OllamaGenerateBenchmark `
            -Model $Model `
            -Prompt $Prompt `
            -NumPredict $NumPredict `
            -NumThread $NumThread `
            -NumCtx $numCtx `
            -NumBatch $NumBatch `
            -Temperature $Temperature `
            -RunIndex $runIndex `
            -Warmup $false
        $records.Add($record)
        Write-Host ("  run {0}/{1} eval tok/s: {2}" -f $runIndex, $Runs, $record.EvalTokPerSec)
        Invoke-OllamaStop -Model $Model
        if ($runIndex -lt $Runs -and $CooldownSeconds -gt 0) {
            Start-Sleep -Seconds $CooldownSeconds
        }
    }

    $ctxRuns = @($records | Where-Object { $_.NumCtx -eq $numCtx })
    $stats = Get-StatsSummary -Values @($ctxRuns | ForEach-Object { [double]$_.EvalTokPerSec })
    $summaries.Add([pscustomobject]@{
        Model           = $Model
        NumThread       = $NumThread
        NumCtx          = $numCtx
        MedianEvalTokPs = $stats.Median
        AvgEvalTokPs    = $stats.Average
        StdDevEvalTokPs = $stats.StdDev
        Recommendation  = ''
    })
}

$records | Export-Csv -Path $paths.CsvPath -NoTypeInformation
Write-JsonLines -InputObject @($records) -Path $paths.JsonlPath

$recommended = $summaries | Sort-Object MedianEvalTokPs -Descending | Select-Object -First 1
foreach ($summary in $summaries) {
    if ($summary.NumCtx -eq $recommended.NumCtx) {
        $summary.Recommendation = 'Best current context length'
    }
}

$mdLines = @(
    '# Context Length Comparison',
    '',
    '| NumCtx | Median eval tok/s | Avg eval tok/s | Std dev | Note |',
    '| --- | --- | --- | --- | --- |'
)
foreach ($summary in $summaries | Sort-Object NumCtx) {
    $mdLines += "| $($summary.NumCtx) | $($summary.MedianEvalTokPs) | $($summary.AvgEvalTokPs) | $($summary.StdDevEvalTokPs) | $($summary.Recommendation) |"
}
$mdLines += ''
$mdLines += "Recommendation: use num_ctx=$($recommended.NumCtx) on this laptop unless your workload genuinely needs a larger context."
$mdLines | Set-Content -Path $paths.SummaryMd

Write-Host ''
$summaries | Sort-Object NumCtx | Format-Table NumCtx, MedianEvalTokPs, AvgEvalTokPs, StdDevEvalTokPs, Recommendation -AutoSize
Write-Host ''
Write-Host ("Recommended context length: {0}" -f $recommended.NumCtx)
