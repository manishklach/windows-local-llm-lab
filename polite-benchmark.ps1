param(
    [string[]]$Models,
    [int]$NumPredict = 16,
    [int]$NumThread = 8,
    [int]$CooldownSeconds = 8,
    [string]$Prompt = "Explain in about 80 words what makes language model inference fast.",
    [double]$Temperature = 0,
    [string]$OutFile = ""
)

$ErrorActionPreference = 'Stop'

if (-not $Models -or $Models.Count -eq 0) {
    throw "Pass at least one model name with -Models."
}

$results = @()

foreach ($model in $Models) {
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
        Threads         = $NumThread
        NumPredict      = $NumPredict
        PromptTokPerSec = [math]::Round($promptTokPerSec, 2)
        GenTokPerSec    = [math]::Round($genTokPerSec, 2)
        LoadSeconds     = [math]::Round(($response.load_duration / 1e9), 2)
        TotalSeconds    = [math]::Round(($response.total_duration / 1e9), 2)
    }

    ollama stop $model | Out-Null
    Start-Sleep -Seconds $CooldownSeconds
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
