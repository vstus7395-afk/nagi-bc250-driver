$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'install-bd253-test-umd.ps1')
$root = Join-Path $env:TEMP ('bc250-installer-test-' + [guid]::NewGuid().ToString('N'))
$targetFolder = Join-Path $root 'protected'
$target = Join-Path $targetFolder 'amdgpu_wddm_d3d1232.dll'
$source = Join-Path $root 'candidate.dll'
$backups = Join-Path $root 'backups'
$originalDirAcl = $null
$originalFileAcl = $null
function Assert([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
    Write-Host "PASS: $Message"
}
try {
    New-Item -ItemType Directory -Path $targetFolder -Force | Out-Null
    [IO.File]::WriteAllText($target, 'old driver test fixture')
    [IO.File]::WriteAllText($source, 'new driver test fixture')
    $oldHash = (Get-FileHash $target).Hash
    $newHash = (Get-FileHash $source).Hash
    $originalDirAcl = Get-Acl $targetFolder
    $originalFileAcl = Get-Acl $target
    # Restrict only these disposable fixtures, never DriverStore or a real driver.
    $user = [Security.Principal.WindowsIdentity]::GetCurrent().User
    $system = [Security.Principal.SecurityIdentifier]::new('S-1-5-18')
    foreach ($path in @($targetFolder, $target)) {
        $acl = Get-Acl $path
        $acl.SetAccessRuleProtection($true, $false)
        foreach ($rule in @($acl.Access)) { $acl.RemoveAccessRuleSpecific($rule) }
        $acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new($user, 'ReadAndExecute', 'Allow'))
        $acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new($system, 'FullControl', 'Allow'))
        Set-Acl -LiteralPath $path -AclObject $acl
    }
    $dirSecurity = (Get-Acl $targetFolder).Sddl
    $fileSecurity = (Get-Acl $target).Sddl
    $denied = $false
    try { Copy-Item -LiteralPath $source -Destination $target -Force -ErrorAction Stop } catch { $denied = $true }
    Assert $denied 'ordinary Copy-Item cannot overwrite the protected fixture'

    Install-Bd253File $source $target $backups
    Assert ((Get-FileHash $target).Hash -eq $newHash) 'backup-mode install replaces the protected file'
    Assert ((Get-Acl $targetFolder).Sddl -eq $dirSecurity) 'directory permissions and owner are unchanged'
    Assert ((Get-Acl $target).Sddl -eq $fileSecurity) 'file permissions and owner are unchanged'
    $folders = @(Get-ChildItem $backups -Directory)
    Assert ($folders.Count -eq 1) 'one external backup is created'
    $folder = $folders[0].FullName
    Assert ((Get-FileHash (Join-Path $folder (Split-Path -Leaf $target))).Hash -eq $oldHash) 'backup contains the original bytes'
    Install-Bd253File $source $target $backups
    Assert (@(Get-ChildItem $backups -Directory).Count -eq 1) 'repeated install preserves the original rollback point'
    Restore-Bd253File $target $folder
    Assert ((Get-FileHash $target).Hash -eq $oldHash) 'rollback restores the protected file'
    Assert ((Get-Acl $target).Sddl -eq $fileSecurity) 'rollback preserves file security'

    $backupFile = Join-Path $folder (Split-Path -Leaf $target)
    [IO.File]::WriteAllText($backupFile, 'corrupt backup')
    $rejected = $false
    try { Restore-Bd253File $target $folder } catch { $rejected = $true }
    Assert $rejected 'corrupt backup is rejected'
    Assert ((Get-FileHash $target).Hash -eq $oldHash) 'rejected rollback leaves target intact'

    # Exercise the transaction's rollback after a copy reports failure after changing bytes.
    $realCopy = (Get-Item Function:\Copy-Bd253File).ScriptBlock
    $script:copyCalls = 0
    function Copy-Bd253File([string]$Source, [string]$Target) {
        $script:copyCalls++
        & $realCopy $Source $Target
        if ($script:copyCalls -eq 1) { throw 'Injected failure after writing candidate bytes' }
    }
    $failed = $false
    try { Install-Bd253File $source $target $backups } catch { $failed = $true }
    Assert $failed 'installation reports an injected copy failure'
    Assert ($script:copyCalls -eq 2) 'failed copy invokes automatic rollback'
    Assert ((Get-FileHash $target).Hash -eq $oldHash) 'automatic rollback restores original bytes'
    Write-Host 'All installer regression tests passed.'
} finally {
    if ($originalDirAcl) { Set-Acl -LiteralPath $targetFolder -AclObject $originalDirAcl }
    if ($originalFileAcl) { Set-Acl -LiteralPath $target -AclObject $originalFileAcl }
    Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
}
