# spec: IDE-BOOT-11. Не изменяет registry PATH или profile shell.
$ErrorActionPreference='Stop'
$forgeKit=Split-Path -Parent $PSScriptRoot
$forgeEnvironment=@{
    XDG_CONFIG_HOME=(Join-Path $forgeKit 'config'); XDG_DATA_HOME=(Join-Path $forgeKit 'data')
    XDG_STATE_HOME=(Join-Path $forgeKit 'state'); XDG_CACHE_HOME=(Join-Path $forgeKit 'cache')
    NVIM_APPNAME='forge'; NVIM_LOG_FILE=(Join-Path $forgeKit 'log/nvim.log')
    TEMP=(Join-Path $forgeKit 'tmp'); TMP=(Join-Path $forgeKit 'tmp'); TMPDIR=(Join-Path $forgeKit 'tmp')
    VIM=$null; VIMRUNTIME=$null; VIMINIT=$null; EXINIT=$null; LUA_INIT=$null; LUA_PATH=$null; LUA_CPATH=$null
    FORGE_NVIM_COMPONENTS=$null
}
$forgePaths=@(Get-Content -LiteralPath (Join-Path $PSScriptRoot 'runtime-paths.txt'))
$forgeStateBins=@()
foreach ($forgeLine in [IO.File]::ReadAllLines((Join-Path $PSScriptRoot 'sdk-environment.tsv'),[Text.Encoding]::UTF8)) {
    if (-not $forgeLine -or $forgeLine.StartsWith('#')) { continue }
    $forgeRow=$forgeLine.Split("`t")
    if ($forgeRow.Count -ne 3) { throw 'Invalid SDK environment policy.' }
    switch ($forgeRow[0]) {
        { $_ -in @('dir','file') } { $forgeEnvironment[$forgeRow[1]]=Join-Path $forgeKit $forgeRow[2] }
        'clear' { $forgeEnvironment[$forgeRow[1]]=$null }
        'bin' { if ($forgeRow[1] -in @('all','windows')) { $forgeStateBins+=Join-Path $forgeKit $forgeRow[2] } }
        default { throw 'Invalid SDK environment policy kind.' }
    }
}
$forgeEnvironment['PATH']=((@($forgePaths | ForEach-Object { Join-Path $forgeKit ('runtime/'+$_) }) + $forgeStateBins + @($env:PATH)) -join ';')
$forgeSaved=@{}
foreach ($forgeKey in $forgeEnvironment.Keys) { $forgeSaved[$forgeKey]=[Environment]::GetEnvironmentVariable($forgeKey,'Process') }
try {
    foreach ($forgeKey in $forgeEnvironment.Keys) { [Environment]::SetEnvironmentVariable($forgeKey,$forgeEnvironment[$forgeKey],'Process') }
    & (Join-Path $forgeKit 'runtime/bin/nvim.exe') @args
    $forgeExit=$LASTEXITCODE
} finally {
    foreach ($forgeKey in $forgeSaved.Keys) { [Environment]::SetEnvironmentVariable($forgeKey,$forgeSaved[$forgeKey],'Process') }
}
exit $forgeExit
