# spec: IDE-BOOT-11. Не изменяет registry PATH или profile shell.
$ErrorActionPreference='Stop'
$forgeKit=Split-Path -Parent $PSScriptRoot
$forgeEnvironment=@{
    NVIM_APPNAME='fride'; NVIM_LOG_FILE=(Join-Path $forgeKit 'log/nvim.log')
    FRIDE_CONFIG=(Join-Path $forgeKit 'config/forge')
    TEMP=(Join-Path $forgeKit 'tmp'); TMP=(Join-Path $forgeKit 'tmp'); TMPDIR=(Join-Path $forgeKit 'tmp')
    VIM=$null; VIMRUNTIME=$null; VIMINIT=$null; EXINIT=$null; LUA_INIT=$null; LUA_PATH=$null; LUA_CPATH=$null
    FORGE_NVIM_COMPONENTS=$null
    FORGE_SDK_PATHS=$null
}
$forgePaths=@(Get-Content -LiteralPath (Join-Path $PSScriptRoot 'runtime-paths.txt'))
$forgeSDKPaths=@();$forgeSDKFile=Join-Path $PSScriptRoot 'sdk-paths.txt'
if (Test-Path -LiteralPath $forgeSDKFile) { $forgeSDKPaths=@([IO.File]::ReadAllLines($forgeSDKFile,[Text.Encoding]::UTF8)) }
$forgeEnvironment['PATH']=((@($forgePaths | ForEach-Object { Join-Path $forgeKit ('runtime/'+$_) }) + @($env:PATH) + $forgeSDKPaths) -join ';')
$forgeSaved=@{}
foreach ($forgeKey in $forgeEnvironment.Keys) { $forgeSaved[$forgeKey]=[Environment]::GetEnvironmentVariable($forgeKey,'Process') }
try {
    foreach ($forgeKey in $forgeEnvironment.Keys) { [Environment]::SetEnvironmentVariable($forgeKey,$forgeEnvironment[$forgeKey],'Process') }
    & (Join-Path $forgeKit 'runtime/bin/nvim.exe') --cmd 'lua vim.opt.rtp:prepend(vim.env.FRIDE_CONFIG)' -u (Join-Path $env:FRIDE_CONFIG 'init.lua') @args
    $forgeExit=$LASTEXITCODE
} finally {
    foreach ($forgeKey in $forgeSaved.Keys) { [Environment]::SetEnvironmentVariable($forgeKey,$forgeSaved[$forgeKey],'Process') }
}
exit $forgeExit
