[CmdletBinding()]
param([switch]$Rollback, [string]$BackupDirectory)
$ErrorActionPreference = 'Stop'

function Copy-Bd253File([string]$Source, [string]$Target) {
    # Backup mode bypasses file ACLs using administrator backup/restore privileges.
    # Copy only this file's data, attributes and timestamps. Never copy security or a directory tree.
    $stage = Join-Path ([IO.Path]::GetTempPath()) ('bc250-stage-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $stage -ErrorAction Stop | Out-Null
    try {
        $name = Split-Path -Leaf $Target
        Copy-Item -LiteralPath $Source -Destination (Join-Path $stage $name) -ErrorAction Stop
        & "$env:SystemRoot\System32\robocopy.exe" $stage (Split-Path -Parent $Target) $name /B /COPY:DAT /IS /IT /R:0 /W:0 /NP /NFL /NDL /NJH /NJS | Out-Host
        $copyExit = $LASTEXITCODE
        if ($copyExit -ge 8) { throw "Robocopy failed with code $copyExit. No permissions were changed." }
        if ((Get-FileHash -LiteralPath $Source -Algorithm SHA256).Hash -ne (Get-FileHash -LiteralPath $Target -Algorithm SHA256).Hash) {
            throw 'Copied DLL hash does not match the source.'
        }
    } finally {
        Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Install-Bd253File([string]$Source, [string]$Target, [string]$BackupRoot) {
    $sourceHash = (Get-FileHash -LiteralPath $Source -Algorithm SHA256).Hash
    $targetHash = (Get-FileHash -LiteralPath $Target -Algorithm SHA256).Hash
    if ($sourceHash -eq $targetHash) {
        Write-Host 'This DLL is already installed. No new backup was created.'
        return
    }
    $folder = Join-Path $BackupRoot ((Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $folder -Force | Out-Null
    $backup = Join-Path $folder (Split-Path -Leaf $Target)
    Copy-Item -LiteralPath $Target -Destination $backup -ErrorAction Stop
    if ((Get-FileHash -LiteralPath $backup -Algorithm SHA256).Hash -ne $targetHash) { throw 'Backup hash mismatch. Driver was not changed.' }
    [ordered]@{ Target = $Target; PreviousSha256 = $targetHash; CandidateSha256 = $sourceHash; CreatedUtc = [DateTime]::UtcNow.ToString('o') } |
        ConvertTo-Json | Set-Content -LiteralPath (Join-Path $folder 'backup.json') -Encoding UTF8
    Write-Host "Verified backup: $folder"
    try {
        Copy-Bd253File $Source $Target
    } catch {
        $installError = $_
        try {
            if (-not (Test-Path -LiteralPath $Target) -or (Get-FileHash -LiteralPath $Target -Algorithm SHA256).Hash -ne $targetHash) {
                Copy-Bd253File $backup $Target
            }
        } catch {
            throw "Installation AND automatic rollback failed. Backup: $folder. Install: $installError. Restore: $_"
        }
        throw "Installation failed. Previous DLL is intact/restored. Backup: $folder. Error: $installError"
    }
    Write-Host 'BD-253 x86 D3D12 UMD installed.'
    Write-Host "Target: $Target"
    Write-Host "Previous DLL backup: $folder"
    Write-Host "Previous SHA256: $targetHash"
    Write-Host "Installed SHA256: $sourceHash"
    Write-Host "Rollback: run this script with -Rollback -BackupDirectory `"$folder`""
}

function Restore-Bd253File([string]$Target, [string]$Folder) {
    $record = Get-Content -LiteralPath (Join-Path $Folder 'backup.json') -Raw | ConvertFrom-Json
    if ($record.Target -ne $Target) { throw 'Backup belongs to a different registered DLL. Refusing to restore.' }
    $backup = Join-Path $Folder (Split-Path -Leaf $Target)
    if ((Get-FileHash -LiteralPath $backup -Algorithm SHA256).Hash -ne $record.PreviousSha256) {
        throw 'Backup hash mismatch. Refusing to restore.'
    }
    Copy-Bd253File $backup $Target
    Write-Host "Restored: $Target"
    Write-Host "From verified backup: $Folder"
}

# Dot-sourcing exposes only file operations for isolated Windows regression tests.
if ($MyInvocation.InvocationName -eq '.') { return }
if (-not [Environment]::Is64BitProcess) { throw 'Use 64-bit Windows PowerShell as administrator.' }
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = [Security.Principal.WindowsPrincipal]::new($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw 'Run this script from an elevated PowerShell window (Run as administrator).' }
if (Get-Process -Name 'L2' -ErrorAction SilentlyContinue) { throw 'Close Lineage II (L2.exe) before changing the 32-bit D3D12 UMD.' }
$classRoot = 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}'
if (-not (Test-Path -LiteralPath $classRoot)) { throw "Display class registry key not found: $classRoot" }
$baseKey = [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine,[Microsoft.Win32.RegistryView]::Registry64)
$classKey = $baseKey.OpenSubKey('SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}')
if ($null -eq $classKey) { $baseKey.Dispose(); throw 'Unable to open display class registry key.' }
$foundList = [System.Collections.Generic.List[object]]::new()
try {
 foreach ($subKeyName in $classKey.GetSubKeyNames()) {
  if ($subKeyName -notmatch '^\d{4}$') { continue }
  $instanceKey = $null
  try {
   $instanceKey = $classKey.OpenSubKey($subKeyName)
   if ($null -eq $instanceKey) { continue }
   foreach ($entry in @($instanceKey.GetValue('UserModeDriverNameWow',$null))) {
    if ($null -eq $entry) { continue }
    $candidate = [Environment]::ExpandEnvironmentVariables([string]$entry)
    if ($candidate -match '(?i)\\wow64\\d3d12\\amdgpu_wddm_d3d12(?:32)?\.dll$') {
     $foundList.Add([pscustomobject]@{ RegistryKey = "$classRoot\$subKeyName"; Target = $candidate })
    }
   }
  } catch [System.Security.SecurityException] { Write-Warning "Skipping inaccessible display instance key $subKeyName" }
  finally { if ($null -ne $instanceKey) { $instanceKey.Dispose() } }
 }
} finally { $classKey.Dispose(); $baseKey.Dispose() }
$found = @($foundList | Sort-Object -Property Target -Unique)
if ($found.Count -ne 1) { throw "Expected one registered 32-bit Nagi D3D12 UMD path, found $($found.Count). Refusing to guess." }
$target = $found[0].Target
if (-not (Test-Path -LiteralPath $target -PathType Leaf)) { throw "Registered D3D12 UMD does not exist: $target" }
$backupRoot = Join-Path $env:ProgramData 'BC250\UMD-backups'
if ($Rollback) {
    if (-not $BackupDirectory) {
        $records = @(Get-ChildItem -LiteralPath $backupRoot -Filter backup.json -Recurse -File -ErrorAction SilentlyContinue |
            Where-Object { (Get-Content -LiteralPath $_.FullName -Raw | ConvertFrom-Json).Target -eq $target } |
            Sort-Object LastWriteTimeUtc -Descending)
        if ($records.Count -eq 0) { throw "No external backup found. Specify -BackupDirectory or use the installer that made the old backup." }
        $BackupDirectory = $records[0].DirectoryName
    }
    Restore-Bd253File $target $BackupDirectory
    exit 0
}
if ($BackupDirectory) { throw '-BackupDirectory is used only with -Rollback.' }
$source = Join-Path $PSScriptRoot 'amdgpu_wddm_d3d12.dll'
if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "Built x86 DLL missing: $source" }
$stream = [IO.File]::OpenRead($source)
$reader = [IO.BinaryReader]::new($stream)
try {
    if ($reader.ReadUInt16() -ne 0x5a4d) { throw 'Source is not a PE DLL.' }
    $stream.Position = 0x3c
    $peOffset = $reader.ReadUInt32()
    $stream.Position = $peOffset
    if ($reader.ReadUInt32() -ne 0x4550 -or $reader.ReadUInt16() -ne 0x14c) { throw 'Source is not an x86 PE DLL.' }
} finally { $reader.Dispose() }
Install-Bd253File $source $target $backupRoot
