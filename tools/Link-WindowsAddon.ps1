#Requires -Version 5.1
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string] $AddOnsPath,
    [switch] $BackupExisting
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script:RCPRepositoryRoot = Split-Path -Parent $PSScriptRoot

function Get-RCPPath([string] $Value) {
    return [IO.Path]::GetFullPath($Value).TrimEnd([IO.Path]::DirectorySeparatorChar)
}
function Test-RCPWithin([string] $Child, [string] $Parent) {
    return $Child.Equals($Parent, [StringComparison]::OrdinalIgnoreCase) -or
        $Child.StartsWith($Parent + '\', [StringComparison]::OrdinalIgnoreCase)
}
function Get-RCPExistingItem([string] $LiteralPath) {
    try { return Get-Item -LiteralPath $LiteralPath -Force -ErrorAction Stop }
    catch [System.Management.Automation.ItemNotFoundException] { return $null }
}
function Assert-RCPLocalPath([string] $Value) {
    if ($Value.StartsWith('\\') -or $Value -notmatch '^[A-Za-z]:\\') {
        throw 'Use a local Windows drive, not a network/UNC path.'
    }
    $drive = [IO.DriveInfo]::new([IO.Path]::GetPathRoot($Value))
    if ($drive.DriveType -eq [IO.DriveType]::Network -or $drive.DriveFormat -ne 'NTFS') {
        throw 'This setup supports local NTFS drives. Choose a local checkout and Retail installation.'
    }
    # Cloud placeholders are allowed; directory links in ancestors are ambiguous.
    $item = Get-Item -LiteralPath $Value -Force
    while ($null -ne $item) {
        $link = $item.PSObject.Properties['LinkType']
        if ($null -ne $link -and $link.Value -in @('Junction', 'SymbolicLink')) {
            throw "Choose a physical folder, not a path through another directory link: $($item.FullName)"
        }
        $item = $item.Parent
    }
}
function Select-RCPAddOnsPath {
    Add-Type -AssemblyName System.Windows.Forms
    $picker = New-Object System.Windows.Forms.FolderBrowserDialog
    $picker.Description = 'Choose the actual Retail Interface\AddOns folder (not Interface or a repository folder).'
    $picker.ShowNewFolderButton = $false
    try {
        if ($picker.ShowDialog() -ne [Windows.Forms.DialogResult]::OK) {
            throw 'Cancelled. Nothing was changed.'
        }
        return $picker.SelectedPath
    }
    finally { $picker.Dispose() }
}
function New-RCPJunction([string] $Destination, [string] $Source) {
    # Windows PowerShell 5.1 expands junction targets as wildcard paths (#6232).
    # Escape that provider input only; verification compares the real, unescaped target.
    $providerTarget = [Management.Automation.WildcardPattern]::Escape($Source)
    New-Item -ItemType Junction -Path $Destination -Value $providerTarget -ErrorAction Stop | Out-Null
}
function Get-RCPInstallPlan([string] $RepositoryRoot, [string] $AddOnsPath) {
    if ($env:OS -ne 'Windows_NT') { throw 'Run this setup on the Windows PC that has WoW installed.' }
    if ($PSVersionTable.PSEdition -ne 'Desktop') { throw 'Use Setup-Windows.cmd, which runs the built-in Windows PowerShell 5.1. PowerShell 7 is not supported by this helper.' }
    $root = Get-RCPPath $RepositoryRoot
    $addons = Get-RCPPath $AddOnsPath
    $source = Join-Path $root 'RCPArsenal'
    $destination = Join-Path $addons 'RCPArsenal'
    if (-not (Test-Path -LiteralPath (Join-Path $root '.git')) -or
        -not (Test-Path -LiteralPath (Join-Path $source 'RCPArsenal.toc') -PathType Leaf) -or
        -not (Test-Path -LiteralPath (Join-Path $source 'Core.lua') -PathType Leaf) -or
        -not (Test-Path -LiteralPath (Join-Path $source 'Media') -PathType Container)) {
        throw 'Run Setup-Windows.cmd from the source checkout containing .git, tools, and the inner RCPArsenal addon folder.'
    }
    if ((Get-Content -LiteralPath (Join-Path $source 'RCPArsenal.toc') -Raw) -notmatch '(?m)^Core\.lua\s*$') {
        throw 'The inner addon TOC is incomplete. Fetch/Pull the checkout and keep its files available on this device.'
    }
    $item = Get-RCPExistingItem $addons
    if ($null -eq $item -or -not $item.PSIsContainer -or $item.Name -ine 'AddOns' -or
        $item.Parent.Name -ine 'Interface' -or
        -not (Test-Path -LiteralPath (Join-Path $item.Parent.Parent.FullName 'Wow.exe') -PathType Leaf)) {
        throw 'Choose the existing Retail Interface\AddOns folder with Wow.exe two levels above it. Custom installation folder names are supported. Use Battle.net -> WoW -> gear -> Show in Explorer to find it.'
    }
    if ((Test-RCPWithin $root $addons) -or (Test-RCPWithin $addons $root) -or
        $root -match '(?i)\\Interface\\AddOns(?:\\|$)') {
        throw 'Move the WHOLE GitHub checkout outside WoW first, then Locate it in GitHub Desktop. Do not link a checkout that is inside AddOns.'
    }
    Assert-RCPLocalPath $root
    Assert-RCPLocalPath $source
    Assert-RCPLocalPath $addons
    $existing = Get-RCPExistingItem $destination
    $alreadyLinked = $false
    if ($null -ne $existing) {
        if (-not $existing.PSIsContainer) { throw "A file already occupies $destination. It was kept unchanged." }
        if (($existing.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            $linkType = $existing.PSObject.Properties['LinkType']
            $targets = @($existing.Target)
            if ($null -ne $linkType -and $linkType.Value -eq 'Junction' -and $targets.Count -eq 1 -and
                (Get-RCPPath $targets[0]).Equals($source, [StringComparison]::OrdinalIgnoreCase)) {
                $alreadyLinked = $true
            }
            else { throw "A different link/reparse point already occupies $destination. It was kept unchanged; this setup will not retarget it." }
        }
    }
    $backup = $null
    if ($null -ne $existing -and -not $alreadyLinked) {
        $backupBase = Join-Path $item.Parent.FullName 'RCPArsenal-InstallBackups'
        $backupItem = Get-RCPExistingItem $backupBase
        if ($null -ne $backupItem) {
            if (-not $backupItem.PSIsContainer) { throw "A file occupies the backup directory: $backupBase. It was kept unchanged." }
            Assert-RCPLocalPath $backupBase
        }
        $backup = Join-Path $backupBase ((Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [guid]::NewGuid().ToString('N') + '\RCPArsenal')
    }
    return [pscustomobject]@{ Source = $source; Destination = $destination; Backup = $backup; AlreadyLinked = $alreadyLinked; Changed = $false }
}
function Invoke-RCPWindowsInstall {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param([string] $RepositoryRoot, [string] $AddOnsPath, [switch] $BackupExisting)
    if ([string]::IsNullOrWhiteSpace($AddOnsPath)) { $AddOnsPath = Select-RCPAddOnsPath }
    $plan = Get-RCPInstallPlan $RepositoryRoot $AddOnsPath
    Write-Host "Source checkout addon: $($plan.Source)"
    Write-Host "Live WoW addon:        $($plan.Destination)"
    if ($plan.AlreadyLinked) {
        Write-Host 'Already linked correctly. Desktop Fetch/Pull updates this live addon. No changes made.'
        return $plan
    }
    if ($null -ne $plan.Backup) { Write-Host "Existing folder backup: $($plan.Backup)" }
    if (-not $PSCmdlet.ShouldProcess($plan.Destination, 'Link the source addon; preserve any existing folder in the displayed backup')) { return $plan }
    if ($null -ne $plan.Backup -and -not $BackupExisting) {
        Write-Host 'The entire existing folder, including any nested files, will be MOVED to that backup outside AddOns. No files are deleted.'
        if ((Read-Host 'Type BACKUP to preserve it and continue, or press Enter to cancel') -cne 'BACKUP') {
            throw 'Cancelled. Existing files were kept unchanged.'
        }
    }
    $moved = $false
    try {
        if ($null -ne $plan.Backup) {
            $backupParent = [IO.Path]::GetDirectoryName($plan.Backup)
            [IO.Directory]::CreateDirectory($backupParent) | Out-Null
            Assert-RCPLocalPath $backupParent
            [IO.Directory]::Move($plan.Destination, $plan.Backup)
            $moved = $true
        }
        # No -Force: an existing/racing destination must never be overwritten.
        New-RCPJunction $plan.Destination $plan.Source
        $verified = Get-RCPInstallPlan $RepositoryRoot $AddOnsPath
        if (-not $verified.AlreadyLinked -or -not (Test-Path -LiteralPath (Join-Path $plan.Destination 'RCPArsenal.toc') -PathType Leaf)) {
            throw 'The link could not be verified. Keep the displayed source/backup paths and inspect the destination before retrying.'
        }
        $plan.Changed = $true
    }
    catch {
        if ($moved -and $null -eq (Get-RCPExistingItem $plan.Destination)) {
            try { [IO.Directory]::Move($plan.Backup, $plan.Destination); $moved = $false }
            catch { Write-Warning "The backup is safe at $($plan.Backup); automatic restoration failed: $($_.Exception.Message)" }
        }
        if ($moved) { Write-Warning "Your previous folder is preserved at $($plan.Backup)." }
        throw "Setup stopped: $($_.Exception.Message) If access was denied, retry this same setup as administrator. For OneDrive, keep the checkout available on this device. No files were overwritten or deleted."
    }
    Write-Host 'Linked successfully. Future GitHub Desktop Fetch/Pull updates the live addon; no copying is needed.'
    Write-Host 'Keep this checkout in place. Fully restart WoW for the first install; use /reload for later Lua changes.'
    return $plan
}
if ($MyInvocation.InvocationName -ne '.') {
    try { Invoke-RCPWindowsInstall -RepositoryRoot $script:RCPRepositoryRoot -AddOnsPath $AddOnsPath -BackupExisting:$BackupExisting -WhatIf:$WhatIfPreference | Out-Null }
    catch { Write-Host $_.Exception.Message -ForegroundColor Red; exit 1 }
}
