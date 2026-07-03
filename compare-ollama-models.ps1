param(
    [string[]]$Models,
    [int]$Runs = 1,
    [int]$NumPredict = 32,
    [string]$Prompt = "Write a clear explanation of what makes a language model fast at inference time. Use about 120 words.",
    [double]$Temperature = 0,
    [int]$NumThread = 8,
    [string]$OutFile = ""
)

$ErrorActionPreference = 'Stop'

if (-not $Models -or $Models.Count -eq 0) {
    throw "Pass at least one model name with -Models."
}

$results = @()

foreach ($model in $Models) {
    for ($i = 1; $i -le $Runs; $i++) {
        $body = @{
            model   = $model
            prompt  = $Prompt
            stream  = $false
            options = @{
                temperature = $Temperature
                num_predict = $NumPredict
                num_thread  = $NumThread
            }
        } | ConvertTo-Json -Depth 5

        $response = Invoke-RestMethod `
            -Uri 'http://localhost:11434/api/generate' `
            -Method Post `
            -ContentType 'application/json' `
            -Body $body

        $promptTokPerSec = if ($response.prompt_eval_duration -gt 0) {
            $response.prompt_eval_count / ($response.prompt_eval_duration / 1e9)
        } else { 0 }

        $genTokPerSec = if ($response.eval_duration -gt 0) {
            $response.eval_count / ($response.eval_duration / 1e9)
        } else { 0 }

        $results += [pscustomobject]@{
            Model           = $model
            Run             = $i
            Threads         = $NumThread
            NumPredict      = $NumPredict
            PromptTokPerSec = [math]::Round($promptTokPerSec, 2)
            GenTokPerSec    = [math]::Round($genTokPerSec, 2)
            LoadSeconds     = [math]::Round(($response.load_duration / 1e9), 2)
            TotalSeconds    = [math]::Round(($response.total_duration / 1e9), 2)
        }
    }
}

$results | Format-Table -AutoSize

$summary = $results |
    Group-Object Model |
    ForEach-Object {
        [pscustomobject]@{
            Model              = $_.Name
            AvgPromptTokPerSec = [math]::Round(($_.Group | Measure-Object -Property PromptTokPerSec -Average).Average, 2)
            AvgGenTokPerSec    = [math]::Round(($_.Group | Measure-Object -Property GenTokPerSec -Average).Average, 2)
            AvgLoadSeconds     = [math]::Round(($_.Group | Measure-Object -Property LoadSeconds -Average).Average, 2)
        }
    } |
    Sort-Object AvgGenTokPerSec -Descending

""
$summary | Format-Table -AutoSize

if ($OutFile) {
    $parent = Split-Path -Parent $OutFile
    if ($parent -and -not (Test-Path $parent)) {
        New-Item -ItemType Directory -Path $parent | Out-Null
    }
    [pscustomobject]@{
        results = $results
        summary = $summary
    } | ConvertTo-Json -Depth 5 | Set-Content -Path $OutFile
}
