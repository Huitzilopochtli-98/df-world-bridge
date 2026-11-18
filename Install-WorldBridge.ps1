[CmdletBinding(SupportsShouldProcess=$true)]
param([string]$GamePath,[string]$HackPath)
$ErrorActionPreference='Stop'
$sourceRoot=$PSScriptRoot
. (Join-Path $sourceRoot 'installer\Find-Game.ps1')
$installation=Find-WorldBridgeInstallation -GamePath $GamePath -HackPath $HackPath
$gameRoot=$installation.GamePath
$hackRoot=$installation.HackPath
function Get-WorldBridgeFileHash([string]$Path) {
    # Read directly: PowerShell 5.1's Get-FileHash path pipeline inherits WhatIf.
    $stream=[IO.File]::OpenRead($Path)
    $algorithm=[Security.Cryptography.SHA256]::Create()
    try { return [BitConverter]::ToString($algorithm.ComputeHash($stream)).Replace('-','') }
    finally { $algorithm.Dispose(); $stream.Dispose() }
}
Write-Host "Game: $gameRoot"
Write-Host "DFHack: $hackRoot"
$planned=@()
$mappings=@(
    @{source='lua';destination=(Join-Path $hackRoot 'lua');prefix='hack\lua';root=$hackRoot},
    @{source='dfhack-config\scripts';destination=(Join-Path $gameRoot 'dfhack-config\scripts');prefix='dfhack-config\scripts';root=$gameRoot}
)
foreach($mapping in $mappings) {
    $from=Join-Path $sourceRoot $mapping.source
    foreach($file in Get-ChildItem -LiteralPath $from -Recurse -File) {
        $suffix=$file.FullName.Substring($from.Length).TrimStart('\')
        $relative=Join-Path $mapping.prefix $suffix
        $destination=[System.IO.Path]::GetFullPath((Join-Path $mapping.destination $suffix))
        if (-not $destination.StartsWith($mapping.root.TrimEnd('\')+'\',[System.StringComparison]::OrdinalIgnoreCase)) { throw 'Invalid installation path.' }
        $planned+=@{source=$file.FullName;destination=$destination;relative=$relative;sha256=(Get-WorldBridgeFileHash $file.FullName)}
    }
}
if (-not $PSCmdlet.ShouldProcess("$gameRoot (DFHack: $hackRoot)","Install World Bridge development build ($($planned.Count) files)")) { return }
$backupRoot=Join-Path $gameRoot ('dfhack-config\world-bridge-backups\'+[DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')+'-'+[Guid]::NewGuid().ToString('N').Substring(0,8))
$changed=@()
try {
    foreach($entry in $planned) {
        $existing=Test-Path -LiteralPath $entry.destination
        $backup=$null
        if ($existing) {
            if ((Get-WorldBridgeFileHash $entry.destination) -eq $entry.sha256) { continue }
            $backup=Join-Path $backupRoot $entry.relative
            New-Item -ItemType Directory -Path ([System.IO.Path]::GetDirectoryName($backup)) -Force | Out-Null
            Copy-Item -LiteralPath $entry.destination -Destination $backup
        }
        New-Item -ItemType Directory -Path ([System.IO.Path]::GetDirectoryName($entry.destination)) -Force | Out-Null
        $changed+=@{destination=$entry.destination;backup=$backup;existed=$existing}
        Copy-Item -LiteralPath $entry.source -Destination $entry.destination -Force
        if ((Get-WorldBridgeFileHash $entry.destination) -ne $entry.sha256) { throw 'Installed file verification failed.' }
    }
    $manifest=@{version=(Get-Content -Raw -LiteralPath (Join-Path $sourceRoot 'VERSION')).Trim();game_path=$gameRoot;hack_path=$hackRoot;installed_utc=[DateTime]::UtcNow.ToString('o');files=@($planned | ForEach-Object {@{path=$_.relative;sha256=$_.sha256}})}
    $manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $gameRoot 'dfhack-config\world-bridge-install.json') -Encoding UTF8
} catch {
    for($i=$changed.Count-1;$i -ge 0;$i--) {
        $entry=$changed[$i]
        if ($entry.existed) { Copy-Item -LiteralPath $entry.backup -Destination $entry.destination -Force }
        elseif (Test-Path -LiteralPath $entry.destination) { Remove-Item -LiteralPath $entry.destination -Force }
    }
    throw
}
Write-Host "World Bridge installed: $gameRoot"
Write-Host 'Restart Dwarf Fortress, load a copied fortress save, and run: world-bridge'
Write-Host 'Supported Windows Steam builds: DF 53.17 / DFHack 53.17-r1 and DF 53.16 / DFHack 53.16-r3.'
