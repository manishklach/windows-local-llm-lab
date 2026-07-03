param(
    [switch]$Apply
)

$ErrorActionPreference = 'Stop'

$blobDir = Join-Path $env:USERPROFILE '.ollama\models\blobs'
if (-not (Test-Path $blobDir)) {
    throw "Ollama blob directory not found: $blobDir"
}

$partials = Get-ChildItem $blobDir -File | Where-Object { $_.Name -like '*-partial' } |
    Sort-Object Length -Descending |
    Select-Object FullName, Name, @{N='SizeGB';E={[math]::Round($_.Length / 1GB, 2)}}

if (-not $partials) {
    "No partial blobs found."
    exit 0
}

"Partial blobs:"
$partials | Format-Table -AutoSize

if (-not $Apply) {
    ""
    "Dry run only. Re-run with -Apply to remove the files above."
    exit 0
}

foreach ($partial in $partials) {
    Remove-Item -LiteralPath $partial.FullName -Force
}

""
"Removed partial blobs."
