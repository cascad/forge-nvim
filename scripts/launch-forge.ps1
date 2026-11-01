# Plain args сохраняют опции Neovim (-u, -l, --headless и т.д.).
$ErrorActionPreference='Stop'
$forgeRoot=Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'lib/nvim-sdk.ps1')
$forgeSavedConfig=$env:XDG_CONFIG_HOME
$forgeSavedApp=$env:NVIM_APPNAME
try {
    $forgeNvim=Get-ForgeNvim $forgeRoot
    $env:XDG_CONFIG_HOME=$forgeRoot
    $env:NVIM_APPNAME='nvim_forge'
    & $forgeNvim @args
    $forgeExit=$LASTEXITCODE
} finally {
    $env:XDG_CONFIG_HOME=$forgeSavedConfig
    $env:NVIM_APPNAME=$forgeSavedApp
}
exit $forgeExit
