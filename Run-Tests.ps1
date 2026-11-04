param([string]$Lua='lua')
$ErrorActionPreference='Stop'
$previous=$env:WORLD_BRIDGE_TEST_ROOT
try {
    $env:WORLD_BRIDGE_TEST_ROOT=$PSScriptRoot.Replace('\','/')
    foreach($file in Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'tests') -Filter 'test_*.lua' -File | Sort-Object Name) {
        & $Lua $file.FullName
        if ($LASTEXITCODE -ne 0) { throw "Test failed: $($file.Name)" }
    }
} finally {
    $env:WORLD_BRIDGE_TEST_ROOT=$previous
}
