#Requires -Version 5.1
# spec: IDE-BOOT-54. Local payload; the native frontend owns installation.
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$bundleRoot=[IO.Path]::GetFullPath($PSScriptRoot)
function Get-PayloadHash([string]$Path) {
    $stream=[IO.File]::OpenRead($Path)
    $sha=[Security.Cryptography.SHA256]::Create()
    try { return [BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-','').ToLowerInvariant() }
    finally { $stream.Dispose();$sha.Dispose() }
}
if ([IO.File]::ReadAllText((Join-Path $bundleRoot 'platform.txt')).Trim() -ne 'windows-x64' -or
    -not [Environment]::Is64BitProcess -or $env:PROCESSOR_ARCHITECTURE -eq 'ARM64') {
    throw 'Installer belongs to another native platform; use native x64 PowerShell.'
}
foreach ($argument in $args) {
    if ($argument -match '^--(source(?:=|$)|runtime-|powershell(?:=|$))') {
        throw 'Source and runtime are provided by this installer.'
    }
}
$expectedCount=0
foreach ($line in [IO.File]::ReadAllLines((Join-Path $bundleRoot 'payload.sha256'))) {
    if ($line -notmatch '^(?<sha>[a-f0-9]{64})  (?<path>[^\r\n]+)$') { throw 'Invalid installer manifest.' }
    $relative=$Matches.path
    $expected=$Matches.sha
    $file=[IO.Path]::GetFullPath((Join-Path $bundleRoot $relative))
    if (-not $file.StartsWith($bundleRoot.TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase) -or
        -not (Test-Path -LiteralPath $file -PathType Leaf)) { throw ('Missing installer file: '+$relative) }
    $entry=Get-Item -Force -LiteralPath $file
    if (($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) -or
        (Get-PayloadHash $file) -ne $expected) {
        throw ('Installer SHA256 mismatch: '+$relative)
    }
    if ($relative.StartsWith('payload/')) { $expectedCount++ }
}
$entries=@(Get-ChildItem -Force -Recurse -LiteralPath (Join-Path $bundleRoot 'payload'))
if (@($entries | Where-Object { $_.Attributes -band [IO.FileAttributes]::ReparsePoint }).Count -ne 0 -or
    @($entries | Where-Object { -not $_.PSIsContainer }).Count -ne $expectedCount) {
    throw 'Incomplete or unexpected installer payload.'
}
& (Join-Path $bundleRoot 'payload/frontend/fride-setup.exe') --source (Join-Path $bundleRoot 'payload/source') `
    --runtime-path (Join-Path $bundleRoot 'payload/runtime') --powershell ([Diagnostics.Process]::GetCurrentProcess().MainModule.FileName) `
    --log-dir (Join-Path $bundleRoot 'logs') @args
exit $LASTEXITCODE
