[CmdletBinding()]
param(
    [switch]$Rollback
)

$ErrorActionPreference = 'Stop'

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = [Security.Principal.WindowsPrincipal]::new($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Run this script from an elevated PowerShell window (Run as administrator).'
}

if (Get-Process -Name 'L2' -ErrorAction SilentlyContinue) {
    throw 'Close Lineage II (L2.exe) before changing the 32-bit D3D12 UMD.'
}

$classRoot = 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}'
if (-not (Test-Path -LiteralPath $classRoot)) {
    throw "Display class registry key not found: $classRoot"
}

$found = @(
    foreach ($key in Get-ChildItem -LiteralPath $classRoot -ErrorAction Stop) {
        $properties = Get-ItemProperty -LiteralPath $key.PSPath -ErrorAction SilentlyContinue
        foreach ($entry in @($properties.UserModeDriverNameWow)) {
            if ($null -eq $entry) { continue }
            $candidate = [Environment]::ExpandEnvironmentVariables([string]$entry)
            if ($candidate -match '(?i)\\wow64\\d3d12\\amdgpu_wddm_d3d12(?:32)?\.dll$') {
                [pscustomobject]@{
                    RegistryKey = $key.PSPath
                    Target = $candidate
                }
            }
        }
    }
) | Sort-Object -Property Target -Unique

if ($found.Count -ne 1) {
    throw "Expected one registered 32-bit Nagi D3D12 UMD path, found $($found.Count). Refusing to guess."
}

$target = $found[0].Target
if (-not (Test-Path -LiteralPath $target -PathType Leaf)) {
    throw "Registered D3D12 UMD does not exist: $target"
}

if ($Rollback) {
    $backups = @(Get-ChildItem -LiteralPath (Split-Path -Parent $target) -File |
        Where-Object { $_.Name -like ((Split-Path -Leaf $target) + '.bak-bd253-*') } |
        Sort-Object -Property LastWriteTimeUtc -Descending)
    if ($backups.Count -eq 0) {
        throw "No BD-253 backup found beside: $target"
    }
    Copy-Item -LiteralPath $backups[0].FullName -Destination $target -Force
    Write-Host "Restored: $target"
    Write-Host "From backup: $($backups[0].FullName)"
    exit 0
}

$source = Join-Path $PSScriptRoot 'amdgpu_wddm_d3d12.dll'
if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
    throw "Place the built x86 DLL beside this script: $source"
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backup = "$target.bak-bd253-$stamp"
$sourceHash = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash
$targetHash = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash

Copy-Item -LiteralPath $target -Destination $backup
try {
    Copy-Item -LiteralPath $source -Destination $target -Force
    $installedHash = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash
    if ($installedHash -ne $sourceHash) {
        throw 'The copied DLL hash does not match the build artifact.'
    }
}
catch {
    Copy-Item -LiteralPath $backup -Destination $target -Force
    throw
}

Write-Host 'BD-253 x86 D3D12 UMD installed.'
Write-Host "Target: $target"
Write-Host "Previous DLL backup: $backup"
Write-Host "Previous SHA256: $targetHash"
Write-Host "Installed SHA256: $installedHash"
Write-Host 'Rollback: run this script again with -Rollback'
