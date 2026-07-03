param(
    [string]$Model,
    [int[]]$ThreadCounts = @(4, 8),
    [int[]]$NumPredictValues = @(32, 64),
    [string]$Prompt = "Write a clear explanation of what makes a language model fast at inference time. Use about 120 words.",
    [double]$Temperature = 0,
    [string]$OutFile = ""
)

$ErrorActionPreference = 'Stop'

if (-not $Model) {
    throw "Pass -Model with an Ollama model name."
}

$results = @()

foreach ($threads in $ThreadCounts) {
    foreach ($numPredict in $NumPredictValues) {
        $body = @{
            model   = $Model
            prompt  = $Prompt
            stream  = $false
            options = @{
                temperature = $Temperature
                num_predict = $numPredict
                num_thread  = $threads
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
            Model          = $Model
            Threads        = $threads
            NumPredict     = $numPredict
            PromptTokens   = $response.prompt_eval_count
            PromptTokPerSec= [math]::Round($promptTokPerSec, 2)
            GenTokens      = $response.eval_count
            GenTokPerSec   = [math]::Round($genTokPerSec, 2)
            LoadSeconds    = [math]::Round(($response.load_duration / 1e9), 2)
            TotalSeconds   = [math]::Round(($response.total_duration / 1e9), 2)
        }
    }
}

$results = $results | Sort-Object GenTokPerSec -Descending
$results | Format-Table -AutoSize

if ($OutFile) {
    $parent = Split-Path -Parent $OutFile
    if ($parent -and -not (Test-Path $parent)) {
        New-Item -ItemType Directory -Path $parent | Out-Null
    }
    $results | ConvertTo-Json -Depth 4 | Set-Content -Path $OutFile
}
