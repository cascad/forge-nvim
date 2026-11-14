#Requires -Version 5.1
# spec: IDE-BOOT-11. Никаких системных package managers или fallback на PATH nvim.
[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$Source,
      [Parameter(Mandatory=$true)][string]$InstallPath,
      [string]$RuntimePath = '', [string]$RuntimeArchiveUrl = '', [string]$RuntimeSHA256 = '')
$ErrorActionPreference='Stop'
function Get-RuntimeHash([string]$Path) {
    $algorithm=[Security.Cryptography.SHA256]::Create(); $stream=[IO.File]::OpenRead($Path)
    try { return [BitConverter]::ToString($algorithm.ComputeHash($stream)).Replace('-','').ToLowerInvariant() }
    finally { $stream.Dispose(); $algorithm.Dispose() }
}
if ($RuntimePath -and $RuntimeArchiveUrl) { throw 'Choose RuntimePath or RuntimeArchiveUrl.' }
if ($RuntimeArchiveUrl) {
    if ($RuntimeSHA256 -notmatch '^[a-fA-F0-9]{64}$') { throw 'Runtime archive requires SHA256.' }
    $uri=[Uri]$RuntimeArchiveUrl
    if (-not $uri.IsAbsoluteUri -or $uri.Scheme -notin @('http','https')) { throw 'Runtime URL must use HTTP(S).' }
    $cache=Join-Path (Split-Path -Parent $Source) ('.runtime-cache/'+$RuntimeSHA256.ToLowerInvariant())
    if (-not (Test-Path -LiteralPath $cache)) {
        $stage=$cache+'.stage-'+[Guid]::NewGuid().ToString('N')
        New-Item -ItemType Directory -Force -Path $stage | Out-Null
        try {
            $archive=Join-Path $stage 'runtime.zip'
            Invoke-WebRequest -Uri $uri -OutFile $archive -UseBasicParsing
            if ((Get-RuntimeHash $archive) -ne $RuntimeSHA256) { throw 'Runtime archive SHA256 mismatch.' }
            Add-Type -AssemblyName System.IO.Compression.FileSystem
            $zip=[IO.Compression.ZipFile]::OpenRead($archive)
            try {
                foreach ($entry in $zip.Entries) {
                    $parts=$entry.FullName.Replace('\','/').TrimEnd('/').Split('/')
                    if ($entry.FullName.StartsWith('/') -or $parts -contains '..' -or $parts -contains '.' -or
                        $entry.FullName.Contains(':') -or (($entry.ExternalAttributes -shr 16) -band 0xF000) -eq 0xA000) { throw 'Unsafe runtime archive entry.' }
                }
            } finally { $zip.Dispose() }
            $unpacked=Join-Path $stage 'unpacked'
            [IO.Compression.ZipFile]::ExtractToDirectory($archive,$unpacked)
            Move-Item -LiteralPath $unpacked -Destination $cache
        } finally {
            # stage построен только под cache, не из содержимого архива.
            $stageFull=[IO.Path]::GetFullPath($stage)
            $parentFull=[IO.Path]::GetFullPath((Split-Path -Parent $cache)).TrimEnd('\','/')+'\'
            if (-not $stageFull.StartsWith($parentFull,[StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe runtime cleanup path.' }
            Remove-Item -LiteralPath $stageFull -Recurse -Force
        }
    }
    $RuntimePath=$cache
}
if (-not $RuntimePath) { throw 'Prepared private runtime is unavailable. IDE-138 release bundles are not published yet; development stand: -RuntimePath <prepared bundle>. System Neovim and packages were not changed.' }
$runtime=[IO.Path]::GetFullPath($RuntimePath)
$manifest=Get-Content -LiteralPath (Join-Path $runtime 'forge-runtime.json') -Raw | ConvertFrom-Json
if ($manifest.schema -ne 1 -or $manifest.platform -ne 'windows-x64') { throw 'Unsupported private runtime manifest/platform.' }
$binary=[IO.Path]::GetFullPath((Join-Path $runtime $manifest.nvim))
if (-not $binary.StartsWith($runtime.TrimEnd('\','/')+'\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Runtime executable escapes its root.' }
$expected=$manifest.files.PSObject.Properties[$manifest.nvim].Value
if (-not $expected -or (Get-RuntimeHash $binary) -ne $expected) { throw 'Runtime Neovim SHA256 mismatch.' }
# -u NONE и очищенное окружение: даже bootstrap не читает init.lua пользователя.
$keys=@('FORGE_INSTALL_SOURCE','FORGE_INSTALL_TARGET','FORGE_INSTALL_RUNTIME','VIM','VIMRUNTIME','VIMINIT','EXINIT','LUA_INIT','LUA_PATH','LUA_CPATH',
    'XDG_CONFIG_HOME','XDG_DATA_HOME','XDG_STATE_HOME','XDG_CACHE_HOME','NVIM_APPNAME','NVIM_LOG_FILE','TEMP','TMP','TMPDIR')
$saved=@{}
foreach ($key in $keys) { $saved[$key]=[Environment]::GetEnvironmentVariable($key,'Process') }
try {
    foreach ($key in $keys) { [Environment]::SetEnvironmentVariable($key,$null,'Process') }
    $env:FORGE_INSTALL_SOURCE=[IO.Path]::GetFullPath($Source)
    $env:FORGE_INSTALL_TARGET=[IO.Path]::GetFullPath($InstallPath)
    $env:FORGE_INSTALL_RUNTIME=$runtime
    $work=Join-Path (Split-Path -Parent $Source) ('.installer-'+[Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path (Join-Path $work 'tmp') -Force | Out-Null
    $env:XDG_CONFIG_HOME=Join-Path $work 'config';$env:XDG_DATA_HOME=Join-Path $work 'data'
    $env:XDG_STATE_HOME=Join-Path $work 'state';$env:XDG_CACHE_HOME=Join-Path $work 'cache'
    $env:NVIM_APPNAME='forge-bootstrap';$env:NVIM_LOG_FILE=Join-Path $work 'nvim.log'
    $env:TEMP=Join-Path $work 'tmp';$env:TMP=$env:TEMP;$env:TMPDIR=$env:TEMP
    & $binary --headless -u NONE -i NONE -l (Join-Path $Source 'scripts/install-private.lua')
    if ($LASTEXITCODE -ne 0) { throw "Private installation failed (exit $LASTEXITCODE)." }
} finally {
    foreach ($key in $keys) { [Environment]::SetEnvironmentVariable($key,$saved[$key],'Process') }
}
