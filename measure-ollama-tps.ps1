param(
    [string]$Model,
    [string]$Prompt = "Write a clear explanation of what makes a language model fast at inference time. Use about 220 words.",
    [double]$Temperature = 0,
    [int]$NumPredict = 256,
    [int]$Runs = 3
)

$ErrorActionPreference = 'Stop'

if (-not $Model) {
    throw "Pass -Model with an Ollama model name."
}

$results = @()

for ($i = 1; $i -le $Runs; $i++) {
    $body = @{
        model   = $Model
        prompt  = $Prompt
        stream  = $false
        options = @{
            temperature = $Temperature
            num_predict = $NumPredict
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
        Run              = $i
        PromptTokens     = $response.prompt_eval_count
        PromptTokPerSec  = [math]::Round($promptTokPerSec, 2)
        GenTokens        = $response.eval_count
        GenTokPerSec     = [math]::Round($genTokPerSec, 2)
        LoadSeconds      = [math]::Round(($response.load_duration / 1e9), 2)
        TotalSeconds     = [math]::Round(($response.total_duration / 1e9), 2)
    }
}

$results | Format-Table -AutoSize

$avgPrompt = ($results | Measure-Object -Property PromptTokPerSec -Average).Average
$avgGen = ($results | Measure-Object -Property GenTokPerSec -Average).Average

[pscustomobject]@{
    Model               = $Model
    Runs                = $Runs
    AvgPromptTokPerSec  = [math]::Round($avgPrompt, 2)
    AvgGenTokPerSec     = [math]::Round($avgGen, 2)
} | Format-Table -AutoSize
