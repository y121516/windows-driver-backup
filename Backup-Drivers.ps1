#Requires -Version 5.1
#Requires -RunAsAdministrator
[CmdletBinding()]
param(
    [string]$Destination = (Join-Path (Get-Location).Path 'drivers'),
    [ValidateSet('Assigned', 'All')][string]$Mode = 'Assigned'
)
$ErrorActionPreference = 'Stop'
try {
    $Destination = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Destination)
    if (Test-Path -LiteralPath $Destination) {
        if (-not (Test-Path -LiteralPath $Destination -PathType Container)) { throw 'Destination is not a directory.' }
        if (Get-ChildItem -LiteralPath $Destination -Force | Select-Object -First 1) {
            throw 'Destination is not empty. Choose a new directory; existing backups are never deleted.'
        }
    }
    $devices = @(& pnputil.exe /enum-devices)
    if ($LASTEXITCODE -ne 0) { throw "Device enumeration failed: $LASTEXITCODE" }
    $packages = @(& pnputil.exe /enum-drivers)
    if ($LASTEXITCODE -ne 0) { throw "Package enumeration failed: $LASTEXITCODE" }
    $names = @(
        foreach ($line in $devices) {
            if ($line -match ':\s*(oem\d+\.inf)\s*$') { $Matches[1].ToLowerInvariant() }
        }
    ) | Sort-Object -Unique
    if ($Mode -eq 'Assigned' -and -not $names) { throw 'No OEM INF names found. Check pnputil output; nothing exported.' }
    New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    $deviceDir = Join-Path $Destination 'packages'
    New-Item -ItemType Directory -Path $deviceDir | Out-Null
    $devices | Set-Content -LiteralPath (Join-Path $Destination 'devices.txt') -Encoding UTF8
    $packages | Set-Content -LiteralPath (Join-Path $Destination 'driver-packages.txt') -Encoding UTF8
    $manifest = [ordered]@{
        SchemaVersion = 1
        CreatedAt = (Get-Date).ToString('o')
        ComputerName = $env:COMPUTERNAME
        OSVersion = [Environment]::OSVersion.VersionString
        Mode = $Mode
        Status = 'Incomplete'
        ExportedInfNames = @()
    }
    $manifestPath = Join-Path $Destination 'backup.json'
    $manifest | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $manifestPath -Encoding UTF8
    $exported = @()
    if ($Mode -eq 'All') {
        & pnputil.exe /export-driver '*' $deviceDir
        if ($LASTEXITCODE -ne 0) { throw "Export failed: $LASTEXITCODE" }
    } else {
        Write-Host "Selected: $($names -join ', ')"
        foreach ($inf in $names) {
            $folder = Join-Path $deviceDir ([IO.Path]::GetFileNameWithoutExtension($inf))
            New-Item -ItemType Directory -Path $folder | Out-Null
            & pnputil.exe /export-driver $inf $folder
            if ($LASTEXITCODE -ne 0) { throw "Export failed for ${inf}: $LASTEXITCODE" }
            if (-not (Get-ChildItem -LiteralPath $folder -Filter '*.inf' -File -Recurse)) { throw "No INF exported for $inf" }
            $exported += $inf
        }
    }
    if (-not (Get-ChildItem -LiteralPath $deviceDir -Filter '*.inf' -File -Recurse)) { throw 'No INF files exported.' }
    $manifest.ExportedInfNames = @($exported)
    $manifest.Status = 'Complete'
    $manifest | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $manifestPath -Encoding UTF8
    Write-Host "Backup complete: $Destination"
    exit 0
} catch {
    [Console]::Error.WriteLine($_.Exception.Message)
    exit 1
}
