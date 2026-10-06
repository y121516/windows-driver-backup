#Requires -Version 5.1
#Requires -RunAsAdministrator
[CmdletBinding()]
param([string]$Source = (Join-Path (Get-Location).Path 'drivers'))
$ErrorActionPreference = 'Stop'
try {
    $Source = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Source)
    $manifestPath = Join-Path $Source 'backup.json'
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) { throw 'backup.json not found. Use a backup produced by Backup-Drivers.ps1.' }
    $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    if ($manifest.SchemaVersion -ne 1 -or $manifest.Status -ne 'Complete') { throw 'Backup is incomplete or has an unsupported schema.' }
    $packages = Join-Path $Source 'packages'
    if (-not (Test-Path -LiteralPath $packages -PathType Container)) { throw 'packages directory not found.' }
    if (-not (Get-ChildItem -LiteralPath $packages -Filter '*.inf' -File -Recurse)) { throw 'No INF files found.' }
    & pnputil.exe /add-driver (Join-Path $packages '*.inf') /subdirs /install
    $result = $LASTEXITCODE
    if ($result -notin @(0, 3010)) { throw "Restore returned an error: $result. Review pnputil output; some packages may already be installed." }
    if ($result -eq 3010) { Write-Host 'Restart required. No automatic restart was requested.' }
    else { Write-Host 'Command completed. Review output and restart if requested.' }
    Write-Host 'After restarting, run: pnputil /enum-devices /problem'
    Write-Host 'Also check actual device functions; successful import does not prove every driver was applied.'
    exit $result
} catch {
    [Console]::Error.WriteLine($_.Exception.Message)
    exit 1
}
