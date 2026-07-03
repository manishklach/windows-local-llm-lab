[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$StatePath = '.\.wsl-ollama-bridge-state.json',
    [switch]$DeleteStateAfterRestore
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot '..\..\tools\LlmLab.Common.ps1')

if (-not (Test-IsAdministrator)) {
    throw 'This restore script needs an elevated PowerShell session because it removes the scoped Windows Firewall rule.'
}

$resolvedStatePath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($StatePath)
if (-not (Test-Path -LiteralPath $resolvedStatePath)) {
    throw "Could not find experiment state at '$resolvedStatePath'."
}

$state = Get-Content -Raw -Path $resolvedStatePath | ConvertFrom-Json

Write-Host 'Restoring controlled WSL-to-Windows Ollama bridge experiment state.'
Write-Host ("State file:         {0}" -f $resolvedStatePath)
Write-Host ("Firewall rule:      {0}" -f $state.FirewallRuleName)
Write-Host ''

if ($state.PreviousUserOllamaHostSet) {
    if ($PSCmdlet.ShouldProcess('User OLLAMA_HOST environment variable', "Restore previous value '$($state.PreviousUserOllamaHost)'")) {
        [Environment]::SetEnvironmentVariable('OLLAMA_HOST', [string]$state.PreviousUserOllamaHost, 'User')
    }
} else {
    if ($PSCmdlet.ShouldProcess('User OLLAMA_HOST environment variable', 'Remove temporary experiment override')) {
        [Environment]::SetEnvironmentVariable('OLLAMA_HOST', $null, 'User')
    }
}

$existingRule = @(Get-NetFirewallRule -DisplayName $state.FirewallRuleName -ErrorAction SilentlyContinue)
if ($existingRule.Count -gt 0) {
    if ($PSCmdlet.ShouldProcess('Windows Firewall', "Remove rule '$($state.FirewallRuleName)'")) {
        $existingRule | Remove-NetFirewallRule
    }
} else {
    Write-Warning ("Firewall rule '{0}' was not present at restore time." -f $state.FirewallRuleName)
}

if ($DeleteStateAfterRestore) {
    if ($PSCmdlet.ShouldProcess($resolvedStatePath, 'Delete experiment state file')) {
        Remove-Item -LiteralPath $resolvedStatePath -Force
    }
}

Write-Host 'Restore summary'
Write-Host ("User OLLAMA_HOST restored: {0}" -f $state.PreviousUserOllamaHostSet)
Write-Host ("Firewall rule removed:     {0}" -f ($existingRule.Count -gt 0))
Write-Host 'Restart Ollama again so it releases the temporary host binding and returns to its prior behavior.'
