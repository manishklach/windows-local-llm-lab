[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Model,
    [int[]]$ThreadCounts = @(4, 5, 6, 7, 8),
    [int[]]$NumCtxValues = @(1024, 2048, 4096),
    [int[]]$NumBatchValues = @(64, 128, 256),
    [int]$NumPredict = 128,
    [int]$Runs = 3,
    [int]$WarmupRuns = 1,
    [int]$CooldownSeconds = 20,
    [string]$OutDir = '.\results-local',
    [string]$Prompt = 'Explain why local inference performance depends on memory bandwidth.',
    [double]$Temperature = 0
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'tools\LlmLab.Common.ps1')

$resolvedOutDir = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutDir)
$paths = New-ResultPaths -OutDir $resolvedOutDir -Prefix "sweep-$($Model -replace '[:/\\]', '_')"
$allRecords = [System.Collections.Generic.List[object]]::new()
$summaries = [System.Collections.Generic.List[object]]::new()

foreach ($threadCount in $ThreadCounts) {
    foreach ($numCtx in $NumCtxValues) {
        foreach ($numBatch in $NumBatchValues) {
            $preflight = Invoke-LlmPreflightCheck -RequireAC -Model $Model -ResultsPath $resolvedOutDir
            if (-not $preflight.Safe) {
                $preflight.Checks | Select-Object Name, Passed, Details | Format-Table -Wrap -AutoSize
                throw "Preflight failed before config thread=$threadCount ctx=$numCtx batch=$numBatch."
            }

            Write-Host ''
            Write-Host ("Testing threads={0}, ctx={1}, batch={2}" -f $threadCount, $numCtx, $numBatch)

            for ($warmupIndex = 1; $warmupIndex -le $WarmupRuns; $warmupIndex++) {
                $record = Invoke-OllamaGenerateBenchmark `
                    -Model $Model `
                    -Prompt $Prompt `
                    -NumPredict $NumPredict `
                    -NumThread $threadCount `
                    -NumCtx $numCtx `
                    -NumBatch $numBatch `
                    -Temperature $Temperature `
                    -RunIndex $warmupIndex `
                    -Warmup $true
                $allRecords.Add($record)
                Write-Host ("  warmup eval tok/s: {0}" -f $record.EvalTokPerSec)
                Invoke-OllamaStop -Model $Model
                if ($CooldownSeconds -gt 0) {
                    Start-Sleep -Seconds $CooldownSeconds
                }
            }

            $measuredRecords = [System.Collections.Generic.List[object]]::new()
            for ($runIndex = 1; $runIndex -le $Runs; $runIndex++) {
                $record = Invoke-OllamaGenerateBenchmark `
                    -Model $Model `
                    -Prompt $Prompt `
                    -NumPredict $NumPredict `
                    -NumThread $threadCount `
                    -NumCtx $numCtx `
                    -NumBatch $numBatch `
                    -Temperature $Temperature `
                    -RunIndex $runIndex `
                    -Warmup $false
                $allRecords.Add($record)
                $measuredRecords.Add($record)
                Write-Host ("  run {0}/{1} eval tok/s: {2}" -f $runIndex, $Runs, $record.EvalTokPerSec)
                Invoke-OllamaStop -Model $Model
                if ($runIndex -lt $Runs -and $CooldownSeconds -gt 0) {
                    Start-Sleep -Seconds $CooldownSeconds
                }
            }

            $stats = Get-StatsSummary -Values @($measuredRecords | ForEach-Object { [double]$_.EvalTokPerSec })
            $variancePercent = if ($stats.Median -gt 0) { [math]::Round(($stats.StdDev / $stats.Median) * 100, 2) } else { 0 }
            $summaries.Add([pscustomobject]@{
                Model            = $Model
                NumThread        = $threadCount
                NumCtx           = $numCtx
                NumBatch         = $numBatch
                Runs             = $Runs
                MedianEvalTokPs  = $stats.Median
                AvgEvalTokPs     = $stats.Average
                StdDevEvalTokPs  = $stats.StdDev
                StabilityScore   = Get-StabilityScore -Median $stats.Median -StdDev $stats.StdDev
                VariancePercent  = $variancePercent
                HighVariance     = ($variancePercent -gt 10)
            })

            if ($CooldownSeconds -gt 0) {
                Start-Sleep -Seconds $CooldownSeconds
            }
        }
    }
}

$allRecords | Export-Csv -Path $paths.CsvPath -NoTypeInformation
Write-JsonLines -InputObject @($allRecords) -Path $paths.JsonlPath

$byMedian = @($summaries | Sort-Object MedianEvalTokPs -Descending | Select-Object -First 10)
$byStability = @($summaries | Sort-Object StabilityScore -Descending | Select-Object -First 10)
$recommended = $byStability | Select-Object -First 1

$summaryMd = [System.Collections.Generic.List[string]]::new()
$summaryMd.Add('# Sweep Summary')
$summaryMd.Add('')
$summaryMd.Add('## Top 10 configs by median eval tok/s')
$summaryMd.Add('')
$summaryMd.Add('| Threads | Ctx | Batch | Median eval tok/s | Std dev | Variance % |')
$summaryMd.Add('| --- | --- | --- | --- | --- | --- |')
foreach ($item in $byMedian) {
    $summaryMd.Add("| $($item.NumThread) | $($item.NumCtx) | $($item.NumBatch) | $($item.MedianEvalTokPs) | $($item.StdDevEvalTokPs) | $($item.VariancePercent) |")
}
$summaryMd.Add('')
$summaryMd.Add('## Top 10 configs by stability-adjusted score')
$summaryMd.Add('')
$summaryMd.Add('| Threads | Ctx | Batch | Stability score | Median eval tok/s | Std dev |')
$summaryMd.Add('| --- | --- | --- | --- | --- | --- |')
foreach ($item in $byStability) {
    $summaryMd.Add("| $($item.NumThread) | $($item.NumCtx) | $($item.NumBatch) | $($item.StabilityScore) | $($item.MedianEvalTokPs) | $($item.StdDevEvalTokPs) |")
}
$summaryMd.Add('')
$summaryMd.Add('## Recommended config')
$summaryMd.Add('')
$summaryMd.Add("| Threads | Ctx | Batch | Stability score | Median eval tok/s |")
$summaryMd.Add("| --- | --- | --- | --- | --- |")
$summaryMd.Add("| $($recommended.NumThread) | $($recommended.NumCtx) | $($recommended.NumBatch) | $($recommended.StabilityScore) | $($recommended.MedianEvalTokPs) |")
$summaryMd | Set-Content -Path $paths.SummaryMd

Write-Host ''
Write-Host 'Top 10 configs by median eval tok/s'
$byMedian | Format-Table NumThread, NumCtx, NumBatch, MedianEvalTokPs, StdDevEvalTokPs, VariancePercent -AutoSize
Write-Host ''
Write-Host 'Top 10 configs by stability-adjusted score'
$byStability | Format-Table NumThread, NumCtx, NumBatch, StabilityScore, MedianEvalTokPs, StdDevEvalTokPs -AutoSize
Write-Host ''
Write-Host 'Recommended config'
$recommended | Format-List
