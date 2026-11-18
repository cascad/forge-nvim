# spec: IDE-BOOT-13. Получение готового frontend без компилятора/Neovim.
function Get-ForgeUIHash([string]$Path) {
    $algorithm=[Security.Cryptography.SHA256]::Create();$stream=[IO.File]::OpenRead($Path)
    try { return [BitConverter]::ToString($algorithm.ComputeHash($stream)).Replace('-','').ToLowerInvariant() }
    finally { $stream.Dispose();$algorithm.Dispose() }
}
function Get-ForgeInstallerUI([string]$Source,[string]$CacheRoot,[string]$Checkout,[string]$ExplicitPath) {
    if ($ExplicitPath) {
        $path=[IO.Path]::GetFullPath($ExplicitPath)
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Installer UI not found: $path" }
        return $path
    }
    $machine=$env:PROCESSOR_ARCHITEW6432
    if (-not $machine) { $machine=$env:PROCESSOR_ARCHITECTURE }
    $arch=if ($machine -match 'ARM64') { 'arm64' } elseif ($machine -match 'AMD64') { 'x64' } else { throw 'Unsupported installer UI architecture.' }
    $platform='windows-'+$arch
    $catalog=Join-Path $Source 'installer-ui/artifacts.tsv'
    $url='';$expected=''
    if (Test-Path -LiteralPath $catalog -PathType Leaf) {
        foreach ($line in [IO.File]::ReadAllLines($catalog,[Text.Encoding]::UTF8)) {
            if (-not $line.Trim() -or $line.StartsWith('#')) { continue }
            $fields=$line.Split("`t")
            if ($fields.Count -ne 3) { throw 'Invalid installer UI artifact catalog.' }
            if ($fields[0] -eq $platform) { $url=$fields[1];$expected=$fields[2] }
        }
    }
    if (-not $url) { throw "Installer UI artifact for $platform is not published. Developer preview: build with scripts/build-installer-ui.py and pass -InstallerUIPath explicitly; install never runs Cargo." }
    if ($expected -notmatch '^[a-f0-9]{64}$') { throw 'Installer UI requires SHA256.' }
    $uri=[Uri]$url
    if (-not $uri.IsAbsoluteUri -or $uri.Scheme -notin @('https','http')) { throw 'Installer UI URL must use HTTP(S).' }
    if ($Checkout) {
        $binary=Join-Path $Checkout ('.tools/installer-ui/'+$platform+'/fride-setup.exe')
        if ((Test-Path -LiteralPath $binary -PathType Leaf) -and (Get-ForgeUIHash $binary) -eq $expected) { return $binary }
    }
    $cache=Join-Path $CacheRoot '.ui-cache'
    $current=[IO.Path]::GetFullPath($cache)
    while ($current) {
        if ((Test-Path -LiteralPath $current) -and ((Get-Item -LiteralPath $current -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw "Linked UI cache: $current" }
        $parent=[IO.Path]::GetDirectoryName($current);if ($parent -eq $current) { break };$current=$parent
    }
    New-Item -ItemType Directory -Force -Path $cache | Out-Null
    $binary=Join-Path $cache ($expected+'.exe')
    if (Test-Path -LiteralPath $binary) {
        if ((Get-Item -LiteralPath $binary -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Linked installer UI cache file.' }
        if ((Get-ForgeUIHash $binary) -eq $expected) { return $binary }
    }
    $pending=Join-Path $cache ('.download-'+[Guid]::NewGuid().ToString('N'))
    try {
        Invoke-WebRequest -Uri $uri -OutFile $pending -UseBasicParsing
        if ((Get-ForgeUIHash $pending) -ne $expected) { throw 'Installer UI SHA256 mismatch.' }
        Move-Item -LiteralPath $pending -Destination $binary -Force
    } finally { if (Test-Path -LiteralPath $pending) { Remove-Item -LiteralPath $pending -Force } }
    return $binary
}
