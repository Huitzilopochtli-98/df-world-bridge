param([string]$OutputDirectory=(Join-Path $PSScriptRoot 'dist'))
$ErrorActionPreference='Stop'
$version=(Get-Content -Raw -LiteralPath (Join-Path $PSScriptRoot 'VERSION')).Trim()
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$archive=Join-Path $OutputDirectory "WorldBridge-$version.zip"
$include=@('lua','dfhack-config','installer','tests','README.md','CHANGELOG.md','LICENSE','VERSION','Install-WorldBridge.ps1','Run-Tests.ps1','Package-WorldBridge.ps1')
$paths=@($include | ForEach-Object {Join-Path $PSScriptRoot $_})
Compress-Archive -LiteralPath $paths -DestinationPath $archive -Force
$hash=(Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant()
"$hash  $([System.IO.Path]::GetFileName($archive))" | Set-Content -LiteralPath ($archive+'.sha256') -Encoding ASCII
Get-Item -LiteralPath $archive | Select-Object FullName,Length
