$ErrorActionPreference='Stop'
$packageRoot=Split-Path -Parent $PSScriptRoot
. (Join-Path $packageRoot 'installer\Find-Game.ps1')
$fixtureParent=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')
$fixtureName='world-bridge-installer-'+[guid]::NewGuid().ToString('N')
$fixtureRoot=Join-Path $fixtureParent $fixtureName
New-Item -ItemType Directory -Path $fixtureRoot | Out-Null
$checks=0
function Assert-True($value,[string]$message) {
    if(-not $value) { throw $message }; $script:checks++
}
function Assert-Throws([scriptblock]$action,[string]$pattern) {
    $threw=$false
    try { & $action | Out-Null } catch {
        if($pattern -and $_.Exception.Message -notmatch $pattern) { throw }
        $threw=$true
    }
    Assert-True $threw 'Expected installation discovery to reject this case.'
}
function Write-Fixture([string]$path,[string]$text='fixture') {
    New-Item -ItemType Directory -Path (Split-Path -Parent $path) -Force | Out-Null
    [IO.File]::WriteAllText($path,$text)
}
function New-Game([string]$path,[switch]$WithHack) {
    Write-Fixture (Join-Path $path 'Dwarf Fortress.exe')
    if($WithHack) {
        Write-Fixture (Join-Path $path 'hack\dfhack-run.exe')
        Write-Fixture (Join-Path $path 'hack\dfhooks_dfhack.dll')
    }
}
function Write-Manifest([string]$library,[string]$directory) {
    Write-Fixture (Join-Path $library 'steamapps\appmanifest_975370.acf') ('"AppState" { "appid" "975370" "installdir" "'+$directory+'" }')
}
$oldProgramFiles=$env:ProgramFiles
$oldProgramFilesX86=${env:ProgramFiles(x86)}
$oldProgramW6432=$env:ProgramW6432
try {
    $steam=Join-Path $fixtureRoot 'Program Files\Steam'
    $library=Join-Path $fixtureRoot 'Secondary Library'
    $game=Join-Path $library 'steamapps\common\Dwarf Fortress 975370'
    $hack=Join-Path $steam 'steamapps\common\DFHack\hack'
    New-Game $game
    Write-Fixture (Join-Path $hack 'dfhack-run.exe')
    Write-Fixture (Join-Path $hack 'dfhooks_dfhack.dll')
    Write-Fixture (Join-Path $game 'dfhooks_dfhack.ini') ('"'+(Join-Path $hack 'dfhooks_dfhack.dll')+'"')
    Write-Manifest $library 'Dwarf Fortress 975370'
    $vanilla=Join-Path $steam 'steamapps\common\Vanilla'
    New-Game $vanilla; Write-Manifest $steam 'Vanilla'
    $escaped=$library.Replace('\','\\')
    $vdf=Join-Path $steam 'steamapps\libraryfolders.vdf'
    Write-Fixture $vdf ('"libraryfolders" { "1" { "path" "'+$escaped+'" } "2" { "path" "'+$escaped+'" } }')
    $found=Find-WorldBridgeInstallation -SteamRoots @($steam,$steam) -RegisteredGamePaths @()
    Assert-True ($found.GamePath -eq $game) 'Failed to find the renamed game in a secondary library.'
    Assert-True ($found.HackPath -eq $hack) 'Failed to follow the external DFHack hook.'

    # End-to-end no-argument installation sees only this synthetic Steam setup.
    function Get-ItemProperty { [CmdletBinding()]param([string]$LiteralPath) }
    function Get-Process { [CmdletBinding()]param([string]$Name) }
    $env:ProgramFiles=Split-Path -Parent $steam
    ${env:ProgramFiles(x86)}=$env:ProgramFiles
    $env:ProgramW6432=$env:ProgramFiles
    $installer=Join-Path $packageRoot 'Install-WorldBridge.ps1'
    & $installer -WhatIf
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $hack 'lua'))) 'WhatIf created files.'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $game 'dfhack-config'))) 'WhatIf created a manifest.'
    & $installer
    $manifest=Get-Content -LiteralPath (Join-Path $game 'dfhack-config\world-bridge-install.json') -Raw | ConvertFrom-Json
    Assert-True ($manifest.game_path -eq $game -and $manifest.hack_path -eq $hack) 'Manifest recorded the wrong roots.'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $game 'hack'))) 'Installer used the inactive local hack path.'
    foreach($file in $manifest.files) {
        if($file.path.StartsWith('hack\')) { $target=Join-Path $hack $file.path.Substring(5) }
        else { $target=Join-Path $game $file.path }
        Assert-True ((Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash -eq $file.sha256) 'Installed file hash mismatch.'
    }
    $service=Join-Path $hack 'lua\world-bridge\service.lua'
    Write-Fixture $service 'prior custom content'
    & $installer
    $backups=@(Get-ChildItem -LiteralPath (Join-Path $game 'dfhack-config\world-bridge-backups') -Recurse -File -Filter service.lua)
    Assert-True ($backups.Count -eq 1) 'Replacing an external DFHack file did not create one backup.'
    Assert-True ((Get-Content -LiteralPath $backups[0].FullName -Raw) -eq 'prior custom content') 'Backup content differs.'

    # Legacy library metadata and explicit portable installations remain usable.
    Write-Fixture $vdf ('"libraryfolders" { "1" "'+$escaped+'" }')
    Assert-True ((Find-WorldBridgeInstallation -SteamRoots @($steam) -RegisteredGamePaths @()).GamePath -eq $game) 'Legacy Steam library format failed.'
    $portable=Join-Path $fixtureRoot 'Portable [test]'
    New-Game $portable -WithHack
    Write-Fixture (Join-Path $portable 'dfhooks_dfhack.ini') 'hack/dfhooks_dfhack.dll'
    Assert-True ((Find-WorldBridgeInstallation -GamePath $portable).HackPath -eq (Join-Path $portable 'hack')) 'Relative hook or literal bracket path failed.'
    Assert-True ((Find-WorldBridgeInstallation -GamePath $portable -HackPath $hack).HackPath -eq $hack) 'Manual DFHack override failed.'
    Write-Fixture (Join-Path $portable 'dfhooks_dfhack.ini') 'missing/dfhooks_dfhack.dll'
    Assert-Throws { Find-WorldBridgeInstallation -GamePath $portable } 'missing DFHack'

    $second=Join-Path $steam 'steamapps\common\Second copy'
    New-Game $second -WithHack; Write-Manifest $steam 'Second copy'
    Assert-Throws { Find-WorldBridgeInstallation -SteamRoots @($steam) -RegisteredGamePaths @() } 'Multiple'
    Assert-True ((Find-WorldBridgeInstallation -SteamRoots @($steam) -RegisteredGamePaths @($game)).GamePath -eq $game) 'Authoritative registration did not disambiguate.'
    Assert-Throws { Find-WorldBridgeInstallation -SteamRoots @() -RegisteredGamePaths @() } 'Could not find'

    $badLibrary=Join-Path $fixtureRoot 'Untrusted Library'
    New-Game (Join-Path $badLibrary 'Outside') -WithHack
    Write-Manifest $badLibrary '..\..\Outside'
    Assert-Throws { Find-WorldBridgeInstallation -SteamRoots @($badLibrary) -RegisteredGamePaths @() } 'Could not find'
    Write-Manifest $badLibrary 'Missing game'
    Assert-Throws { Find-WorldBridgeInstallation -SteamRoots @($badLibrary) -RegisteredGamePaths @('missing registered path') } 'Could not find'
    Write-Host "Installer tests passed ($checks checks)."
} finally {
    $env:ProgramFiles=$oldProgramFiles
    ${env:ProgramFiles(x86)}=$oldProgramFilesX86
    $env:ProgramW6432=$oldProgramW6432
    # Delete only the exact temporary fixture directory created by this run.
    $resolved=(Resolve-Path -LiteralPath $fixtureRoot).ProviderPath
    if(-not $resolved.StartsWith($fixtureParent+'\',[StringComparison]::OrdinalIgnoreCase) -or
        (Split-Path -Leaf $resolved) -ne $fixtureName) { throw 'Refusing to remove an unexpected test directory.' }
    Remove-Item -LiteralPath $resolved -Recurse -Force
}
