$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\set-bc250-heap-limit.ps1"
function Require($Condition, $Message) { if (-not $Condition) { throw $Message } }
$base = [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::CurrentUser,
    [Microsoft.Win32.RegistryView]::Registry32)
$path = 'Software\BC250HeapLimitTest-' + [guid]::NewGuid().ToString('N')
$root = Join-Path $env:TEMP ('BC250HeapLimitTest-' + [guid]::NewGuid().ToString('N'))
try {
    foreach ($original in @(@{Present=$false;Value=$null}, @{Present=$true;Value=262144}, @{Present=$true;Value=-1})) {
        Write-HeapLimitState $base $path $original
        $key = $base.OpenSubKey($path,$true)
        $key.SetValue('UnrelatedSetting','keep'); $key.Dispose()
        $backup = Set-HeapLimit $base $path $root
        Require ((Get-HeapLimitState $base $path).Value -eq 65536) 'Apply failed'
        $count = @(Get-ChildItem $root -Directory).Count
        $null = Set-HeapLimit $base $path $root
        Require (@(Get-ChildItem $root -Directory).Count -eq $count) 'Repeated apply overwrote backup'
        Restore-HeapLimit $base $path $backup
        $after = Get-HeapLimitState $base $path
        Require ($after.Present -eq $original.Present -and $after.Value -eq $original.Value) 'Rollback failed'
        Restore-HeapLimit $base $path $backup
        $key = $base.OpenSubKey($path)
        Require ($key.GetValue('UnrelatedSetting') -eq 'keep') 'Unrelated value changed'; $key.Dispose()
    }
    $backup = Set-HeapLimit $base $path $root
    Write-HeapLimitState $base $path @{Present=$true;Value=131072}
    $rejected=$false
    try { Restore-HeapLimit $base $path $backup } catch { $rejected=$true }
    Require $rejected 'Rollback must preserve a later external change'
    Require ((Get-HeapLimitState $base $path).Value -eq 131072) 'External change overwritten'
    $key=$base.OpenSubKey($path,$true);$key.SetValue('MaxSRVHeapSize','bad',[Microsoft.Win32.RegistryValueKind]::String);$key.Dispose()
    $rejected=$false
    try { $null=Set-HeapLimit $base $path $root } catch { $rejected=$true }
    Require $rejected 'Non-DWORD setting was accepted'
    Write-Host 'PASS: apply, exact rollback, absent/DWORD/unsigned default, idempotence, unrelated values, conflict and wrong-type guards.'
} finally {
    $base.DeleteSubKeyTree($path,$false);$base.Dispose()
    Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
}
exit 0
