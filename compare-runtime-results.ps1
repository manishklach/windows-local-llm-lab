[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$PrimaryCsv,
    [Parameter(Mandatory)]
    [string]$SecondaryCsv,
    [string]$OutDir = '.\results-local'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-Median {
    param(
        [double[]]$Values
    )

    $sorted = @($Values | Sort-Object)
    if ($sorted.Count -eq 0) {
        throw 'No values provided.'
    }

    if ($sorted.Count % 2 -eq 1) {
        return [math]::Round($sorted[[int]($sorted.Count / 2)], 4)
    }

    return [math]::Round((($sorted[($sorted.Count / 2) - 1] + $sorted[$sorted.Count / 2]) / 2), 4)
}

function Get-Summary {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $rows = @(Import-Csv -Path $Path)
    if ($rows.Count -eq 0) {
        throw "CSV has no rows: $Path"
    }

    $measured = @($rows | Where-Object { -not $_.Warmup -or $_.Warmup -eq 'False' })
    $evalValues = @($measured | ForEach-Object { [double]$_.EvalTokPerSec })
    $promptValues = @($measured | ForEach-Object { [double]$_.PromptTokPerSec })

    [pscustomobject]@{
        Path            = $Path
        Label           = [System.IO.Path]::GetFileNameWithoutExtension($Path)
        Rows            = $rows.Count
        MeasuredRows    = $measured.Count
        AvgEvalTokPs    = [math]::Round((($evalValues | Measure-Object -Average).Average), 4)
        MedianEvalTokPs = Get-Median -Values $evalValues
        AvgPromptTokPs  = [math]::Round((($promptValues | Measure-Object -Average).Average), 4)
    }
}

$primaryPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($PrimaryCsv)
$secondaryPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($SecondaryCsv)
$resolvedOutDir = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutDir)
if (-not (Test-Path -LiteralPath $resolvedOutDir)) {
    New-Item -ItemType Directory -Path $resolvedOutDir -Force | Out-Null
}

$primary = Get-Summary -Path $primaryPath
$secondary = Get-Summary -Path $secondaryPath
$delta = [math]::Round($secondary.MedianEvalTokPs - $primary.MedianEvalTokPs, 4)
$deltaPercent = if ($primary.MedianEvalTokPs -ne 0) {
    [math]::Round(($delta / $primary.MedianEvalTokPs) * 100, 2)
} else {
    0
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$outPath = Join-Path $resolvedOutDir "runtime-compare-$stamp.md"

$lines = @(
    '# Runtime Comparison',
    '',
    '| Runtime | Avg eval tok/s | Median eval tok/s | Avg prompt tok/s | Measured runs |',
    '| --- | --- | --- | --- | --- |',
    "| $($primary.Label) | $($primary.AvgEvalTokPs) | $($primary.MedianEvalTokPs) | $($primary.AvgPromptTokPs) | $($primary.MeasuredRows) |",
    "| $($secondary.Label) | $($secondary.AvgEvalTokPs) | $($secondary.MedianEvalTokPs) | $($secondary.AvgPromptTokPs) | $($secondary.MeasuredRows) |",
    '',
    "| Delta vs primary | $deltaPercent% median eval tok/s | $delta |",
    '',
    "Recommendation: prefer the runtime with the higher median eval tok/s only if it is also stable and does not introduce hangs or thermal issues."
)
$lines | Set-Content -Path $outPath

$comparison = [pscustomobject]@{
    Primary         = $primary.Label
    Secondary       = $secondary.Label
    PrimaryMedian   = $primary.MedianEvalTokPs
    SecondaryMedian = $secondary.MedianEvalTokPs
    DeltaTokPs      = $delta
    DeltaPercent    = $deltaPercent
    SummaryPath     = $outPath
}

$comparison | Format-List
