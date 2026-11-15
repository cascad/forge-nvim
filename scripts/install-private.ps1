#Requires -Version 5.1
# spec: IDE-BOOT-11. Никаких системных package managers или fallback на PATH nvim.
[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$Source,
      [Parameter(Mandatory=$true)][string]$InstallPath,
      [string]$RuntimePath = '', [string]$RuntimeArchiveUrl = '', [string]$RuntimeSHA256 = '', [string]$CommandDir = '', [string]$RuntimePlanPath = '')
$ErrorActionPreference='Stop'
if ($env:FRIDE_INSTALL_UI -eq '1') {
    [Console]::OutputEncoding=New-Object Text.UTF8Encoding($false)
    [Console]::Out.WriteLine('FRIDE_EVENT'+[char]9+'{"stage":"runtime","status":"start"}')
}
function Get-RuntimeHash([string]$Path) {
    $algorithm=[Security.Cryptography.SHA256]::Create(); $stream=[IO.File]::OpenRead($Path)
    try { return [BitConverter]::ToString($algorithm.ComputeHash($stream)).Replace('-','').ToLowerInvariant() }
    finally { $stream.Dispose(); $algorithm.Dispose() }
}
function Receive-ForgeRuntimeArchive([string]$RuntimeArchiveUrl,[string]$RuntimeSHA256) {
    # Frontend renders progress; Windows PowerShell's byte progress is costly.
    $ProgressPreference='SilentlyContinue'
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
    return $cache
}
if ($RuntimePath -and $RuntimeArchiveUrl) { throw 'Choose RuntimePath or RuntimeArchiveUrl.' }
if ($RuntimePlanPath) {
    if ($RuntimePath -or $RuntimeArchiveUrl) { throw 'RuntimePlanPath conflicts with explicit runtime.' }
    $seen=@{};$first=$true
    foreach ($line in [IO.File]::ReadAllLines([IO.Path]::GetFullPath($RuntimePlanPath),[Text.Encoding]::UTF8)) {
        $row=$line.Split("`t")
        if ($row.Count -ne 4 -or $row[0] -ne 'windows-x64' -or $row[1] -notmatch '^[a-z-]+$' -or $seen.ContainsKey($row[1])) { throw 'Invalid runtime delivery plan.' }
        if ($row[1] -in @('node-runtime','go-runtime')) { throw 'Native SDK cannot be a private IDE artifact.' }
        if ($first -and $row[1] -ne 'core') { throw 'Runtime delivery plan requires Core first.' }
        $seen[$row[1]]=$true
        Write-Output ('Runtime component: '+$row[1])
        $part=Receive-ForgeRuntimeArchive $row[2] $row[3]
        if ($first) { $RuntimePath=$part;$first=$false }
    }
    if ($first) { throw 'Empty runtime delivery plan.' }
} elseif ($RuntimeArchiveUrl) { $RuntimePath=Receive-ForgeRuntimeArchive $RuntimeArchiveUrl $RuntimeSHA256 }
if (-not $RuntimePath) { throw 'Prepared private runtime is unavailable. IDE-138 release bundles are not published yet; development stand: -RuntimePath <prepared bundle>. System Neovim and packages were not changed.' }
$runtime=[IO.Path]::GetFullPath($RuntimePath)
$manifest=Get-Content -LiteralPath (Join-Path $runtime 'forge-runtime.json') -Raw | ConvertFrom-Json
if ($manifest.schema -ne 1 -or $manifest.platform -ne 'windows-x64') { throw 'Unsupported private runtime manifest/platform.' }
$binary=[IO.Path]::GetFullPath((Join-Path $runtime $manifest.nvim))
if (-not $binary.StartsWith($runtime.TrimEnd('\','/')+'\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Runtime executable escapes its root.' }
$expected=$manifest.files.PSObject.Properties[$manifest.nvim].Value
if (-not $expected -or (Get-RuntimeHash $binary) -ne $expected) { throw 'Runtime Neovim SHA256 mismatch.' }
# -u NONE и очищенное окружение: даже bootstrap не читает init.lua пользователя.
$keys=@('FORGE_INSTALL_SOURCE','FORGE_INSTALL_TARGET','FORGE_INSTALL_RUNTIME','FORGE_INSTALL_COMMAND_DIR','FORGE_INSTALL_RUNTIME_PLAN','VIM','VIMRUNTIME','VIMINIT','EXINIT','LUA_INIT','LUA_PATH','LUA_CPATH',
    'NVIM_APPNAME','NVIM_LOG_FILE','TEMP','TMP','TMPDIR')
$saved=@{}
foreach ($key in $keys) { $saved[$key]=[Environment]::GetEnvironmentVariable($key,'Process') }
try {
    foreach ($key in $keys) { [Environment]::SetEnvironmentVariable($key,$null,'Process') }
    $env:FORGE_INSTALL_SOURCE=[IO.Path]::GetFullPath($Source)
    $env:FORGE_INSTALL_TARGET=[IO.Path]::GetFullPath($InstallPath)
    $env:FORGE_INSTALL_RUNTIME=$runtime
    if ($RuntimePlanPath) { $env:FORGE_INSTALL_RUNTIME_PLAN=[IO.Path]::GetFullPath($RuntimePlanPath) }
    if ($CommandDir) { $env:FORGE_INSTALL_COMMAND_DIR=[IO.Path]::GetFullPath($CommandDir) }
    $work=Join-Path (Split-Path -Parent $Source) ('.installer-'+[Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path (Join-Path $work 'tmp') -Force | Out-Null
    $env:NVIM_APPNAME='fride';$env:NVIM_LOG_FILE=Join-Path $work 'nvim.log'
    $env:TEMP=Join-Path $work 'tmp';$env:TMP=$env:TEMP;$env:TMPDIR=$env:TEMP
    & $binary --headless -u NONE -i NONE -l (Join-Path $Source 'scripts/install-private.lua')
    if ($LASTEXITCODE -ne 0) { throw "Private installation failed (exit $LASTEXITCODE)." }
} finally {
    foreach ($key in $keys) { [Environment]::SetEnvironmentVariable($key,$saved[$key],'Process') }
}
