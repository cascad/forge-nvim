#Requires -Version 5.1
# spec: IDE-BOOT-8. Source bootstrap без Git; packages остаются в platform script.
[CmdletBinding()]
param(
    [ValidatePattern('^[a-zA-Z0-9][a-zA-Z0-9._/-]*$')][string]$Ref = 'main',
    [string]$ArchiveUrl = '',
    [string]$SourceRoot = (Join-Path $env:LOCALAPPDATA 'forge-nvim\sources'),
    [string]$InstallPath = (Join-Path $env:LOCALAPPDATA 'nvim'),
    [switch]$SkipDependencies,
    [Alias('Profile')][ValidateSet('Default','Custom')][string]$InstallProfile = 'Default',
    [AllowEmptyString()][string]$Components = ''
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$componentsExplicit = $PSBoundParameters.ContainsKey('Components')
if (-not $ArchiveUrl) {
    $ArchiveUrl = 'https://codeload.github.com/cascad/forge-nvim/zip/' + [Uri]::EscapeDataString($Ref)
}
$uri = [Uri]$ArchiveUrl
if (-not $uri.IsAbsoluteUri -or $uri.Scheme -notin @('http', 'https')) { throw 'Archive URL must use HTTP(S).' }
New-Item -ItemType Directory -Force -Path $SourceRoot | Out-Null
$sourceRootFull = [IO.Path]::GetFullPath($SourceRoot)
$staging = Join-Path $sourceRootFull ('.bootstrap-' + [Guid]::NewGuid().ToString('N'))
$oldComponents = $env:FORGE_NVIM_COMPONENTS
New-Item -ItemType Directory -Path $staging | Out-Null
function Test-Source([string]$Directory) {
    foreach ($name in @('nvim_forge\init.lua', 'nvim_forge\scripts\install-windows.ps1', 'nvim_forge.sh', 'wezterm.lua')) {
        if (-not (Test-Path -LiteralPath (Join-Path $Directory $name) -PathType Leaf)) { return $false }
    }
    return $true
}
try {
    $archive = Join-Path $staging 'source.zip'
    Write-Host "Downloading source (Windows): $ArchiveUrl"
    # Windows PowerShell5.1 использует системный .NET downloader, не Internet Explorer.
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $uri -OutFile $archive -UseBasicParsing
    $hash = [Security.Cryptography.SHA256]::Create()
    $inputFile = [IO.File]::OpenRead($archive)
    try { $digest = [BitConverter]::ToString($hash.ComputeHash($inputFile)).Replace('-', '').ToLowerInvariant() }
    finally { $inputFile.Dispose(); $hash.Dispose() }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    try { $zip = [IO.Compression.ZipFile]::OpenRead($archive) }
    catch { throw "Invalid source archive: $_" }
    try {
        $top = $null
        if ($zip.Entries.Count -eq 0) { throw 'Empty source archive.' }
        foreach ($entry in $zip.Entries) {
            $name = $entry.FullName.Replace('\', '/')
            $parts = $name.TrimEnd('/').Split('/')
            if ($name.StartsWith('/') -or $parts -contains '..' -or $parts -contains '.' -or
                $parts[0] -notmatch '^[a-zA-Z0-9_.-]+$') { throw 'Invalid source archive layout.' }
            if ($null -eq $top) { $top = $parts[0] }
            if ($top -ne $parts[0]) { throw 'Source archive must have one top directory.' }
        }
    } finally { $zip.Dispose() }
    $tree = Join-Path $staging 'tree'
    [IO.Compression.ZipFile]::ExtractToDirectory($archive, $tree)
    $candidate = Join-Path $tree $top
    if (-not (Test-Source $candidate)) { throw 'Archive has no complete forge-nvim source.' }
    $source = Join-Path $sourceRootFull $digest
    if (Test-Path -LiteralPath $source) {
        if (-not (Test-Source $source)) { throw "Cached source is incomplete: $source" }
    } else {
        Move-Item -LiteralPath $candidate -Destination $source
    }
    Write-Host "Source ready: $source"
    . (Join-Path $source 'nvim_forge\scripts\lib\install-profile.ps1')
    $env:FORGE_NVIM_COMPONENTS = Resolve-ForgeProfile -Profile $InstallProfile -Components $Components -Explicit $componentsExplicit
    Write-Host "Selected components: $env:FORGE_NVIM_COMPONENTS"
    Write-Host 'Starting Windows installer.'
    $backend = Join-Path $source 'nvim_forge\scripts\install-windows.ps1'
    $shell = (Get-Process -Id $PID).Path
    $backendArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $backend,
        '-UseLocalSource', '-WithLanguages', '-InstallPath', $InstallPath)
    if ($SkipDependencies) { $backendArgs += '-SkipDependencies' }
    & $shell @backendArgs
    $backendExit = $LASTEXITCODE
    if ($backendExit -ne 0) { exit $backendExit }
} finally {
    $env:FORGE_NVIM_COMPONENTS = $oldComponents
    # Проверить абсолютную границу перед recursive cleanup на Windows.
    $stageFull = [IO.Path]::GetFullPath($staging)
    $prefix = $sourceRootFull.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
    if (-not $stageFull.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase) -or
        -not ([IO.Path]::GetFileName($stageFull)).StartsWith('.bootstrap-')) {
        throw "Refusing cleanup outside bootstrap staging: $stageFull"
    }
    if (Test-Path -LiteralPath $stageFull) { Remove-Item -LiteralPath $stageFull -Recurse -Force }
}
