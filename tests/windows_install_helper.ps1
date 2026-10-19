# Focused filesystem fixtures on a disposable Windows runner; never touches WoW.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot '..\tools\Link-WindowsAddon.ps1')
$script:checks = 0
$fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ('RCP-setup-' + [guid]::NewGuid().ToString('N'))
function Assert-RCPTest([bool] $Condition, [string] $Message) {
    $script:checks++
    if (-not $Condition) { throw $Message }
}
function New-RCPFixture([string] $Name) {
    $base = Join-Path $fixtureRoot $Name
    $repo = Join-Path $base 'User Source [repo] & spaces\RCPArsenal'
    $source = Join-Path $repo 'RCPArsenal'
    # Deliberately matches the owner's custom root name, not a guessed _retail_ directory.
    $retail = Join-Path $base 'Program Files (x86)\World of Warcraft_retail_'
    $addons = Join-Path $retail 'Interface\AddOns'
    foreach ($dir in @((Join-Path $repo '.git'), (Join-Path $source 'Media'), $addons)) { [IO.Directory]::CreateDirectory($dir) | Out-Null }
    [IO.File]::WriteAllText((Join-Path $source 'RCPArsenal.toc'), "## Interface: 120100`nCore.lua`n")
    [IO.File]::WriteAllText((Join-Path $source 'Core.lua'), 'source version one')
    [IO.File]::WriteAllText((Join-Path $retail 'Wow.exe'), 'fixture marker; never executed')
    return [pscustomobject]@{ Repo=$repo; Source=$source; AddOns=$addons; Destination=(Join-Path $addons 'RCPArsenal') }
}
function Expect-RCPFailure([scriptblock] $Operation, [string] $Message) {
    $failed = $false
    try { & $Operation | Out-Null } catch { $failed = $true }
    Assert-RCPTest $failed $Message
}
$links = New-Object 'Collections.Generic.List[string]'
try {
    $f = New-RCPFixture 'normal'
    $plan = Invoke-RCPWindowsInstall -RepositoryRoot $f.Repo -AddOnsPath $f.AddOns -WhatIf
    Assert-RCPTest (-not (Test-Path -LiteralPath $f.Destination)) 'WhatIf created a live destination.'
    $result = Invoke-RCPWindowsInstall -RepositoryRoot $f.Repo -AddOnsPath $f.AddOns
    $links.Add($f.Destination)
    Assert-RCPTest $result.Changed 'Fresh setup did not create a link.'
    Assert-RCPTest ((Get-Item -LiteralPath $f.Destination).LinkType -eq 'Junction') 'Destination is not a junction.'
    [IO.File]::WriteAllText((Join-Path $f.Source 'Core.lua'), 'source version two')
    Assert-RCPTest ((Get-Content -LiteralPath (Join-Path $f.Destination 'Core.lua') -Raw) -eq 'source version two') 'Source update did not reach the linked addon.'
    $again = Invoke-RCPWindowsInstall -RepositoryRoot $f.Repo -AddOnsPath $f.AddOns
    Assert-RCPTest ($again.AlreadyLinked -and -not $again.Changed -and $null -eq $again.Backup) 'Repeat setup changed an already-correct link.'

    $b = New-RCPFixture 'existing nested install'
    [IO.Directory]::CreateDirectory((Join-Path $b.Destination 'RCPArsenal\RCPArsenal')) | Out-Null
    $old = Join-Path $b.Destination 'RCPArsenal\RCPArsenal\private-old-file.txt'
    [IO.File]::WriteAllText($old, 'keep every old byte')
    $preview = Invoke-RCPWindowsInstall -RepositoryRoot $b.Repo -AddOnsPath $b.AddOns -WhatIf
    Assert-RCPTest ((Test-Path -LiteralPath $old) -and -not (Test-Path -LiteralPath $preview.Backup)) 'Preview moved an existing nested directory.'
    $backup = Invoke-RCPWindowsInstall -RepositoryRoot $b.Repo -AddOnsPath $b.AddOns -BackupExisting
    $links.Add($b.Destination)
    Assert-RCPTest ((Get-Content -LiteralPath (Join-Path $backup.Backup 'RCPArsenal\RCPArsenal\private-old-file.txt') -Raw) -eq 'keep every old byte') 'Existing nested contents were not preserved.'
    Assert-RCPTest (-not (Test-RCPWithin $backup.Backup $b.AddOns)) 'Backup is still inside AddOns.'

    $other = New-RCPFixture 'foreign link'
    New-Item -ItemType Junction -Path $other.Destination -Value $f.Source | Out-Null
    $links.Add($other.Destination)
    Expect-RCPFailure { Invoke-RCPWindowsInstall -RepositoryRoot $other.Repo -AddOnsPath $other.AddOns } 'A foreign junction was retargeted.'
    Assert-RCPTest ((Get-Item -LiteralPath $other.Destination).Target[0] -eq $f.Source) 'Foreign junction target changed.'

    $file = New-RCPFixture 'existing file'
    [IO.File]::WriteAllText($file.Destination, 'keep file')
    Expect-RCPFailure { Invoke-RCPWindowsInstall -RepositoryRoot $file.Repo -AddOnsPath $file.AddOns } 'An existing file was replaced.'
    Assert-RCPTest ((Get-Content -LiteralPath $file.Destination -Raw) -eq 'keep file') 'Existing file bytes changed.'
    Expect-RCPFailure { Get-RCPInstallPlan $f.Repo (Split-Path -Parent $f.AddOns) } 'Interface was accepted as AddOns.'
    $noGame = New-RCPFixture 'not a game'
    [IO.File]::Delete((Join-Path (Split-Path -Parent (Split-Path -Parent $noGame.AddOns)) 'Wow.exe'))
    Expect-RCPFailure { Get-RCPInstallPlan $noGame.Repo $noGame.AddOns } 'An unrelated AddOns directory without Wow.exe was accepted.'
    $inside = New-RCPFixture 'nested clone'
    $nested = Join-Path $inside.AddOns 'RCPArsenal\RCPArsenal'
    [IO.Directory]::CreateDirectory((Split-Path -Parent $nested)) | Out-Null
    [IO.Directory]::Move($inside.Repo, $nested)
    Expect-RCPFailure { Get-RCPInstallPlan $nested $inside.AddOns } 'A source checkout inside AddOns was accepted.'
    Assert-RCPTest (Test-Path -LiteralPath (Join-Path $nested 'RCPArsenal\Core.lua')) 'Rejected nested checkout was modified.'

    # Force only the junction creation to fail after backup, exercising rollback.
    $rollback = New-RCPFixture 'permission failure'
    [IO.Directory]::CreateDirectory($rollback.Destination) | Out-Null
    [IO.File]::WriteAllText((Join-Path $rollback.Destination 'keep.txt'), 'original')
    function New-Item { throw [UnauthorizedAccessException]::new('Fixture access denied') }
    try { Expect-RCPFailure { Invoke-RCPWindowsInstall -RepositoryRoot $rollback.Repo -AddOnsPath $rollback.AddOns -BackupExisting } 'Creation failure was reported as success.' }
    finally { Remove-Item Function:\New-Item }
    Assert-RCPTest ((Get-Content -LiteralPath (Join-Path $rollback.Destination 'keep.txt') -Raw) -eq 'original') 'Failed creation did not restore the untouched prior folder.'
    Write-Host "PASS: $script:checks Windows helper filesystem checks (disposable fixtures, not a user/WoW install)."
}
finally {
    # Remove only known fixture junctions without recursion; never traverse targets.
    foreach ($link in $links) { if ($null -ne (Get-RCPExistingItem $link)) { [IO.Directory]::Delete($link) } }
    if (Test-Path -LiteralPath $fixtureRoot) { [IO.Directory]::Delete($fixtureRoot, $true) }
}
