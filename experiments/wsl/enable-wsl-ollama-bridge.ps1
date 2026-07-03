[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$StatePath = '.\.wsl-ollama-bridge-state.json',
    [string]$FirewallRuleName = 'windows-local-llm-lab WSL Ollama API (experiment)',
    [string]$OllamaHost = '0.0.0.0:11434',
    [switch]$AllowLocalSubnetFallback,
    [switch]$ForceStateOverwrite
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot '..\..\tools\LlmLab.Common.ps1')

function ConvertTo-Ipv4NetworkCidr {
    param(
        [Parameter(Mandatory)]
        [string]$IpAddress,
        [Parameter(Mandatory)]
        [int]$PrefixLength
    )

    $bytes = [System.Net.IPAddress]::Parse($IpAddress).GetAddressBytes()
    if ($bytes.Length -ne 4) {
        throw "Only IPv4 addresses are supported for firewall scoping. Got '$IpAddress'."
    }

    $ipValue = [uint32]0
    for ($index = 0; $index -lt 4; $index++) {
        $shift = 8 * (3 - $index)
        $ipValue = $ipValue -bor ([uint32]$bytes[$index] -shl $shift)
    }

    $mask = if ($PrefixLength -eq 0) {
        [uint32]0
    } else {
        [uint32]::MaxValue -shl (32 - $PrefixLength)
    }
    $network = $ipValue -band $mask

    $networkBytes = [byte[]]@(
        (($network -shr 24) -band 0xFF),
        (($network -shr 16) -band 0xFF),
        (($network -shr 8) -band 0xFF),
        ($network -band 0xFF)
    )
    $networkIp = [System.Net.IPAddress]::new($networkBytes)
    return '{0}/{1}' -f $networkIp.IPAddressToString, $PrefixLength
}

function Get-WslFirewallRemoteAddresses {
    param(
        [switch]$AllowFallback
    )

    $addresses = @(Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias 'vEthernet (WSL)' -ErrorAction SilentlyContinue)
    if ($addresses.Count -gt 0) {
        return @(
            $addresses |
                Where-Object { $_.PrefixLength -ge 1 } |
                ForEach-Object { ConvertTo-Ipv4NetworkCidr -IpAddress $_.IPAddress -PrefixLength $_.PrefixLength } |
                Sort-Object -Unique
        )
    }

    if ($AllowFallback) {
        Write-Warning 'Could not detect the vEthernet (WSL) subnet. Falling back to LocalSubnet, which is broader than WSL-only.'
        return @('LocalSubnet')
    }

    throw "Could not detect the 'vEthernet (WSL)' subnet. Start WSL once or pass -AllowLocalSubnetFallback for a broader, less strict firewall scope."
}

if (-not (Test-IsAdministrator)) {
    throw 'This controlled experiment needs an elevated PowerShell session because it creates a scoped Windows Firewall rule.'
}

$repoRoot = Resolve-LlmLabRepoRoot -ScriptRoot $PSScriptRoot
$resolvedStatePath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($StatePath)
$stateDir = Split-Path -Parent $resolvedStatePath
if ($stateDir) {
    Ensure-Directory -Path $stateDir
}

if ((Test-Path -LiteralPath $resolvedStatePath) -and -not $ForceStateOverwrite) {
    throw "State file already exists at '$resolvedStatePath'. Run disable-wsl-ollama-bridge.ps1 first or pass -ForceStateOverwrite if you are intentionally replacing the prior experiment state."
}

$existingRule = @(Get-NetFirewallRule -DisplayName $FirewallRuleName -ErrorAction SilentlyContinue)
if ($existingRule.Count -gt 0 -and -not $ForceStateOverwrite) {
    throw "A firewall rule named '$FirewallRuleName' already exists. Use a different -FirewallRuleName or clean up the prior experiment first."
}

$remoteAddresses = @(Get-WslFirewallRemoteAddresses -AllowFallback:$AllowLocalSubnetFallback)
$previousUserHost = [Environment]::GetEnvironmentVariable('OLLAMA_HOST', 'User')
$state = [pscustomobject]@{
    Version                     = '1.0'
    Timestamp                   = (Get-Date).ToString('o')
    MachineName                 = $env:COMPUTERNAME
    WindowsVersion              = Get-WindowsVersionSummary
    FirewallRuleName            = $FirewallRuleName
    FirewallRemoteAddresses     = @($remoteAddresses)
    PreviousUserOllamaHost      = $previousUserHost
    PreviousUserOllamaHostSet   = -not [string]::IsNullOrEmpty($previousUserHost)
    RequestedOllamaHost         = $OllamaHost
}
$state | ConvertTo-Json -Depth 6 | Set-Content -Path $resolvedStatePath

Write-Host 'Prepared controlled WSL-to-Windows Ollama bridge experiment.'
Write-Host ("State file:         {0}" -f $resolvedStatePath)
Write-Host ("Requested host:     {0}" -f $OllamaHost)
Write-Host ("Firewall rule:      {0}" -f $FirewallRuleName)
Write-Host ("Remote addresses:   {0}" -f ($remoteAddresses -join ', '))
Write-Host ''

if ($PSCmdlet.ShouldProcess('User OLLAMA_HOST environment variable', "Set to '$OllamaHost'")) {
    [Environment]::SetEnvironmentVariable('OLLAMA_HOST', $OllamaHost, 'User')
}

if ($PSCmdlet.ShouldProcess('Windows Firewall', "Create inbound TCP 11434 allow rule '$FirewallRuleName'")) {
    New-NetFirewallRule `
        -DisplayName $FirewallRuleName `
        -Direction Inbound `
        -Action Allow `
        -Enabled True `
        -Profile Private `
        -Protocol TCP `
        -LocalPort 11434 `
        -RemoteAddress $remoteAddresses `
        -Description 'Temporary windows-local-llm-lab experiment for WSL access to the Windows-hosted Ollama API.' | Out-Null
}

Write-Host 'Next steps'
Write-Host '1. Restart Ollama so it picks up the new user-level OLLAMA_HOST setting.'
Write-Host '2. Re-run powershell -ExecutionPolicy Bypass -File .\tools\test-wsl-readiness.ps1'
Write-Host '3. When finished, restore the machine with:'
Write-Host '   powershell -ExecutionPolicy Bypass -File .\experiments\wsl\disable-wsl-ollama-bridge.ps1'
