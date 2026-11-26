# Plain args сохраняют опции Neovim (-u, -l, --headless и т.д.).
$ErrorActionPreference='Stop'
$forgeRoot=Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'lib/nvim-sdk.ps1')
$forgeSavedConfig=$env:XDG_CONFIG_HOME
$forgeSavedApp=$env:NVIM_APPNAME
$forgeSavedCheckout=$env:FORGE_CHECKOUT_CONFIG
try {
    $forgeNvim=Get-ForgeNvim $forgeRoot
    $env:XDG_CONFIG_HOME=$forgeRoot
    $env:NVIM_APPNAME='nvim_forge'
    $env:FORGE_CHECKOUT_CONFIG=Join-Path $forgeRoot 'nvim_forge'
    & $forgeNvim @args
    $forgeExit=$LASTEXITCODE
} finally {
    $env:XDG_CONFIG_HOME=$forgeSavedConfig
    $env:NVIM_APPNAME=$forgeSavedApp
    $env:FORGE_CHECKOUT_CONFIG=$forgeSavedCheckout
}
exit $forgeExit
