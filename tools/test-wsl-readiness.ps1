[CmdletBinding()]
param(
    [string]$Distro,
    [string]$OllamaEndpoint
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-WslText {
    param(
        [Parameter(Mandatory)]
        [string[]]$Arguments
    )

    $output = & wsl.exe @Arguments 2>&1
    return (($output | Out-String) -replace "`0", '').Trim()
}

function Convert-WindowsPathToWslPath {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $resolved = [System.IO.Path]::GetFullPath($Path)
    if ($resolved -notmatch '^([A-Za-z]):\\(.+)$') {
        throw "Cannot convert path to WSL format: $resolved"
    }

    $drive = $matches[1].ToLowerInvariant()
    $rest = $matches[2] -replace '\\', '/'
    return "/mnt/$drive/$rest"
}

if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) {
    throw 'wsl.exe is not available on this Windows installation.'
}

$statusText = Get-WslText -Arguments @('--status')
$listText = Get-WslText -Arguments @('-l', '-v')

$lines = @($listText -split "`r?`n" | Where-Object { $_.Trim() })
$parsedDistros = foreach ($line in $lines | Select-Object -Skip 1) {
    $clean = $line.Trim().TrimStart('*').Trim()
    if (-not $clean) {
        continue
    }

    $parts = $clean -split '\s{2,}'
    if ($parts.Count -lt 3) {
        continue
    }

    [pscustomobject]@{
        Name    = $parts[0]
        State   = $parts[1]
        Version = $parts[2]
    }
}

if (-not $parsedDistros) {
    throw 'No WSL distributions were detected.'
}

$selected = if ($Distro) {
    $parsedDistros | Where-Object { $_.Name -eq $Distro } | Select-Object -First 1
} else {
    $parsedDistros | Select-Object -First 1
}

if (-not $selected) {
    throw "Requested distro '$Distro' was not found."
}

$checks = [System.Collections.Generic.List[object]]::new()
$checks.Add([pscustomobject]@{
    Name    = 'WSLInstalled'
    Passed  = $true
    Details = $statusText
})
$checks.Add([pscustomobject]@{
    Name    = 'SelectedDistro'
    Passed  = $true
    Details = "Using distro '$($selected.Name)' in state '$($selected.State)' with WSL version $($selected.Version)."
})

$pythonOkay = $false
try {
    $pythonVersion = Get-WslText -Arguments @('-d', $selected.Name, '--', 'bash', '-lc', 'python3 --version')
    $pythonOkay = $LASTEXITCODE -eq 0
} catch {
    $pythonVersion = $_.Exception.Message
}
$checks.Add([pscustomobject]@{
    Name    = 'Python3'
    Passed  = $pythonOkay
    Details = $pythonVersion
})

$curlOkay = $false
try {
    $curlVersion = Get-WslText -Arguments @('-d', $selected.Name, '--', 'bash', '-lc', 'curl --version | head -n 1')
    $curlOkay = $LASTEXITCODE -eq 0
} catch {
    $curlVersion = $_.Exception.Message
}
$checks.Add([pscustomobject]@{
    Name    = 'Curl'
    Passed  = $curlOkay
    Details = $curlVersion
})

$hostNetworkOkay = $false
try {
    $tempPyPath = Join-Path $env:TEMP 'qwen_windows_tps_lab_wsl_probe.py'
    $tempPy = @"
import sys, urllib.request

explicit = sys.argv[1] if len(sys.argv) > 1 else ""
if explicit:
    candidates = [explicit.rstrip("/")]
else:
    candidates = ["http://localhost:11434", "http://host.docker.internal:11434"]
    with open("/etc/resolv.conf", "r", encoding="utf-8") as handle:
        for line in handle:
            if line.startswith("nameserver "):
                candidates.append(f"http://{line.split()[1]}:11434")

last_error = ""
for endpoint in candidates:
    try:
        urllib.request.urlopen(endpoint + "/api/tags", timeout=3).read()
        print(f"reachable:{endpoint}")
        raise SystemExit(0)
    except Exception as exc:
        last_error = f"{endpoint} -> {exc}"

print(last_error)
raise SystemExit(1)
"@
    $tempPy | Set-Content -Path $tempPyPath
    $wslPyPath = Convert-WindowsPathToWslPath -Path $tempPyPath
    $networkArgs = @('-d', $selected.Name, '--', 'python3', $wslPyPath)
    if ($OllamaEndpoint) {
        $networkArgs += $OllamaEndpoint
    }
    $networkText = Get-WslText -Arguments $networkArgs
    Remove-Item -LiteralPath $tempPyPath -Force -ErrorAction SilentlyContinue
    $hostNetworkOkay = $LASTEXITCODE -eq 0
} catch {
    $networkText = $_.Exception.Message
}
$checks.Add([pscustomobject]@{
    Name    = 'WindowsOllamaFromWSL'
    Passed  = $hostNetworkOkay
    Details = $networkText
})

$checks | Format-Table -Wrap -AutoSize

if ($checks.Where({ -not $_.Passed }).Count -gt 0) {
    exit 1
}
