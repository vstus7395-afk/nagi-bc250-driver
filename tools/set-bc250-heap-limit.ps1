[CmdletBinding()]
param([switch]$Rollback, [string]$BackupDirectory)
$ErrorActionPreference = 'Stop'

function Get-HeapLimitState($Base, [string]$Path) {
    $key = $Base.OpenSubKey($Path, $false)
    try {
        if (-not $key -or $key.GetValueNames() -notcontains 'MaxSRVHeapSize') {
            return @{ Present = $false; Value = $null }
        }
        if ($key.GetValueKind('MaxSRVHeapSize') -ne [Microsoft.Win32.RegistryValueKind]::DWord) {
            throw 'Existing MaxSRVHeapSize is not REG_DWORD. No changes made.'
        }
        return @{ Present = $true; Value = [int]$key.GetValue('MaxSRVHeapSize') }
    } finally { if ($key) { $key.Dispose() } }
}

function Write-HeapLimitState($Base, [string]$Path, $State) {
    $key = $Base.CreateSubKey($Path)
    try {
        if ($State.Present) {
            $key.SetValue('MaxSRVHeapSize', [int]$State.Value, [Microsoft.Win32.RegistryValueKind]::DWord)
        } else { $key.DeleteValue('MaxSRVHeapSize', $false) }
        $key.Flush()
    } finally { if ($key) { $key.Dispose() } }
    $actual = Get-HeapLimitState $Base $Path
    if ($actual.Present -ne $State.Present -or ($actual.Present -and $actual.Value -ne $State.Value)) {
        throw 'Registry verification failed.'
    }
}

function Set-HeapLimit($Base, [string]$Path, [string]$Root) {
    $before = Get-HeapLimitState $Base $Path
    if ($before.Present -and $before.Value -eq 65536) {
        Write-Host 'MaxSRVHeapSize is already 65536. No new backup or change.'
        return
    }
    $folder = Join-Path $Root ((Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $folder -Force | Out-Null
    $record = [ordered]@{ Schema = 1; Hive = $Base.Name; View = [string]$Base.View; Path = $Path;
        Name = 'MaxSRVHeapSize'; Present = $before.Present; Value = $before.Value; Applied = 65536 }
    $file = Join-Path $folder 'registry-backup.json'
    $record | ConvertTo-Json | Set-Content -LiteralPath $file -Encoding UTF8
    $saved = Get-Content -LiteralPath $file -Raw | ConvertFrom-Json
    if ($saved.Present -ne $before.Present -or $saved.Value -ne $before.Value -or $saved.Path -ne $Path) {
        throw 'Backup verification failed. Registry was not changed.'
    }
    try { Write-HeapLimitState $Base $Path @{ Present = $true; Value = 65536 } }
    catch {
        $failure = $_
        try { Write-HeapLimitState $Base $Path $before }
        catch { throw "Apply and rollback failed. Backup: $file. Apply: $failure. Restore: $_" }
        throw "Apply failed; previous value restored. $failure"
    }
    Write-Host "Verified backup: $folder"
    Write-Host 'Applied MaxSRVHeapSize=65536 in the 32-bit registry view.'
    Write-Host 'This affects new 32-bit D3D9On12 processes. No DLL or file permissions changed.'
    Write-Host 'Keep the current diagnostic DLL. Start the recorder, then a fresh L2 process.'
    Write-Host 'Check for descriptor_heap_large_ok with count=65536 in the new log.'
    return $folder
}

function Restore-HeapLimit($Base, [string]$Path, [string]$Folder) {
    $record = Get-Content -LiteralPath (Join-Path $Folder 'registry-backup.json') -Raw | ConvertFrom-Json
    if ($record.Schema -ne 1 -or $record.Hive -ne $Base.Name -or $record.View -ne [string]$Base.View -or
        $record.Path -ne $Path -or $record.Name -ne 'MaxSRVHeapSize' -or $record.Applied -ne 65536 -or
        $record.Present -isnot [bool]) { throw 'Backup does not belong to this setting. No changes made.' }
    if ($record.Present) { $null = [int]$record.Value }
    $now = Get-HeapLimitState $Base $Path
    if ($now.Present -eq $record.Present -and (-not $now.Present -or $now.Value -eq $record.Value)) {
        Write-Host 'Original setting is already restored.'; return
    }
    if (-not $now.Present -or $now.Value -ne 65536) {
        throw 'The setting changed after this experiment. Refusing to overwrite another change.'
    }
    Write-HeapLimitState $Base $Path $record
    Write-Host 'Original MaxSRVHeapSize restored. Start a fresh game process.'
}

if ($MyInvocation.InvocationName -ne '.') {
    if (-not [Environment]::Is64BitOperatingSystem) { throw 'This experiment requires 64-bit Windows.' }
    $principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'Run Windows PowerShell as administrator.'
    }
    if (Get-Process -Name L2 -ErrorAction SilentlyContinue) { throw 'Close all L2 processes first.' }
    $desktop = [Environment]::GetFolderPath([Environment+SpecialFolder]::DesktopDirectory)
    if (-not $desktop -or -not (Test-Path -LiteralPath $desktop -PathType Container)) { throw 'Desktop folder not found.' }
    $root = Join-Path $desktop 'BC250-heap-limit-backups'
    $path = 'Software\Microsoft\Direct3D\Direct3D9on12'
    $base = [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine,
        [Microsoft.Win32.RegistryView]::Registry32)
    try {
        if ($Rollback) {
            if (-not $BackupDirectory) {
                $latest = Get-ChildItem -LiteralPath $root -Filter registry-backup.json -Recurse -File |
                    Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1
                if (-not $latest) { throw 'No backup found on the Desktop.' }
                $BackupDirectory = $latest.DirectoryName
            }
            Restore-HeapLimit $base $path $BackupDirectory
        } else { $null = Set-HeapLimit $base $path $root }
    } finally { $base.Dispose() }
    exit 0
}
