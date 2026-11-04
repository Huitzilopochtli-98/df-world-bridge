# Steam metadata and DFHack's own hook file identify the active installation.
# No game files are written by these discovery functions.
function Get-WorldBridgeSteamRoots {
    foreach($key in @('HKCU:\Software\Valve\Steam','HKLM:\SOFTWARE\WOW6432Node\Valve\Steam','HKLM:\SOFTWARE\Valve\Steam')) {
        $entry=Get-ItemProperty -LiteralPath $key -ErrorAction SilentlyContinue
        foreach($name in @('SteamPath','InstallPath')) {
            if($entry -and $entry.PSObject.Properties[$name]) { $entry.$name }
        }
    }
    foreach($process in Get-Process -Name steam -ErrorAction SilentlyContinue) {
        try { if($process.Path) { Split-Path -Parent $process.Path } } catch { }
    }
    foreach($base in @(${env:ProgramFiles(x86)},$env:ProgramFiles,$env:ProgramW6432)) {
        if($base) { Join-Path $base 'Steam' }
    }
}

function Get-WorldBridgeRegisteredGames {
    foreach($root in @('HKCU:\Software','HKLM:\SOFTWARE','HKLM:\SOFTWARE\WOW6432Node')) {
        $entry=Get-ItemProperty -LiteralPath ($root+'\Microsoft\Windows\CurrentVersion\Uninstall\Steam App 975370') -ErrorAction SilentlyContinue
        if($entry -and $entry.PSObject.Properties['InstallLocation']) { $entry.InstallLocation }
    }
}

function ConvertFrom-WorldBridgeVdfString([string]$Value) {
    return [regex]::Replace($Value,'\\([\\"])','$1')
}

function Resolve-WorldBridgeFolder([string]$Path) {
    $folder=Get-Item -LiteralPath $Path -ErrorAction Stop
    if($folder -isnot [System.IO.DirectoryInfo]) { throw 'Choose a folder.' }
    $full=$folder.FullName
    if($full -ne [IO.Path]::GetPathRoot($full)) { $full=$full.TrimEnd('\') }
    return $full
}

function Resolve-WorldBridgeInstallation {
    param([Parameter(Mandatory=$true)][string]$GamePath,[string]$HackPath)
    $game=Resolve-WorldBridgeFolder $GamePath
    if(-not (Test-Path -LiteralPath (Join-Path $game 'Dwarf Fortress.exe') -PathType Leaf)) {
        throw "Dwarf Fortress.exe was not found in: $game"
    }
    if(-not $HackPath) {
        $hook=Join-Path $game 'dfhooks_dfhack.ini'
        if(Test-Path -LiteralPath $hook -PathType Leaf) {
            $dll=(Get-Content -LiteralPath $hook -Raw -Encoding UTF8).Trim().Trim('"')
            if(-not [IO.Path]::IsPathRooted($dll)) { $dll=Join-Path $game $dll }
            $dll=[IO.Path]::GetFullPath($dll)
            if(-not (Test-Path -LiteralPath $dll -PathType Leaf)) {
                throw 'The game points to a missing DFHack installation. Repair DFHack or pass -HackPath.'
            }
            $HackPath=Split-Path -Parent $dll
        } else { $HackPath=Join-Path $game 'hack' }
    }
    $hack=Resolve-WorldBridgeFolder $HackPath
    if(-not (Test-Path -LiteralPath (Join-Path $hack 'dfhack-run.exe') -PathType Leaf)) {
        throw "DFHack was not found in: $hack. Install DFHack first or pass -HackPath."
    }
    return [pscustomobject]@{GamePath=$game;HackPath=$hack}
}

function Find-WorldBridgeInstallation {
    param([string]$GamePath,[string]$HackPath,[string[]]$SteamRoots,[string[]]$RegisteredGamePaths)
    if($GamePath) { return Resolve-WorldBridgeInstallation -GamePath $GamePath -HackPath $HackPath }
    if(-not $PSBoundParameters.ContainsKey('SteamRoots')) { $SteamRoots=@(Get-WorldBridgeSteamRoots) }
    if(-not $PSBoundParameters.ContainsKey('RegisteredGamePaths')) { $RegisteredGamePaths=@(Get-WorldBridgeRegisteredGames) }

    # A valid Windows registration takes precedence over stale library manifests.
    $registered=@(foreach($path in $RegisteredGamePaths) {
        if($path) { try { Resolve-WorldBridgeInstallation -GamePath $path -HackPath $HackPath } catch { } }
    })
    $registered=@($registered | Sort-Object -Property GamePath -Unique)
    if($registered.Count -eq 1) { return $registered[0] }
    if($registered.Count -gt 1) { throw ('Multiple registered games were found. Pass -GamePath to choose one: '+($registered.GamePath -join '; ')) }

    $libraries=@(foreach($root in $SteamRoots) {
        if(-not $root -or -not (Test-Path -LiteralPath $root -PathType Container)) { continue }
        $root
        foreach($relative in @('steamapps\libraryfolders.vdf','config\libraryfolders.vdf')) {
            $file=Join-Path $root $relative
            if(-not (Test-Path -LiteralPath $file -PathType Leaf)) { continue }
            $text=Get-Content -LiteralPath $file -Raw -Encoding UTF8
            # Supports both current path records and legacy numbered records.
            foreach($match in [regex]::Matches($text,'"(?:path|\d+)"\s+"((?:\\.|[^"\\])*)"')) {
                $path=ConvertFrom-WorldBridgeVdfString $match.Groups[1].Value
                if([IO.Path]::IsPathRooted($path)) { $path }
            }
        }
    })
    $found=@(foreach($library in ($libraries | Sort-Object -Unique)) {
        $manifest=Join-Path $library 'steamapps\appmanifest_975370.acf'
        if(-not (Test-Path -LiteralPath $manifest -PathType Leaf)) { continue }
        try {
            $text=Get-Content -LiteralPath $manifest -Raw -Encoding UTF8
            if($text -notmatch '"appid"\s+"975370"') { continue }
            $match=[regex]::Match($text,'"installdir"\s+"((?:\\.|[^"\\])*)"')
            if(-not $match.Success) { continue }
            $common=[IO.Path]::GetFullPath((Join-Path $library 'steamapps\common')).TrimEnd('\')
            $candidate=[IO.Path]::GetFullPath((Join-Path $common (ConvertFrom-WorldBridgeVdfString $match.Groups[1].Value)))
            if(-not $candidate.StartsWith($common+'\',[StringComparison]::OrdinalIgnoreCase)) { continue }
            Resolve-WorldBridgeInstallation -GamePath $candidate -HackPath $HackPath
        } catch { }
    })
    $found=@($found | Sort-Object -Property GamePath -Unique)
    if($found.Count -eq 1) { return $found[0] }
    if($found.Count -gt 1) { throw ('Multiple DFHack-enabled Steam games were found. Pass -GamePath to choose one: '+($found.GamePath -join '; ')) }
    throw "Could not find Dwarf Fortress with DFHack. Install both, or pass -GamePath 'C:\path\to\Dwarf Fortress'."
}
